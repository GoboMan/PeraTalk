import Foundation

struct VocabularyAddFormPayload: Sendable {
    var headword: String
    var usages: [VocabularyAddFormUsageLine]
    var selectedTagRemoteIds: Set<UUID>
    var editingVocabularyRemoteId: UUID?
    /// プリセット辞典 `CachedLemma` へのリンク（ユーザーが辞典候補から選んだ場合）。
    var linkedLemmaStableId: UUID?
    var linkedAdjunctLemmaStableId: UUID?
}
