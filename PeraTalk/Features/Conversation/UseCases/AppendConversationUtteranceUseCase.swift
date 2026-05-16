import Foundation

struct AppendConversationUtteranceUseCase {
    let conversationService: any ConversationService

    func execute(session: CachedSession, role: String, text: String) async throws {}
}
