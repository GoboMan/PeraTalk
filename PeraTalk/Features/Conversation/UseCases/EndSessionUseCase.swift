import Foundation

struct EndSessionUseCase {
    let conversationService: any ConversationService

    func execute(session: CachedSession, utterances: [ChatMessage]) async throws -> FeedbackResult {
        try await conversationService.endSession(session: session, utterances: utterances)
    }
}
