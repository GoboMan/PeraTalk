import Foundation

struct FetchCalendarDataUseCase {
    let learningLogService: any LearningLogService

    func execute(month: Date) async throws -> [CachedSession] {
        try await learningLogService.fetchSessionsInMonth(month)
    }
}
