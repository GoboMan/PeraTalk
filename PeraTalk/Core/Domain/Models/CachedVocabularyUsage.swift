import Foundation
import SwiftData

@Model
final class CachedVocabularyUsage {
    @Attribute(.unique) var remoteId: UUID
    var vocabulary: CachedVocabulary?
    var kind: String
    var definitionTarget: String?
    var definitionAux: String?
    var ipa: String?
    /// 例文 AI 等で嵌める代表的英語綴り（`CachedVocabulary.headword` と異なり得る）。空／nil は親見出しにフォールバック。
    var studyHeadword: String?
    var position: Int
    var dirty: Bool
    var tombstone: Bool
    var remoteUpdatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \CachedVocabularyExample.usage)
    var examples: [CachedVocabularyExample]

    init(
        remoteId: UUID = UUID(),
        kind: String,
        position: Int,
        dirty: Bool = true,
        tombstone: Bool = false
    ) {
        self.remoteId = remoteId
        self.kind = kind
        self.definitionTarget = nil
        self.definitionAux = nil
        self.ipa = nil
        self.studyHeadword = nil
        self.position = position
        self.dirty = dirty
        self.tombstone = tombstone
        self.remoteUpdatedAt = Date()
        self.examples = []
    }
}
