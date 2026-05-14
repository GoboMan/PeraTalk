import Foundation

enum SeedVocabularyFromLemmaError: LocalizedError {
    case lemmaNotFound

    var errorDescription: String? {
        switch self {
        case .lemmaNotFound: "辞典に該当するレマが見つかりませんでした。"
        }
    }
}
