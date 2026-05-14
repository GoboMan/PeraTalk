import Foundation

enum ListRowDensity: String, Codable, CaseIterable, Identifiable, Sendable {
    case comfortable
    case compact

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .comfortable: return "広め"
        case .compact: return "詰めて表示"
        }
    }
}
