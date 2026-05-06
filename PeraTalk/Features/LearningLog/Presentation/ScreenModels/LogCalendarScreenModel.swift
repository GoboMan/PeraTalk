import Foundation
import Observation

@MainActor
@Observable
final class LogCalendarScreenModel {
    var selectedMonth: Date = Date()
    var sessionsInMonth: [CachedSession] = []
    var datesWithSessions: Set<DateComponents> = []

    private let fetchCalendarDataUseCase: FetchCalendarDataUseCase

    init(fetchCalendarDataUseCase: FetchCalendarDataUseCase = FetchCalendarDataUseCase(learningLogService: StubLearningLogService())) {
        self.fetchCalendarDataUseCase = fetchCalendarDataUseCase
    }

    func loadMonth(_ date: Date) async {
        selectedMonth = date
        sessionsInMonth = (try? await fetchCalendarDataUseCase.execute(month: date)) ?? []
        datesWithSessions = Set(sessionsInMonth.map {
            Calendar.current.dateComponents([.year, .month, .day], from: $0.startedAt)
        })
    }

    func goToPreviousMonth() async {
        guard let prev = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) else { return }
        await loadMonth(prev)
    }

    func goToNextMonth() async {
        guard let next = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) else { return }
        await loadMonth(next)
    }
}
