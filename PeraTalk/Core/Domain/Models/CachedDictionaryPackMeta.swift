import Foundation
import SwiftData

/// 端末に適用済みの辞書パック（サーバー側 `vocabulary` 同期とは別系統）。
@Model
final class CachedDictionaryPackMeta {
    /// 例: `en_lemmas` — パック単位で 1 行。
    @Attribute(.unique) var packKey: String
    /// 論理バージョン（マニフェストの `pack_version` と照合）。
    var installedVersion: String
    /// 直近で検証したペイロードの SHA256（hex）。任意。
    var installedContentSHA256: String?
    var installedAt: Date

    init(
        packKey: String,
        installedVersion: String,
        installedContentSHA256: String? = nil,
        installedAt: Date = Date()
    ) {
        self.packKey = packKey
        self.installedVersion = installedVersion
        self.installedContentSHA256 = installedContentSHA256
        self.installedAt = installedAt
    }
}
