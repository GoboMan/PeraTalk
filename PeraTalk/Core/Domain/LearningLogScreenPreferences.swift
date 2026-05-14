import Foundation

struct LearningLogScreenPreferences: Codable, Equatable, Sendable {
    /// カレンダー等で使う週の始まり。
    var calendarFirstWeekday: CalendarFirstWeekdayPreference

    init(calendarFirstWeekday: CalendarFirstWeekdayPreference = .system) {
        self.calendarFirstWeekday = calendarFirstWeekday
    }
}
