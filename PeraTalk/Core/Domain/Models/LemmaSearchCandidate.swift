import Foundation

/// 単語追加画面で一覧するプリセット辞典のレマ候補。
struct LemmaSearchCandidate: Identifiable, Hashable, Sendable {
    var id: UUID { stableLemmaId }
    let stableLemmaId: UUID
    let lemmaText: String
    /// `VocabularyKind.rawValue`
    let posRaw: String
    /// 動詞レマに `adj_*` 表面形があり、分詞形容詞を別用法として持ちうる。
    let hasParticipleAdjectiveParadigm: Bool
}
