import Foundation

enum VocabularyListSortOrder: String, Codable, CaseIterable, Identifiable, Sendable {
    case recentlyAdded
    case headwordAZ

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .recentlyAdded: return "追加が新しい順"
        case .headwordAZ: return "見出し語（A〜Z）"
        }
    }
}
