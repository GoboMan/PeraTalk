import Foundation

struct SendMessageUseCase {
    let conversationService: any ConversationService

    func execute(
        messages: [ChatMessage],
        personaPrompt: String?,
        themeDescription: String?
    ) async throws -> String {
        try await conversationService.sendChat(
            messages: messages,
            personaPrompt: personaPrompt,
            themeDescription: themeDescription
        )
    }
}
