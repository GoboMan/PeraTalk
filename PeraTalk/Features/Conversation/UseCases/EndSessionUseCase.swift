import Foundation

struct EndSessionUseCase {
    let conversationService: any ConversationService

    func execute(session: CachedSession, utterances: [ChatMessage]) async throws -> FeedbackResult {
        FeedbackResult(
            grammarStrength: nil,
            grammarWeakness: nil,
            vocabularyStrength: nil,
            vocabularyWeakness: nil,
            rawText: ""
        )
    }
}
