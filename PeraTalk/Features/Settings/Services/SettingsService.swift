import Foundation

/// 設定画面のプロフィール・サブスク読み書きを束ねるアプリケーションサービス。
@MainActor
protocol SettingsService {
    func fetchProfile() async throws -> CachedProfile?
    func updateAuxiliaryLanguage(_ language: AuxiliaryLanguage) async throws -> CachedProfile?
    func fetchScreenDisplayPreferences() async throws -> ScreenDisplayPreferences
    func updateScreenDisplayPreferences(_ preferences: ScreenDisplayPreferences) async throws -> CachedProfile?
    func fetchSubscription() async throws -> CachedSubscription?
}

// MARK: - Stub

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

// MARK: - Live

struct LiveSettingsService: SettingsService {
    private let profileRepository: any ProfileRepository
    private let subscriptionRepository: any SubscriptionRepository

    init(
        profileRepository: any ProfileRepository,
        subscriptionRepository: any SubscriptionRepository
    ) {
        self.profileRepository = profileRepository
        self.subscriptionRepository = subscriptionRepository
    }

    func fetchProfile() async throws -> CachedProfile? {
        try await profileRepository.fetch()
    }

    func updateAuxiliaryLanguage(_ language: AuxiliaryLanguage) async throws -> CachedProfile? {
        try await profileRepository.updateLanguage(language)
    }

    func fetchScreenDisplayPreferences() async throws -> ScreenDisplayPreferences {
        guard let profile = try await profileRepository.fetch() else {
            return .default
        }
        return profile.screenDisplayPreferencesOrDefault
    }

    func updateScreenDisplayPreferences(_ preferences: ScreenDisplayPreferences) async throws -> CachedProfile? {
        try await profileRepository.updateScreenDisplayPreferences(preferences)
    }

    func fetchSubscription() async throws -> CachedSubscription? {
        try await subscriptionRepository.fetch()
    }
}
