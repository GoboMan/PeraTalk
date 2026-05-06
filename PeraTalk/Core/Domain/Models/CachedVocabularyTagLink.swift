import Foundation
import SwiftData

@Model
final class CachedVocabularyTagLink {
    var vocabulary: CachedVocabulary?
    var tag: CachedTag?
    var remoteCreatedAt: Date
    var dirty: Bool
    var tombstone: Bool

    init(
        remoteCreatedAt: Date = Date(),
        dirty: Bool = true,
        tombstone: Bool = false
    ) {
        self.remoteCreatedAt = remoteCreatedAt
        self.dirty = dirty
        self.tombstone = tombstone
    }
}
