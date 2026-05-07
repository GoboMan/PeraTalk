import Foundation

@MainActor
protocol ProfileRepository {
    func fetch() async throws -> CachedProfile?
    func save(_ profile: CachedProfile) async throws
    func updateLanguage(_ language: AuxiliaryLanguage) async throws -> CachedProfile
    func updateScreenDisplayPreferences(_ preferences: ScreenDisplayPreferences) async throws -> CachedProfile
    func pull() async throws
}

struct StubProfileRepository: ProfileRepository {
    nonisolated init() {}
    func fetch() async throws -> CachedProfile? { nil }
    func save(_ profile: CachedProfile) async throws {}
    func updateLanguage(_ language: AuxiliaryLanguage) async throws -> CachedProfile {
        CachedProfile(auxiliaryLanguage: language.rawValue)
    }

    func updateScreenDisplayPreferences(_ preferences: ScreenDisplayPreferences) async throws -> CachedProfile {
        let data = try preferences.encoded()
        return CachedProfile(auxiliaryLanguage: AuxiliaryLanguage.systemDefault.rawValue, screenDisplayPreferencesData: data)
    }

    func pull() async throws {}
}
