import Foundation

/// 転写ログ（CachedUtterance）をセッションに追加する。
struct AppendConversationUtteranceUseCase {
    let conversationService: any ConversationService

    func execute(session: CachedSession, role: String, text: String) async throws {
        try await conversationService.appendUtterance(to: session, role: role, text: text)
    }
}
