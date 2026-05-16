import Foundation

struct StartSessionUseCase {
    let conversationService: any ConversationService

    func execute(mode: SessionMode, personaId: UUID?, themeId: UUID?) async throws -> CachedSession {
        CachedSession(mode: mode.rawValue, personaId: personaId, themeId: themeId)
    }
}
