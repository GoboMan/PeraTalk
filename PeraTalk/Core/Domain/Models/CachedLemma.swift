import Foundation
import SwiftData

/// プリセット英語辞典のレンマ（ユーザーデータの双方向同期対象外）。
@Model
final class CachedLemma {
    /// 辞書パックとクライアント間で不変の ID（世代をまたいで固定すること）。
    @Attribute(.unique) var stableLemmaId: UUID
    /// 表示・検索用の代表スペル（動詞は原形、名詞は単数などデータ側仕様）。
    var lemmaText: String
    /// `VocabularyKind` の rawValue と整合する想定。
    var posRaw: String
    var languageCode: String

    /// ターゲット言語（英語）側の短い定義プリセット。辞典パック由来。ユーザー上書きは `CachedVocabularyUsage` 側ではなく参照表示。
    var definitionTarget: String?
    /// 補助言語（例: 日本語）側の短い定義プリセット。辞典パック由来。
    var definitionAux: String?
    /// 同一レマに `adj_*` があるが主 `pos` が動詞のとき、過去分詞形容詞としての英語定義（省略可）。
    var participleAdjDefinitionTarget: String?
    /// 同上の補助言語側定義。
    var participleAdjDefinitionAux: String?

    @Relationship(deleteRule: .cascade, inverse: \CachedLemmaSurface.lemma)
    var surfaces: [CachedLemmaSurface]

    @Relationship(deleteRule: .nullify, inverse: \CachedVocabulary.lemma)
    var linkedVocabularyEntries: [CachedVocabulary]

    @Relationship(deleteRule: .nullify, inverse: \CachedVocabulary.adjunctLemma)
    var adjunctLinkedVocabularyEntries: [CachedVocabulary]

    init(
        stableLemmaId: UUID,
        lemmaText: String,
        posRaw: String,
        languageCode: String = "en",
        definitionTarget: String? = nil,
        definitionAux: String? = nil,
        participleAdjDefinitionTarget: String? = nil,
        participleAdjDefinitionAux: String? = nil
    ) {
        self.stableLemmaId = stableLemmaId
        self.lemmaText = lemmaText
        self.posRaw = posRaw
        self.languageCode = languageCode
        self.definitionTarget = definitionTarget
        self.definitionAux = definitionAux
        self.participleAdjDefinitionTarget = participleAdjDefinitionTarget
        self.participleAdjDefinitionAux = participleAdjDefinitionAux
        self.surfaces = []
        self.linkedVocabularyEntries = []
        self.adjunctLinkedVocabularyEntries = []
    }

    /// 辞典パック由来の意味。`kind` に応じて主定義か分詞形容詞用定義を返す。
    /// 動詞レマに `adj_*` がある場合、形容詞用法は **`participleAdj*` のみ**とする（動詞義へフォールバックしない）。
    func packUsageDefinitions(for kind: VocabularyKind) -> (aux: String, target: String) {
        if kind == .adjective, posRaw == VocabularyKind.verb.rawValue {
            let pAux = participleAdjDefinitionAux?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let pTarget = participleAdjDefinitionTarget?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return (pAux, pTarget)
        }
        return (definitionAux ?? "", definitionTarget ?? "")
    }
}
