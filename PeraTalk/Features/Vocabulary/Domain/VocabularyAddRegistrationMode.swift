import Foundation

/// 単語追加画面の登録モード（UI の入力可否・AI ボタンを分岐）。
enum VocabularyAddRegistrationMode: Equatable {
    /// 新規：辞典候補を選ぶ前／選び直し直後。
    case pickingLemma
    /// 新規：辞典レマ結線あり。
    case lemmaLinked
    /// 新規：辞典に無い語として手入力。
    case custom
    /// 既存エントリの編集。
    case editing
}
