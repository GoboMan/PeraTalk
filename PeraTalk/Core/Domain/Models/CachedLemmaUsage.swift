import Foundation
import SwiftData

/// プリセット辞典レマの用法（品詞タブ単位）。ユーザーの `CachedVocabularyUsage` と対応するが、同期フラグは持たない。
@Model
final class CachedLemmaUsage {
    /// `VocabularyKind.rawValue` と整合。
    var kind: String
    var definitionTarget: String?
    var definitionAux: String?
    var ipa: String?
    var position: Int

    var lemma: CachedLemma?

    @Relationship(deleteRule: .cascade, inverse: \CachedLemmaSurface.usage)
    var surfaces: [CachedLemmaSurface]

    init(
        kind: String,
        position: Int,
        definitionTarget: String? = nil,
        definitionAux: String? = nil,
        ipa: String? = nil
    ) {
        self.kind = kind
        self.position = position
        self.definitionTarget = definitionTarget
        self.definitionAux = definitionAux
        self.ipa = ipa
        self.surfaces = []
    }
}
