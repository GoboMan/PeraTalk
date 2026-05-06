import Foundation

struct StartSessionUseCase {
    let conversationService: any ConversationService

    func execute(mode: SessionMode, personaId: UUID?, themeId: UUID?) async throws -> CachedSession {
        try await conversationService.startSession(mode: mode, personaId: personaId, themeId: themeId)
    }
}
