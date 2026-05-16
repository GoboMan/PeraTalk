import Foundation

struct StubLLMClient: LLMClient, Sendable {
    func chat(messages: [ChatMessage], personaPrompt: String?, themeDescription: String?) async throws -> String {
        _ = messages
        _ = personaPrompt
        _ = themeDescription
        return "Hi! Xcode Preview can't run Apple Intelligence reliably, so you're seeing this stub reply. Run the app on a simulator or device for real on-device chat. Want to describe your day so far?"
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
