import Foundation
import SwiftData

@Model
final class SyncMeta {
    @Attribute(.unique) var category: String
    var lastFetchedRemoteUpdatedAt: Date?
    var lastFetchedAt: Date?
    var lastPushedAt: Date?
    var lastAttemptFailedAt: Date?
    var attemptCount: Int
    var nextAttemptAt: Date?
    var lastError: String?

    init(category: String) {
        self.category = category
        self.lastFetchedRemoteUpdatedAt = nil
        self.lastFetchedAt = nil
        self.lastPushedAt = nil
        self.lastAttemptFailedAt = nil
        self.attemptCount = 0
        self.nextAttemptAt = nil
        self.lastError = nil
    }
}
