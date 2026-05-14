import Foundation
import FoundationModels

private enum FoundationModelsGuards {
    static let maxResponseCharacters = 4_096
    static let maxBackgroundUtterances = 6
    static let streamTimeoutSeconds: UInt64 = 20
}

struct FoundationModelsLLMClient: LLMClient, Sendable {
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    func chat(messages: [ChatMessage], personaPrompt: String?, themeDescription: String?) async throws -> String {
        let session = LanguageModelSession(instructions: Self.buildInstructions(
            personaPrompt: personaPrompt,
            themeDescription: themeDescription
        ))
        let prompt = Self.buildPrompt(from: messages)
        let response = try await session.respond(to: prompt)
        return String(response.content.prefix(FoundationModelsGuards.maxResponseCharacters))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func chatStreaming(
        messages: [ChatMessage],
        personaPrompt: String?,
        themeDescription: String?
    ) -> AsyncThrowingStream<String, Error> {
        let instructions = Self.buildInstructions(
            personaPrompt: personaPrompt,
            themeDescription: themeDescription
        )
        let prompt = Self.buildPrompt(from: messages)
        let maxChars = FoundationModelsGuards.maxResponseCharacters
        let timeoutNanos = FoundationModelsGuards.streamTimeoutSeconds * 1_000_000_000
        return AsyncThrowingStream<String, Error> { (continuation: AsyncThrowingStream<String, Error>.Continuation) in
            let task = Task.detached {
                do {
                    try await Self.streamWithTimeout(
                        instructions: instructions,
                        prompt: prompt,
                        maxChars: maxChars,
                        timeoutNanos: timeoutNanos,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    print("[FoundationModelsLLMClient] error: \(error)")
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { reason in
                if case .cancelled = reason { task.cancel() }
            }
        }
    }

    func generateFeedback(utterances: [ChatMessage], mode: String) async throws -> FeedbackResult {
        FeedbackResult(
            grammarStrength: nil,
            grammarWeakness: nil,
            vocabularyStrength: nil,
            vocabularyWeakness: nil,
            rawText: ""
        )
    }

    func generateCandidates(utterances: [ChatMessage]) async throws -> [VocabularyCandidate] {
        []
    }

    private static func streamWithTimeout(
        instructions: String,
        prompt: String,
        maxChars: Int,
        timeoutNanos: UInt64,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                let session = LanguageModelSession(instructions: instructions)
                let stream = session.streamResponse(to: prompt)
                var previousLength = 0
                for try await snapshot in stream {
                    let current = String(snapshot.content.prefix(maxChars))
                    if current.count > previousLength {
                        let delta = String(current.dropFirst(previousLength))
                        continuation.yield(delta)
                        previousLength = current.count
                    }
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanos)
                throw FoundationModelsTimeoutError()
            }
            let _ = try await group.next()
            group.cancelAll()
        }
    }

    private static func buildInstructions(personaPrompt: String?, themeDescription: String?) -> String {
        var parts = [
            "You are an English conversation partner for a Japanese learner. "
                + "Respond naturally in 1-3 concise English sentences.",
            "Output ONLY your spoken reply. No role labels, no prefixes, no meta commentary. "
                + "Never echo or repeat prior dialogue. One reply only, then stop.",
            "End every reply with a question to the learner.",
        ]
        if let personaPrompt { parts.append(personaPrompt) }
        if let themeDescription { parts.append("Topic: \(themeDescription)") }
        return parts.joined(separator: "\n")
    }

    private static func buildPrompt(from messages: [ChatMessage]) -> String {
        guard let latest = messages.last else {
            return "Greet the learner with one short friendly English sentence ending with a question."
        }

        let priorSlice = messages.dropLast()
        let windowedPrior = priorSlice.suffix(FoundationModelsGuards.maxBackgroundUtterances)

        var lines: [String] = []
        if !windowedPrior.isEmpty {
            lines.append("[Prior context - do not repeat these lines:]")
            for msg in windowedPrior {
                let text = msg.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                let tag = msg.role.lowercased() == "user" ? "L" : "P"
                lines.append("\(tag): \(text)")
            }
            lines.append("")
        }

        if latest.role.lowercased() == "user" {
            lines.append("Learner: \(latest.text)")
        }
        lines.append("Reply naturally in English. End with a question.")
        return lines.joined(separator: "\n")
    }
}

private struct FoundationModelsTimeoutError: Error {}
