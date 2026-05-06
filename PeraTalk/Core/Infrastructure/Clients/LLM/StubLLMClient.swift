import Foundation

struct StubLLMClient: LLMClient {
    func chat(messages: [ChatMessage], personaPrompt: String?, themeDescription: String?) async throws -> String {
        ""
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
