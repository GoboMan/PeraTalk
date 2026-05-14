import Foundation

enum ApplyCatalogRemoteDictionaryPackError: Error {
    case catalogEntryNotFound(packKey: String)
    case invalidManifestURL
}

extension ApplyCatalogRemoteDictionaryPackError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .catalogEntryNotFound(let packKey):
            return "辞書パック「\(packKey)」がサーバーカタログにありません。"
        case .invalidManifestURL:
            return "マニフェスト URL が不正です。"
        }
    }
}
