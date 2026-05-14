import Foundation

struct StreamAssistantConversationUseCase {
    let conversationService: any ConversationService

    func execute(
        messages: [ChatMessage],
        personaPrompt: String?,
        themeDescription: String?
    ) -> AsyncThrowingStream<String, Error> {
        conversationService.streamAssistantChat(
            messages: messages,
            personaPrompt: personaPrompt,
            themeDescription: themeDescription
        )
    }
}
