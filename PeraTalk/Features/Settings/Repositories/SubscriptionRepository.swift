import Foundation

@MainActor
protocol SubscriptionRepository {
    func fetch() async throws -> CachedSubscription?
    func pull() async throws
}
