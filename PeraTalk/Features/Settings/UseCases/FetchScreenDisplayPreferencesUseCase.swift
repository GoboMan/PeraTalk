import Foundation

struct FetchScreenDisplayPreferencesUseCase {
    private let settingsService: any SettingsService

    init(settingsService: any SettingsService) {
        self.settingsService = settingsService
    }

    func execute() async throws -> ScreenDisplayPreferences {
        try await settingsService.fetchScreenDisplayPreferences()
    }
}
