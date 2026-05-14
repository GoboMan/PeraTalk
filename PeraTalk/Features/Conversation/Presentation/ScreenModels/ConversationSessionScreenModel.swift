import Foundation
import Observation
import SwiftData

/// 下端がイベントを返さないまま待ち続ける場合の壁時計（`for try await` は内側だけでは解除できない）。
private struct ConversationAssistantStreamTimeoutError: Error {}

private enum ConversationAssistantStreamTiming {
    static let maxWait: Duration = .seconds(150)
}

private final class ConversationAssistantStreamResumeGate: @unchecked Sendable {
    private var continuation: CheckedContinuation<Void, Error>?
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func finishSuccess() {
        lock.lock()
        defer { lock.unlock() }
        guard let c = continuation else { return }
        continuation = nil
        c.resume()
    }

    func finishFailure(_ error: Error) {
        lock.lock()
        defer { lock.unlock() }
        guard let c = continuation else { return }
        continuation = nil
        c.resume(throwing: error)
    }
}

private final class ConversationStreamTimeoutFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var timedOut = false

    func markTimedOut() {
        lock.lock()
        defer { lock.unlock() }
        timedOut = true
    }

    func consumeWasTimedOut() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let v = timedOut
        timedOut = false
        return v
    }
}

private final class MutableConversationPumpTaskRef: @unchecked Sendable {
    var value: Task<Void, Never>?
}

private final class ConversationUtteranceTTSChunkStateBox: @unchecked Sendable {
    var state: ConversationUtteranceTTSChunker.State
    init(_ state: ConversationUtteranceTTSChunker.State) {
        self.state = state
    }
}

@MainActor
@Observable
final class ConversationSessionScreenModel {
    var activeSessionRemoteId: UUID
    /// `hydrate()` 後にセット。
    private(set) var activeSession: CachedSession?
    var transcript: [CachedUtterance] = []
    var personas: [CachedPersona] = []

    var inputText = ""
    var assistantAccumulatedDraft = ""
    /// プランポリシー（部分応答・キャンセル・完了）。
    var assistantStreamPhase = AssistantReplyStreamPhase.idle

    private var assistantLeadingLabelStripper = ConversationAssistantReplyDisplaySanitizer.StreamingLeadingLabelStripper()

    private let conversationService: any ConversationService
    private let streamAssistantUseCase: StreamAssistantConversationUseCase
    private let appendUtteranceUseCase: AppendConversationUtteranceUseCase
    private let speakConversationTextUseCase: SpeakConversationTextUseCase
    private let endSessionUseCase: EndSessionUseCase
    private let sessionRepository: any SessionRepository

    private var consumeStreamTask: Task<Void, Never>?

    init(
        activeSessionRemoteId: UUID,
        conversationService: any ConversationService,
        streamAssistantUseCase: StreamAssistantConversationUseCase,
        appendUtteranceUseCase: AppendConversationUtteranceUseCase,
        speakConversationTextUseCase: SpeakConversationTextUseCase,
        endSessionUseCase: EndSessionUseCase,
        sessionRepository: any SessionRepository
    ) {
        self.activeSessionRemoteId = activeSessionRemoteId
        self.conversationService = conversationService
        self.streamAssistantUseCase = streamAssistantUseCase
        self.appendUtteranceUseCase = appendUtteranceUseCase
        self.speakConversationTextUseCase = speakConversationTextUseCase
        self.endSessionUseCase = endSessionUseCase
        self.sessionRepository = sessionRepository
    }

    func hydrate() async throws {
        personas = try await conversationService.fetchActivePersonas()
        guard let session = try await sessionRepository.fetchById(remoteId: activeSessionRemoteId) else {
            return
        }
        activeSession = session
        transcript = transcriptSorted(session: session)
    }

    func sendUserTurn() async {
        guard let session = activeSession else { return }
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        consumeStreamTask?.cancel()
        await speakConversationTextUseCase.cancelQueue()

        assistantStreamPhase = .connecting
        assistantAccumulatedDraft = ""
        assistantLeadingLabelStripper = ConversationAssistantReplyDisplaySanitizer.StreamingLeadingLabelStripper()
        inputText = ""

        do {
            try await appendUtteranceUseCase.execute(session: session, role: ConvRole.user.rawValue, text: trimmed)
            transcript = transcriptSorted(session: session)
        } catch {}

        consumeStreamTask = Task { @MainActor in
            await runAssistantStream(session: session, latestUserText: trimmed)
        }
    }

