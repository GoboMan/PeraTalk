import Foundation

/// `CachedLemma` から単語追加フォームの初期行を決める結果（辞書のみ。定義・例文は空で AI／手入力に委ねる）。
struct LemmaVocabularyDraftSeed {
    /// ユーザー見出し欄へ入れる文言（辞典の代表綴りに揃える）
    let suggestedHeadword: String
    let usageLines: [VocabularyAddFormUsageLine]
}
