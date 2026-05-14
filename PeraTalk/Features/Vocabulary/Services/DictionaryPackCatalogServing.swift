import Foundation

protocol DictionaryPackCatalogServing {
    func fetchEntry(packKey: String) async throws -> DictionaryPackCatalogEntry?
    func fetchAllEntries() async throws -> [DictionaryPackCatalogEntry]
    func publicManifestURL(manifestPath: String) -> URL?
}
