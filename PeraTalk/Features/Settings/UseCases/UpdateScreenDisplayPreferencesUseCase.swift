import Foundation

struct UpdateScreenDisplayPreferencesUseCase {
    private let settingsService: any SettingsService

    init(settingsService: any SettingsService) {
        self.settingsService = settingsService
    }

    func execute(_ preferences: ScreenDisplayPreferences) async throws -> CachedProfile? {
        try await settingsService.updateScreenDisplayPreferences(preferences)
    }
}
