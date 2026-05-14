import Foundation
import SwiftData

/// `dictionary_pack_catalog` の `manifest_path` から公開マニフェスト URL を解決し、ペイロードを取得して適用する。
struct ApplyCatalogRemoteDictionaryPackUseCase {
    private let catalogService: any DictionaryPackCatalogServing
    private let importService: any DictionaryPackImportServing

    init(
        catalogService: any DictionaryPackCatalogServing,
        importService: any DictionaryPackImportServing = LiveDictionaryPackImportService()
    ) {
        self.catalogService = catalogService
        self.importService = importService
    }

    func execute(packKey: String, context: ModelContext) async throws {
        guard let entry = try await catalogService.fetchEntry(packKey: packKey) else {
            throw ApplyCatalogRemoteDictionaryPackError.catalogEntryNotFound(packKey: packKey)
        }
        guard let manifestURL = catalogService.publicManifestURL(manifestPath: entry.manifestPath) else {
            throw ApplyCatalogRemoteDictionaryPackError.invalidManifestURL
        }
        try await importService.downloadAndApplyPack(manifestURL: manifestURL, context: context)
    }
}
