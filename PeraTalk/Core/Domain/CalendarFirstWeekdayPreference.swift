import Foundation

enum CalendarFirstWeekdayPreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case sunday
    case monday

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "システムに合わせる"
        case .sunday: return "日曜始まり"
        case .monday: return "月曜始まり"
        }
    }

    /// `Calendar.Component` に合わせた `firstWeekday`（日曜 = 1）。
    func resolvedFirstWeekday(calendar: Calendar) -> Int {
        switch self {
        case .system: return calendar.firstWeekday
        case .sunday: return 1
        case .monday: return 2
        }
    }
}
