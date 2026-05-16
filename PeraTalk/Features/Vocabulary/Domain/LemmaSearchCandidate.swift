import Foundation
import SwiftData

/// 単語追加画面で一覧するプリセット辞典のレマ候補。
struct LemmaSearchCandidate: Identifiable, Hashable, Sendable {
    var id: UUID { stableLemmaId }
    let stableLemmaId: UUID
    let lemmaText: String
    /// `position` 最小の用法の `kind`（`VocabularyKind.rawValue`）。バッジ用。
    let posRaw: String
    /// 用法が複数あるときの補助ラベル（例: 「動詞 · 形容詞」）。単一用法なら nil。
    let multiKindSummary: String?
}
