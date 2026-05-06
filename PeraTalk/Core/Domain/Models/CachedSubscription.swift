import Foundation
import SwiftData

@Model
final class CachedSubscription {
    @Attribute(.unique) var remoteId: UUID
    var plan: String
    var status: String
    var currentPeriodEnd: Date?
    var remoteUpdatedAt: Date
    var cachedAt: Date

    init(
        remoteId: UUID = UUID(),
        plan: String = "free",
        status: String = "active",
        remoteUpdatedAt: Date = Date()
    ) {
        self.remoteId = remoteId
        self.plan = plan
        self.status = status
        self.currentPeriodEnd = nil
        self.remoteUpdatedAt = remoteUpdatedAt
        self.cachedAt = Date()
    }
}
