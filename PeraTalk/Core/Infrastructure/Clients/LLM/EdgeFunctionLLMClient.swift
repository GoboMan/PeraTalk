import Foundation

/// SSE を行単位で届け、`URLSessionDataTask.cancel()` と連動させる。
private final class EdgeSSELineStreamCoordinator: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let cfg: URLSessionConfiguration

    private lazy var delegateQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        q.name = "PeraTalk.EdgeSSELineStreamCoordinator"
        return q
    }()

    private var session: URLSession?
    private var sessionTask: URLSessionDataTask?
    private var buffered = Data()
    private static let lfData = Data("\n".utf8)

    /// `didReceive response` が来る前に届いたボディ。
    private var heldBeforeResponse = Data()
    private var sawResponseHeaders = false

    private var lineContinuation: AsyncThrowingStream<String, Error>.Continuation?

    init(configuration: URLSessionConfiguration) {
        cfg = configuration
        super.init()
    }

    func lines(for request: URLRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream<String, Error> { continuation in
            lineContinuation = continuation

            continuation.onTermination = { [weak self] reason in
                guard let self else { return }
                if case .cancelled = reason {
                    sessionTask?.cancel()
                    invalidateSessionRemovingContinuation()
                }
            }

            let sess = URLSession(configuration: cfg, delegate: self, delegateQueue: delegateQueue)
            session = sess

            let task = sess.dataTask(with: request)
            sessionTask = task
            task.resume()
        }
    }

    /// タスク終了後の二重無効化用。
    func invalidateSession() {
        invalidateSessionRemovingContinuation()
    }

    private func invalidateSessionRemovingContinuation() {
        delegateQueue.addOperation { [self] in
            sessionTask?.cancel()
            session?.invalidateAndCancel()
            session = nil
            sessionTask = nil
        }
    }

    func urlSession(
        _: URLSession,
        dataTask _: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if sawResponseHeaders {
            completionHandler(.allow)
            return
        }
        sawResponseHeaders = true

        guard let http = response as? HTTPURLResponse else {
            lineContinuation?.finish(throwing: EdgeFunctionUpstreamError.invalidResponse)
            completionHandler(.cancel)
            return
        }
        guard (200 ... 299).contains(http.statusCode) else {
            lineContinuation?.finish(
                throwing: EdgeFunctionUpstreamError.httpStatus(http.statusCode, "(stream)")
            )
            completionHandler(.cancel)
            return
        }
        guard let ctype = http.value(forHTTPHeaderField: "Content-Type"),
              ctype.lowercased().contains("text/event-stream")
        else {
            lineContinuation?.finish(throwing: EdgeFunctionUpstreamError.notEventStreamBody)
            completionHandler(.cancel)
            return
        }

        buffered.append(heldBeforeResponse)
        heldBeforeResponse.removeAll(keepingCapacity: false)
        flushBufferedLines(includePartialTail: false)
        completionHandler(.allow)
    }

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
        if !sawResponseHeaders {
            heldBeforeResponse.append(data)
            return
        }
        buffered.append(data)
        flushBufferedLines(includePartialTail: false)
    }

    func urlSession(_ session: URLSession, task _: URLSessionTask, didCompleteWithError error: Error?) {
        if sawResponseHeaders {
            flushBufferedLines(includePartialTail: true)
        }
        if let error {
            lineContinuation?.finish(throwing: error)
        } else {
            lineContinuation?.finish()
        }
        lineContinuation = nil
        session.invalidateAndCancel()
        self.session = nil
        sessionTask = nil
    }

    private func flushBufferedLines(includePartialTail: Bool) {
        guard let cont = lineContinuation else { return }

        while let range = buffered.firstRange(of: Self.lfData) {
            let lower = range.lowerBound
            let lineSlice = buffered[..<lower]
            buffered.removeSubrange(buffered.startIndex ..< range.upperBound)

            let raw = String(decoding: lineSlice, as: UTF8.self)
            cont.yield(raw)
        }

        if includePartialTail, !buffered.isEmpty {
            let tail = String(decoding: buffered, as: UTF8.self)
            buffered.removeAll(keepingCapacity: false)
            cont.yield(tail)
        }
    }
}

