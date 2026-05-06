import Foundation
import SwiftData

@Model
final class CachedTag {
    @Attribute(.unique) var remoteId: UUID
    var name: String
    var dirty: Bool
    var tombstone: Bool
    var remoteUpdatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \CachedVocabularyTagLink.tag)
    var vocabularyTagLinks: [CachedVocabularyTagLink]

    init(
        remoteId: UUID = UUID(),
        name: String,
        dirty: Bool = true,
        tombstone: Bool = false
    ) {
        self.remoteId = remoteId
        self.name = name
        self.dirty = dirty
        self.tombstone = tombstone
        self.remoteUpdatedAt = Date()
        self.vocabularyTagLinks = []
    }
}