    private func runAssistantStream(session: CachedSession, latestUserText _: String) async {
        assistantStreamPhase = .streaming

        let messages = transcript.map { ChatMessage(utterance: $0) }
        let personaPrompt = resolvedPersonaPrompt(session: session)
        let themeDescription = await resolvedThemeDescription(session: session)
        let (locale, gender) = ttsParameters(session: session)

        let stream = streamAssistantUseCase.execute(
            messages: messages,
            personaPrompt: personaPrompt,
            themeDescription: themeDescription
        )

        var chunkState = ConversationUtteranceTTSChunker.State()

        do {
            try await consumeStreamIntoUI(
                stream: stream,
                chunkState: &chunkState,
                locale: locale,
                gender: gender
            )

            let flushed = assistantLeadingLabelStripper.flushRemaining()
            if !flushed.isEmpty {
                assistantAccumulatedDraft += flushed
                let flushPieces = ConversationUtteranceTTSChunker.feed(state: &chunkState, delta: flushed)
                for piece in flushPieces {
                    await speakConversationTextUseCase.enqueue(fragment: piece, locale: locale, gender: gender)
                }
            }

            let tailPieces = ConversationUtteranceTTSChunker.drainTail(state: &chunkState)
            for piece in tailPieces {
                await speakConversationTextUseCase.enqueue(fragment: piece, locale: locale, gender: gender)
            }
            await speakConversationTextUseCase.flushPending(locale: locale, gender: gender)

            let finalAssistantRaw = assistantAccumulatedDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalAssistant =
                ConversationAssistantReplyDisplaySanitizer.ensuringLearnerQuestionEnglishSuffix(
                    ConversationAssistantReplyDisplaySanitizer.stripAllLeadingRoleLabels(from: finalAssistantRaw)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                )
            guard !finalAssistant.isEmpty else {
                assistantAccumulatedDraft = ""
                assistantStreamPhase = .failedError
                return
            }

            try await appendUtteranceUseCase.execute(session: session, role: ConvRole.assistant.rawValue, text: finalAssistant)
            transcript = transcriptSorted(session: session)
            assistantAccumulatedDraft = ""
            assistantStreamPhase = .completedNormally
        } catch is CancellationError {
            await persistPartialAssistantIfNeeded(session: session, locale: locale, gender: gender)
            if assistantStreamPhase != .completedTruncatedStream {
                assistantStreamPhase = .failedCancelled
            }
        } catch {
            print("[ConversationSession] assistant stream error: \(error)")
            await persistPartialAssistantIfNeeded(session: session, locale: locale, gender: gender)
            if assistantStreamPhase != .completedTruncatedStream {
                assistantStreamPhase = .failedError
            }
        }
    }

    func cancelAssistantGeneration() {
        consumeStreamTask?.cancel()
        Task {
            await speakConversationTextUseCase.cancelQueue()
        }
        assistantStreamPhase = .failedCancelled
    }

    func endSessionTap() async {
        guard let session = activeSession else { return }
        let built = transcript.map { ChatMessage(utterance: $0) }
        _ = try? await endSessionUseCase.execute(session: session, utterances: built)
    }

    private func consumeStreamIntoUI(
        stream: AsyncThrowingStream<String, Error>,
        chunkState: inout ConversationUtteranceTTSChunker.State,
        locale: String,
        gender: String?
    ) async throws {
        let chunkBox = ConversationUtteranceTTSChunkStateBox(chunkState)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let gate = ConversationAssistantStreamResumeGate(continuation)
            let clockState = ConversationStreamTimeoutFlag()
            let pumpRef = MutableConversationPumpTaskRef()

            let wallClockTask = Task { @MainActor in
                do {
                    try await Task.sleep(for: ConversationAssistantStreamTiming.maxWait)
                } catch {
                    return
                }
                clockState.markTimedOut()
                pumpRef.value?.cancel()
            }

            pumpRef.value = Task { @MainActor in
                defer { wallClockTask.cancel() }
                do {
                    for try await delta in stream {
                        try Task.checkCancellation()
                        let visible = assistantLeadingLabelStripper.push(delta)
                        guard !visible.isEmpty else { continue }
                        assistantAccumulatedDraft += visible
                        let pieces = ConversationUtteranceTTSChunker.feed(state: &chunkBox.state, delta: visible)
                        for piece in pieces {
                            await speakConversationTextUseCase.enqueue(fragment: piece, locale: locale, gender: gender)
                        }
                    }
                    gate.finishSuccess()
                } catch is CancellationError {
                    if clockState.consumeWasTimedOut() {
                        gate.finishFailure(ConversationAssistantStreamTimeoutError())
                    } else {
                        gate.finishFailure(CancellationError())
                    }
                } catch {
                    gate.finishFailure(error)
                }
            }
        }
        chunkState = chunkBox.state
    }

    /// プランポリシー A: 既に画面上に載った応答テキストは保持する。
    private func persistPartialAssistantIfNeeded(session: CachedSession, locale: String, gender: String?) async {
        let partialRaw = assistantAccumulatedDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let partialWithoutSuffix = ConversationAssistantReplyDisplaySanitizer.stripAllLeadingRoleLabels(from: partialRaw)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let partial =
            ConversationAssistantReplyDisplaySanitizer.ensuringLearnerQuestionEnglishSuffix(partialWithoutSuffix)
        guard !partial.isEmpty else { return }
        do {
            try await appendUtteranceUseCase.execute(session: session, role: ConvRole.assistant.rawValue, text: partial)
            transcript = transcriptSorted(session: session)
            assistantAccumulatedDraft = ""
            assistantStreamPhase = .completedTruncatedStream
            await speakConversationTextUseCase.flushPending(locale: locale, gender: gender)
        } catch {}
    }

    private func transcriptSorted(session: CachedSession) -> [CachedUtterance] {
        session.utterances.sorted { $0.sequenceIndex < $1.sequenceIndex }
    }

    private func resolvedPersonaPrompt(session: CachedSession) -> String? {
        guard let pid = session.personaId else { return nil }
        return personas.first(where: { $0.remoteId == pid })?.promptPersona
    }

    private func resolvedThemeDescription(session: CachedSession) async -> String? {
        guard let tid = session.themeId else { return nil }
        guard let themes = try? await conversationService.fetchActiveThemes() else { return nil }
        let row = themes.first(where: { $0.remoteId == tid })
        return row?.themeDescription ?? row?.name
    }

    private func ttsParameters(session: CachedSession) -> (String, String?) {
        guard let pid = session.personaId,
              let persona = personas.first(where: { $0.remoteId == pid })
        else { return ("en-US", nil) }
        let locale = persona.locale.isEmpty ? "en-US" : persona.locale
        return (locale, persona.gender)
    }

    private enum ConvRole: String {
        case user
        case assistant
    }
}

private extension ChatMessage {
    init(utterance: CachedUtterance) {
        let role = utterance.role == "assistant" ? "assistant" : "user"
        self.init(role: role, text: utterance.text)
    }
}
