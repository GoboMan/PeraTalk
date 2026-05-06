import Foundation
import SwiftData

@Model
final class CachedVocabularyExample {
    @Attribute(.unique) var remoteId: UUID
    var usage: CachedVocabularyUsage?
    var sentenceTarget: String
    var position: Int
    var dirty: Bool
    var tombstone: Bool
    var remoteUpdatedAt: Date

    init(
        remoteId: UUID = UUID(),
        sentenceTarget: String,
        position: Int,
        dirty: Bool = true,
        tombstone: Bool = false
    ) {
        self.remoteId = remoteId
        self.sentenceTarget = sentenceTarget
        self.position = position
        self.dirty = dirty
        self.tombstone = tombstone
        self.remoteUpdatedAt = Date()
    }
}
