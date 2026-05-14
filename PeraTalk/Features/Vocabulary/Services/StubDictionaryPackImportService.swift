import Foundation
import SwiftData

/// ユニットテストやスタブ用途：インメモリのみの no-op に近い挙動。
struct StubDictionaryPackImportService: DictionaryPackImportServing {
    func importEmbeddedSampleIfNeeded(context: ModelContext) throws {}
    func downloadAndApplyPack(manifestURL: URL, context: ModelContext) async throws {}
}
