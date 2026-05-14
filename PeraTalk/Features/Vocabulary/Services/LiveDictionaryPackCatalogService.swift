import Foundation

/// PostgREST でカタログを読み、`dictionary-packs` 公開バケットのマニフェスト URL を組み立てる。
final class LiveDictionaryPackCatalogService: DictionaryPackCatalogServing {
    private let supabaseURL: URL
    private let tableClient: any SupabaseTableClient

    init(supabaseURL: URL, tableClient: any SupabaseTableClient) {
        self.supabaseURL = supabaseURL
        self.tableClient = tableClient
    }

    func fetchEntry(packKey: String) async throws -> DictionaryPackCatalogEntry? {
        let rows: [DictionaryPackCatalogEntry] = try await tableClient.fetch(
            from: "dictionary_pack_catalog",
            whereColumn: "pack_key",
            equals: packKey
        )
        return rows.first
    }

    func fetchAllEntries() async throws -> [DictionaryPackCatalogEntry] {
        try await tableClient.fetch(from: "dictionary_pack_catalog", since: nil)
    }

    func publicManifestURL(manifestPath: String) -> URL? {
        let base = supabaseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let path = manifestPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !path.isEmpty else { return nil }
        return URL(string: "\(base)/storage/v1/object/public/dictionary-packs/\(path)")
    }
}
