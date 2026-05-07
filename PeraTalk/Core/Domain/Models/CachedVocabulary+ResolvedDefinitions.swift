import Foundation
import SwiftData

extension CachedVocabulary {
    /// 辞典パックの補助言語定義を合成したうえでの `definitionAux`（詳細・一覧で共通）。
    func resolvedDefinitionAux(for usage: CachedVocabularyUsage) -> String? {
        let fromUsage = usage.definitionAux?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromUsage.isEmpty { return usage.definitionAux }
        if let lemma, let kind = VocabularyKind(kindString: usage.kind) {
            let pack = lemma.packUsageDefinitions(for: kind)
            let packAux = pack.aux.trimmingCharacters(in: .whitespacesAndNewlines)
            if !packAux.isEmpty { return pack.aux }
        }
        return usage.definitionAux
    }

    /// 辞典パックのターゲット言語定義を合成したうえでの `definitionTarget`（詳細・一覧で共通）。
    func resolvedDefinitionTarget(for usage: CachedVocabularyUsage) -> String? {
        let fromUsage = usage.definitionTarget?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromUsage.isEmpty { return usage.definitionTarget }
        if let lemma, let kind = VocabularyKind(kindString: usage.kind) {
            let pack = lemma.packUsageDefinitions(for: kind)
            let packTarget = pack.target.trimmingCharacters(in: .whitespacesAndNewlines)
            if !packTarget.isEmpty { return pack.target }
        }
        return usage.definitionTarget
    }
}
