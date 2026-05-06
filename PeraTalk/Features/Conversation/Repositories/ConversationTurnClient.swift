import Foundation

protocol ConversationTurnClient {
    func sendTurn(
        messages: [ChatMessage],
        personaPrompt: String?,
        themeDescription: String?
    ) async throws -> String
}

struct StubConversationTurnClient: ConversationTurnClient {
    func sendTurn(
        messages: [ChatMessage],
        personaPrompt: String?,
        themeDescription: String?
    ) async throws -> String {
        ""
    }
}
