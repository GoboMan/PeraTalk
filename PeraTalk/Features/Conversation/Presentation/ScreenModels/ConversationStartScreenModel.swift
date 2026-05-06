import Foundation
import Observation

@MainActor
@Observable
final class ConversationStartScreenModel {
    var personas: [CachedPersona] = []
    var themes: [CachedTheme] = []
    var selectedMode: SessionMode = .aiFree
    var selectedPersonaId: UUID?
    var selectedThemeId: UUID?

    private let loadStartDataUseCase: LoadConversationStartDataUseCase

    init(loadStartDataUseCase: LoadConversationStartDataUseCase = LoadConversationStartDataUseCase(conversationService: StubConversationService())) {
        self.loadStartDataUseCase = loadStartDataUseCase
    }

    func loadPersonas() async {
        await refreshStartData()
    }

    func loadThemes() async {
        await refreshStartData()
    }

    private func refreshStartData() async {
        guard let result = try? await loadStartDataUseCase.execute() else { return }
        personas = result.personas
        themes = result.themes
    }

    var canStartSession: Bool {
        switch selectedMode {
        case .selfMode:
            return true
        case .aiFree:
            return selectedPersonaId != nil
        case .aiThemed:
            return selectedPersonaId != nil && selectedThemeId != nil
        }
    }
}
