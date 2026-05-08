import Foundation
import SwiftData

/// レマ用法にひも付く表面形（検索・発話カウントの照会先）。
@Model
final class CachedLemmaSurface {
    var text: String
    /// `LemmaSurfaceFormKind` の rawValue
    var formKindRaw: String
    var ipa: String?

    var usage: CachedLemmaUsage?

    init(text: String, formKindRaw: String, ipa: String? = nil) {
        self.text = text
        self.formKindRaw = formKindRaw
        self.ipa = ipa
    }

    convenience init(text: String, formKind: LemmaSurfaceFormKind, ipa: String? = nil) {
        self.init(text: text, formKindRaw: formKind.rawValue, ipa: ipa)
    }
}
