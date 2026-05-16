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

    private let conversationService: any ConversationService
    private let loadStartDataUseCase: LoadConversationStartDataUseCase
    private let startSessionUseCase: StartSessionUseCase

    init(
        conversationService: any ConversationService = StubConversationService(),
        loadStartDataUseCase: LoadConversationStartDataUseCase? = nil,
        startSessionUseCase: StartSessionUseCase? = nil
    ) {
        self.conversationService = conversationService
        let svc = conversationService
        self.loadStartDataUseCase =
            loadStartDataUseCase ?? LoadConversationStartDataUseCase(conversationService: svc)
        self.startSessionUseCase =
            startSessionUseCase ?? StartSessionUseCase(conversationService: svc)
    }

    /// ペルソナとテーマを 1 回のフェッチで読み込む（二重取得による待ちを避ける）。
    func loadConversationStartData() async {
        do {
            let data = try await loadStartDataUseCase.execute()
            personas = data.personas
            themes = data.themes
            if selectedPersonaId == nil {
                selectedPersonaId = personas.first?.remoteId
            }
        } catch {
            personas = []
            themes = []
        }
    }

    func beginSession() async throws -> CachedSession {
        try await startSessionUseCase.execute(
            mode: selectedMode,
            personaId: selectedPersonaId,
            themeId: selectedThemeId
        )
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

    func prepareEnglishConversationDefaults() {}

    func resetForSelfSoliloquy() {
        selectedMode = .selfMode
        selectedPersonaId = nil
        selectedThemeId = nil
    }

    func selectEnglishFreeTalk() {
        selectedMode = .aiFree
        selectedThemeId = nil
    }

    func selectEnglishTheme(_ themeId: UUID) {
        selectedMode = .aiThemed
        selectedThemeId = themeId
    }
}
