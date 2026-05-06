import Foundation
import SwiftData

/// バンドル内の **`dictionary_scaffold_pack.json`** を、`CachedLemma` がまだ無いときだけ SwiftData に取り込む。
struct ImportEmbeddedDictionarySampleUseCase {
    private let importService: DictionaryPackImportServing

    init(importService: DictionaryPackImportServing = LiveDictionaryPackImportService()) {
        self.importService = importService
    }

    func execute(context: ModelContext) throws {
        try importService.importEmbeddedSampleIfNeeded(context: context)
    }
}
