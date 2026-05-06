import Foundation

struct LoadConversationStartDataUseCase {
    let conversationService: any ConversationService

    func execute() async throws -> (personas: [CachedPersona], themes: [CachedTheme]) {
        async let personas = conversationService.fetchActivePersonas()
        async let themes = conversationService.fetchActiveThemes()
        return try await (personas, themes)
    }
}
