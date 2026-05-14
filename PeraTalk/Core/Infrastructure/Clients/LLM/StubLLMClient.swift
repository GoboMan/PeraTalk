import Foundation

struct StubLLMClient: LLMClient, Sendable {
    func chat(messages: [ChatMessage], personaPrompt: String?, themeDescription: String?) async throws -> String {
        try await concatenateStreaming(messages: messages, personaPrompt: personaPrompt, themeDescription: themeDescription)
    }

    func chatStreaming(
        messages: [ChatMessage],
        personaPrompt: String?,
        themeDescription: String?
    ) -> AsyncThrowingStream<String, Error> {
        _ = messages
        _ = personaPrompt
        _ = themeDescription
        return AsyncThrowingStream<String, Error> { (continuation: AsyncThrowingStream<String, Error>.Continuation) in
            continuation.yield(
                "Hi! Xcode Preview can't run Apple Intelligence reliably, so you're seeing this stub reply. Run the app on a simulator or device for real on-device chat. Want to describe your day so far?"
            )
            continuation.finish()
        }
    }

    private func concatenateStreaming(
        messages: [ChatMessage],
        personaPrompt: String?,
        themeDescription: String?
    ) async throws -> String {
        var buf = ""
        for try await d in chatStreaming(messages: messages, personaPrompt: personaPrompt, themeDescription: themeDescription) {
            buf += d
        }
        return buf
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
}
