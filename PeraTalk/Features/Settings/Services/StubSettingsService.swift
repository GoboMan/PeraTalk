import Foundation

struct StubSettingsService: SettingsService {
    nonisolated init() {}
    func fetchProfile() async throws -> CachedProfile? { nil }

    func updateAuxiliaryLanguage(_ language: AuxiliaryLanguage) async throws -> CachedProfile? {
        nil
    }

    func fetchScreenDisplayPreferences() async throws -> ScreenDisplayPreferences {
        .default
    }

    func updateScreenDisplayPreferences(_ preferences: ScreenDisplayPreferences) async throws -> CachedProfile? {
        nil
    }

    func fetchSubscription() async throws -> CachedSubscription? { nil }
}