private final class EdgeStreamCharacterBudget: @unchecked Sendable {
    private(set) var consumed = 0
    let limit: Int

    init(limit: Int) {
        self.limit = limit
    }

    /// - Returns: これ以上 `delta` を処理できない／打ち切ったら `false`。
    func yieldIfAllowed(
        _ fragment: String,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) -> Bool {
        guard !fragment.isEmpty else { return true }
        let remaining = limit - consumed
        guard remaining > 0 else { return false }
        let out: String
        if fragment.count <= remaining {
            out = fragment
        } else {
            out = String(fragment.prefix(remaining))
        }
        continuation.yield(out)
        consumed += out.count
        if fragment.count > out.count { return false }
        if consumed >= limit { return false }
        return true
    }
}

/// Supabase Edge Function `gemini-chat-stream`（SSE）。キー・モデルは BFF が保持する。
struct EdgeFunctionLLMClient: LLMClient, Sendable {
    /// 会話 1 往復分として十分な upper bound。超えたらストリームを終了する。
    private static let maxStreamYieldedCharacters = 32_768

    private static func streamingSessionConfiguration() -> URLSessionConfiguration {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 90
        cfg.timeoutIntervalForResource = 180
        cfg.waitsForConnectivity = false
        return cfg
    }

    private let invokeURL: URL
    private let anonKey: String
    private let accessTokenProvider: @Sendable () async throws -> String?

    init(
        supabaseProjectRootURL: URL,
        anonKey: String,
        accessTokenProvider: @escaping @Sendable () async throws -> String?
    ) {
        let root = Self.trimmedRoot(supabaseProjectRootURL)
        self.invokeURL = root.appending(path: "/functions/v1/gemini-chat-stream")
        self.anonKey = anonKey
        self.accessTokenProvider = accessTokenProvider
    }

    func chat(messages: [ChatMessage], personaPrompt: String?, themeDescription: String?) async throws -> String {
        try await concatenateStreaming(messages: messages, personaPrompt: personaPrompt, themeDescription: themeDescription)
    }

