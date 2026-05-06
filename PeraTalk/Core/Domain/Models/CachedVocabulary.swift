import Foundation
import SwiftData

@Model
final class CachedVocabulary {
    @Attribute(.unique) var remoteId: UUID
    var headword: String
    var language: String
    var notes: String?
    var source: String?
    var dirty: Bool
    var tombstone: Bool
    var remoteUpdatedAt: Date
    var cachedAt: Date

    /// プリセット辞典のレンマ。カスタム見出しのみのときは nil（逆側の `inverse` は `CachedLemma.linkedVocabularyEntries`）。
    var lemma: CachedLemma?
    /// 同一見出しに動詞義と形容詞義など別レマがあるときの追加紐付け（例: allocate に対する allocated）。
    var adjunctLemma: CachedLemma?

    @Relationship(deleteRule: .cascade, inverse: \CachedVocabularyUsage.vocabulary)
    var usages: [CachedVocabularyUsage]

    @Relationship(deleteRule: .cascade, inverse: \CachedVocabularyTagLink.vocabulary)
    var vocabularyTagLinks: [CachedVocabularyTagLink]

    init(
        remoteId: UUID = UUID(),
        headword: String,
        language: String = "en",
        notes: String? = nil,
        source: String? = nil,
        dirty: Bool = true,
        tombstone: Bool = false
    ) {
        self.remoteId = remoteId
        self.headword = headword
        self.language = language
        self.notes = notes
        self.source = source
        self.dirty = dirty
        self.tombstone = tombstone
        self.remoteUpdatedAt = Date()
        self.cachedAt = Date()
        self.usages = []
        self.vocabularyTagLinks = []
    }
}
