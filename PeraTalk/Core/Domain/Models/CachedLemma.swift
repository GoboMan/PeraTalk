import Foundation
import SwiftData

/// プリセット英語辞典のレンマ（ユーザーデータの双方向同期対象外）。見出し語のみを保持し、品詞・定義・表面形は `CachedLemmaUsage` に分離する。
@Model
final class CachedLemma {
    /// 辞書パックとクライアント間で不変の ID（世代をまたいで固定すること）。
    @Attribute(.unique) var stableLemmaId: UUID
    /// 表示・検索用の代表スペル（動詞は原形、名詞は単数などデータ側仕様）。
    var lemmaText: String
    var languageCode: String

    @Relationship(deleteRule: .cascade, inverse: \CachedLemmaUsage.lemma)
    var usages: [CachedLemmaUsage]

    @Relationship(deleteRule: .nullify, inverse: \CachedVocabulary.lemma)
    var linkedVocabularyEntries: [CachedVocabulary]

    @Relationship(deleteRule: .nullify, inverse: \CachedVocabulary.adjunctLemma)
    var adjunctLinkedVocabularyEntries: [CachedVocabulary]

    init(
        stableLemmaId: UUID,
        lemmaText: String,
        languageCode: String = "en"
    ) {
        self.stableLemmaId = stableLemmaId
        self.lemmaText = lemmaText
        self.languageCode = languageCode
        self.usages = []
        self.linkedVocabularyEntries = []
        self.adjunctLinkedVocabularyEntries = []
    }

    /// 辞典パック由来の意味（`kind` に一致する用法行）。
    func packUsageDefinitions(for kind: VocabularyKind) -> (aux: String, target: String) {
        guard let usage = usages.first(where: { $0.kind == kind.rawValue }) else {
            return ("", "")
        }
        let aux = usage.definitionAux?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let target = usage.definitionTarget?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (aux, target)
    }
}