    func chatStreaming(
        messages: [ChatMessage],
        personaPrompt: String?,
        themeDescription: String?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream<String, Error> { (continuation: AsyncThrowingStream<String, Error>.Continuation) in
            let worker = Task {
                do {
                    guard let bearer = try await accessTokenProvider(), !bearer.isEmpty else {
                        throw EdgeFunctionAuthError.noAccessToken
                    }

                    var request = URLRequest(url: invokeURL)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
                    request.setValue(anonKey, forHTTPHeaderField: "apikey")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let bodyPayload = GeminiChatStreamHTTPPayload(
                        request_id: UUID().uuidString.lowercased(),
                        messages: messages.map { GeminiChatHTTPMessage(role: $0.role, text: $0.text) },
                        persona_prompt: personaPrompt,
                        theme_description: themeDescription
                    )
                    request.httpBody = try JSONEncoder().encode(bodyPayload)
                    request.timeoutInterval = 90

                    let sseCoord = EdgeSSELineStreamCoordinator(configuration: Self.streamingSessionConfiguration())
                    defer { sseCoord.invalidateSession() }

                    let lineStream = sseCoord.lines(for: request)

                    let budget = EdgeStreamCharacterBudget(limit: Self.maxStreamYieldedCharacters)
                    if try await Self.consumeEventStream(lines: lineStream, continuation: continuation, budget: budget) {
                        continuation.finish()
                    }
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { reason in
                if case .cancelled = reason {
                    worker.cancel()
                }
            }
        }
    }

    func generateFeedback(utterances: [ChatMessage], mode: String) async throws -> FeedbackResult {
        _ = utterances
        _ = mode
        return FeedbackResult(
            grammarStrength: nil,
            grammarWeakness: nil,
            vocabularyStrength: nil,
            vocabularyWeakness: nil,
            rawText: ""
        )
    }

    func generateCandidates(utterances: [ChatMessage]) async throws -> [VocabularyCandidate] {
        _ = utterances
        return [] as [VocabularyCandidate]
    }

    private func concatenateStreaming(
        messages: [ChatMessage],
        personaPrompt: String?,
        themeDescription: String?
    ) async throws -> String {
        var acc = ""
        for try await fragment in chatStreaming(
            messages: messages,
            personaPrompt: personaPrompt,
            themeDescription: themeDescription
        ) {
            acc += fragment
        }
        return acc
    }

    private static func trimmedRoot(_ url: URL) -> URL {
        var s = url.absoluteString
        while s.last == "/" { s.removeLast() }
        return URL(string: s)!
    }

    private struct GeminiChatHTTPMessage: Codable {
        let role: String
        let text: String
    }

    private struct GeminiChatStreamHTTPPayload: Codable {
        let request_id: String
        let messages: [GeminiChatHTTPMessage]
        let persona_prompt: String?
        let theme_description: String?
    }

    private struct WireEnvelope: Decodable {
        let type: String
        let text: String?
        let code: String?
        let message: String?
    }

    /// - Returns: false のとき `continuation` は既に終了済み（または打ち切りで正常終了）。
    private static func consumeEventStream(
        lines: AsyncThrowingStream<String, Error>,
        continuation: AsyncThrowingStream<String, Error>.Continuation,
        budget: EdgeStreamCharacterBudget
    ) async throws -> Bool {
        var block: [String] = []
        for try await raw in lines {
            try Task.checkCancellation()
            let line = raw.trimmingCharacters(in: .newlines)
            if line.isEmpty {
                guard !block.isEmpty else { continue }
                guard try flushSSEBlock(lines: block, continuation: continuation, budget: budget) else { return false }
                block = []
                continue
            }
            block.append(raw)
        }
        if !block.isEmpty {
            guard try flushSSEBlock(lines: block, continuation: continuation, budget: budget) else { return false }
        }
        return true
    }

    /// - Returns: `false` で呼び出し側はストリームを即終了（エラー済み、または上限打ち切り）。
    private static func flushSSEBlock(
        lines originalLines: [String],
        continuation: AsyncThrowingStream<String, Error>.Continuation,
        budget: EdgeStreamCharacterBudget
    ) throws -> Bool {
        var eventLow: String?
        var payloads: [String] = []

        for raw in originalLines {
            let t = raw.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { continue }
            if t.lowercased().hasPrefix("event:") {
                eventLow = String(t.dropFirst(6)).trimmingCharacters(in: .whitespaces).lowercased()
                continue
            }
            if t.hasPrefix("data:") {
                payloads.append(String(t.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            }
        }

        guard !payloads.isEmpty else { return true }
        let merged = payloads.joined(separator: "\n")
        guard merged != "[DONE]", let dataBytes = merged.data(using: .utf8) else { return true }

        let wire = try JSONDecoder().decode(WireEnvelope.self, from: dataBytes)
        switch wire.type {
        case "delta":
            if let txt = wire.text, !txt.isEmpty {
                guard budget.yieldIfAllowed(txt, continuation: continuation) else {
                    continuation.finish()
                    return false
                }
            }
            return true
        case "done", "meta":
            return true
        case "error":
            continuation.finish(
                throwing: EdgeFunctionUpstreamError.streamEnvelope(code: wire.code, message: wire.message)
            )
            return false
        default:
            if eventLow == "error" {
                continuation.finish(
                    throwing: EdgeFunctionUpstreamError.streamEnvelope(code: wire.code, message: wire.message)
                )
                return false
            }
            return true
        }
    }
}
