import Foundation

/// Supabase `dictionary_pack_catalog` の行（マニフェストは Storage `dictionary-packs` バケット内）。
struct DictionaryPackCatalogEntry: Decodable, Sendable, Equatable {
    let packKey: String
    let packVersion: String
    let sha256: String?
    let manifestPath: String
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case packKey = "pack_key"
        case packVersion = "pack_version"
        case sha256
        case manifestPath = "manifest_path"
        case updatedAt = "updated_at"
    }
}
