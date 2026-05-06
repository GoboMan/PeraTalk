import Foundation
import SwiftData

@Model
final class CachedPersona {
    @Attribute(.unique) var remoteId: UUID
    var slug: String
    var displayName: String
    var locale: String
    var gender: String?
    var voiceIdentifiersJSON: String?
    var promptPersona: String?
    var avatarURL: String?
    var isPreset: Bool
    var isActive: Bool
    var remoteUpdatedAt: Date
    var cachedAt: Date

    init(
        remoteId: UUID = UUID(),
        slug: String,
        displayName: String,
        locale: String,
        gender: String? = nil,
        isPreset: Bool = true,
        isActive: Bool = true
    ) {
        self.remoteId = remoteId
        self.slug = slug
        self.displayName = displayName
        self.locale = locale
        self.gender = gender
        self.voiceIdentifiersJSON = nil
        self.promptPersona = nil
        self.avatarURL = nil
        self.isPreset = isPreset
        self.isActive = isActive
        self.remoteUpdatedAt = Date()
        self.cachedAt = Date()
    }
}
