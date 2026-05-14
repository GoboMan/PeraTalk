import Foundation
import SwiftData

protocol DictionaryPackImportServing {
    /// バンドル内のサンプルパックを、`CachedLemma` が 0 件のときだけ投入する。
    func importEmbeddedSampleIfNeeded(context: ModelContext) throws
    /// マニフェスト URL → ペイロードダウンロード → SHA256 検証（指定時）→ 全レンマ差し替え。
    func downloadAndApplyPack(manifestURL: URL, context: ModelContext) async throws
}
