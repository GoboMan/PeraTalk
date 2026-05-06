import Foundation
import Observation

@MainActor
@Observable
final class LogDayScreenModel {
    var date: Date = Date()
    var sessions: [CachedSession] = []

    private let fetchDaySessionsUseCase: FetchDaySessionsUseCase

    init(fetchDaySessionsUseCase: FetchDaySessionsUseCase = FetchDaySessionsUseCase(learningLogService: StubLearningLogService())) {
        self.fetchDaySessionsUseCase = fetchDaySessionsUseCase
    }

    func loadDay(_ date: Date) async {
        self.date = date
        sessions = (try? await fetchDaySessionsUseCase.execute(date: date)) ?? []
    }
}
