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

    func loadPersonas() async {
        await refreshStartData()
    }

    func loadThemes() async {
        await refreshStartData()
    }

    func beginSession() async throws -> CachedSession {
        try await startSessionUseCase.execute(
            mode: selectedMode,
            personaId: selectedPersonaId,
            themeId: selectedThemeId
        )
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

    /// 英会話セットアップシートを開く直前に呼ぶ。先頭ペルソナとフリートークを既定にする。
    func prepareEnglishConversationDefaults() {
        if selectedPersonaId == nil, let first = personas.first {
            selectedPersonaId = first.remoteId
        }
        selectedMode = .aiFree
        selectedThemeId = nil
    }

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
