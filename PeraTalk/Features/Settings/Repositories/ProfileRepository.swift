import Foundation

@MainActor
protocol ProfileRepository {
    func fetch() async throws -> CachedProfile?
    func save(_ profile: CachedProfile) async throws
    func updateLanguage(_ language: AuxiliaryLanguage) async throws -> CachedProfile
    func updateScreenDisplayPreferences(_ preferences: ScreenDisplayPreferences) async throws -> CachedProfile
    func pull() async throws
    /// ログイン済みユーザーの `profiles` 行をローカルへ取り込む。補助語と画面表示プリファレンスは既存ローカル値を優先する。
    func mergeAuthenticatedRemoteProfile(
        authenticatedUserId: UUID,
        displayName: String?,
        auxiliaryLanguageFromRemote: String,
        appearanceTheme: String?,
        remoteUpdatedAt: Date
    ) async throws -> CachedProfile
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
