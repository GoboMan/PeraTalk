import Foundation

protocol LLMClient {
    func chat(
        messages: [ChatMessage],
        personaPrompt: String?,
        themeDescription: String?
    ) async throws -> String

    func generateFeedback(
        utterances: [ChatMessage],
        mode: String
    ) async throws -> FeedbackResult

    func generateCandidates(
        utterances: [ChatMessage]
    ) async throws -> [VocabularyCandidate]
}

struct ChatMessage {
    let role: String
    let text: String
}

struct FeedbackResult {
    let grammarStrength: String?
    let grammarWeakness: String?
    let vocabularyStrength: String?
    let vocabularyWeakness: String?
    let rawText: String
}

struct VocabularyCandidate {
    let headword: String
    let kind: String
    let definitionTarget: String?
    let definitionAux: String?
}
