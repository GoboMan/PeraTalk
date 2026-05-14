import Foundation

struct StubConversationTurnClient: ConversationTurnClient {
    func sendTurn(
        messages: [ChatMessage],
        personaPrompt: String?,
        themeDescription: String?
    ) async throws -> String {
        ""
    }
}
