import Foundation

protocol LLMClient: Sendable {
    func chat(
        messages: [ChatMessage],
        personaPrompt: String?,
        themeDescription: String?
    ) async throws -> String

    /// BFF からの SSE を解釈し、追記デルタを逐次 yield する。完了時は正常終了（`finish`）。
    func chatStreaming(
        messages: [ChatMessage],
        personaPrompt: String?,
        themeDescription: String?
    ) -> AsyncThrowingStream<String, Error>

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
