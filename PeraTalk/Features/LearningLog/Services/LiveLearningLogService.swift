import Foundation

struct LiveLearningLogService: LearningLogService {
    private let repository: any LearningLogRepository

    init(repository: any LearningLogRepository) {
        self.repository = repository
    }

    func fetchSessionsInMonth(_ month: Date) async throws -> [CachedSession] {
        try await repository.fetchSessionsInMonth(month)
    }

    func fetchSessionsByDate(_ date: Date) async throws -> [CachedSession] {
        try await repository.fetchSessionsByDate(date)
    }

    func fetchSession(remoteId: UUID) async throws -> CachedSession? {
        try await repository.fetchSession(remoteId: remoteId)
    }
}
