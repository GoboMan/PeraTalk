import Foundation

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

    func mergeAuthenticatedRemoteProfile(
        authenticatedUserId: UUID,
        displayName: String?,
        auxiliaryLanguageFromRemote: String,
        appearanceTheme: String?,
        remoteUpdatedAt _: Date
    ) async throws -> CachedProfile {
        CachedProfile(remoteId: authenticatedUserId, auxiliaryLanguage: auxiliaryLanguageFromRemote)
    }
}
