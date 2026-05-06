import Foundation
import SwiftData

@Model
final class CachedTheme {
    @Attribute(.unique) var remoteId: UUID
    var name: String
    var themeDescription: String?
    var isPreset: Bool
    var isActive: Bool
    var dirty: Bool
    var tombstone: Bool
    var remoteUpdatedAt: Date
    var cachedAt: Date

    init(
        remoteId: UUID = UUID(),
        name: String,
        themeDescription: String? = nil,
        isPreset: Bool = false,
        isActive: Bool = true,
        dirty: Bool = true,
        tombstone: Bool = false
    ) {
        self.remoteId = remoteId
        self.name = name
        self.themeDescription = themeDescription
        self.isPreset = isPreset
        self.isActive = isActive
        self.dirty = dirty
        self.tombstone = tombstone
        self.remoteUpdatedAt = Date()
        self.cachedAt = Date()
    }
}
