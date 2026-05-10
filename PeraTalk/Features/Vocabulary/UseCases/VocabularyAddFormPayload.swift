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

struct VocabularyAddFormUsageLine: Sendable {
    var kind: VocabularyKind
    var ipa: String
    var definitionAux: String
    var definitionTarget: String
    /// 例文に嵌める代表的英語綴り（空でも保存時／生成時は親見出しにフォールバック可）。
    var studyHeadword: String
    var examples: [VocabularyAddFormExampleLine]
}

struct VocabularyAddFormExampleLine: Sendable {
    var sentence: String
}

struct TagPickerItem: Hashable, Sendable {
    let remoteId: UUID
    let name: String
}
