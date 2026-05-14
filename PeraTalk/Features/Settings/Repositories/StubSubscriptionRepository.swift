import Foundation

struct StubSubscriptionRepository: SubscriptionRepository {
    nonisolated init() {}
    func fetch() async throws -> CachedSubscription? { nil }
    func pull() async throws {}
}
