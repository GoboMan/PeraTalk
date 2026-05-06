import Foundation

@MainActor
protocol SubscriptionRepository {
    func fetch() async throws -> CachedSubscription?
    func pull() async throws
}

struct StubSubscriptionRepository: SubscriptionRepository {
    nonisolated init() {}
    func fetch() async throws -> CachedSubscription? { nil }
    func pull() async throws {}
}
