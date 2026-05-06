import Foundation

struct FetchSubscriptionUseCase {
    let settingsService: any SettingsService

    func execute() async throws -> CachedSubscription? {
        try await settingsService.fetchSubscription()
    }
}
