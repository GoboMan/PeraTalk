import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SettingsScreenModel {
    var profile: CachedProfile?
    var subscription: CachedSubscription?

    private let fetchProfileUseCase: FetchProfileUseCase
    private let updateAuxiliaryLanguageUseCase: UpdateAuxiliaryLanguageUseCase
    private let fetchSubscriptionUseCase: FetchSubscriptionUseCase
    private let signOutUseCase: SignOutUseCase
    private let deleteAccountUseCase: DeleteAccountUseCase

    init(
        fetchProfileUseCase: FetchProfileUseCase = FetchProfileUseCase(settingsService: StubSettingsService()),
        updateAuxiliaryLanguageUseCase: UpdateAuxiliaryLanguageUseCase = UpdateAuxiliaryLanguageUseCase(settingsService: StubSettingsService()),
        fetchSubscriptionUseCase: FetchSubscriptionUseCase = FetchSubscriptionUseCase(settingsService: StubSettingsService()),
        signOutUseCase: SignOutUseCase = SignOutUseCase(authService: StubAuthService()),
        deleteAccountUseCase: DeleteAccountUseCase = DeleteAccountUseCase(authService: StubAuthService())
    ) {
        self.fetchProfileUseCase = fetchProfileUseCase
        self.updateAuxiliaryLanguageUseCase = updateAuxiliaryLanguageUseCase
        self.fetchSubscriptionUseCase = fetchSubscriptionUseCase
        self.signOutUseCase = signOutUseCase
        self.deleteAccountUseCase = deleteAccountUseCase
    }

    var auxiliaryLanguage: AuxiliaryLanguage {
        guard let raw = profile?.auxiliaryLanguage else { return .systemDefault }
        return AuxiliaryLanguage(rawValue: raw) ?? .systemDefault
    }

    func loadProfile() async {
        profile = try? await fetchProfileUseCase.execute()
    }

    func changeLanguage(_ language: AuxiliaryLanguage) async {
        profile = try? await updateAuxiliaryLanguageUseCase.execute(language)
    }

    func loadSubscription() async {
        subscription = try? await fetchSubscriptionUseCase.execute()
    }

    func signOut() async throws {
        try await signOutUseCase.execute()
    }

    func deleteAccount() async throws {
        try await deleteAccountUseCase.execute()
    }

    func wipeLocalData() async throws {
        try await WipeLocalDataUseCase().execute()
    }

    /// SwiftData を使う実行時構成（プロフィール）。サブスクは未実装のため Stub のまま。
    static func live(modelContext: ModelContext, authService: any AuthService) -> SettingsScreenModel {
        let profileRepo = SwiftDataProfileRepository(context: modelContext)
        let settingsService = LiveSettingsService(
            profileRepository: profileRepo,
            subscriptionRepository: StubSubscriptionRepository()
        )
        return SettingsScreenModel(
            fetchProfileUseCase: FetchProfileUseCase(settingsService: settingsService),
            updateAuxiliaryLanguageUseCase: UpdateAuxiliaryLanguageUseCase(settingsService: settingsService),
            fetchSubscriptionUseCase: FetchSubscriptionUseCase(settingsService: settingsService),
            signOutUseCase: SignOutUseCase(authService: authService),
            deleteAccountUseCase: DeleteAccountUseCase(authService: authService)
        )
    }
}
