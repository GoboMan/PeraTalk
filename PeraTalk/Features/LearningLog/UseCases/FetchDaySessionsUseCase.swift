import Foundation

struct FetchDaySessionsUseCase {
    let learningLogService: any LearningLogService

    func execute(date: Date) async throws -> [CachedSession] {
        try await learningLogService.fetchSessionsByDate(date)
    }
}
