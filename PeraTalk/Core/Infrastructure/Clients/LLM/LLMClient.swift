import Foundation

protocol LLMClient: Sendable {
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
