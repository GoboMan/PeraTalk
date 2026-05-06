import Foundation
import SwiftData

@Model
final class CachedProfile {
    @Attribute(.unique) var remoteId: UUID
    var displayName: String?
    var auxiliaryLanguage: String
    var appearanceTheme: String?
    var remoteUpdatedAt: Date
    var cachedAt: Date

    init(
        remoteId: UUID = UUID(),
        auxiliaryLanguage: String = "ja",
        remoteUpdatedAt: Date = Date()
    ) {
        self.remoteId = remoteId
        self.displayName = nil
        self.auxiliaryLanguage = auxiliaryLanguage
        self.appearanceTheme = nil
        self.remoteUpdatedAt = remoteUpdatedAt
        self.cachedAt = Date()
    }
}
