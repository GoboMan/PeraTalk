import Foundation
import SwiftData

struct ApplyRemoteDictionaryPackUseCase {
    private let importService: DictionaryPackImportServing

    init(importService: DictionaryPackImportServing = LiveDictionaryPackImportService()) {
        self.importService = importService
    }

    func execute(manifestURL: URL, context: ModelContext) async throws {
        try await importService.downloadAndApplyPack(manifestURL: manifestURL, context: context)
    }
}
