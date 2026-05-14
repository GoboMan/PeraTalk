import Foundation

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
