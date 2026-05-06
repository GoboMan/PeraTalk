import Foundation

struct FetchSessionDetailUseCase {
    let learningLogService: any LearningLogService

    func execute(sessionRemoteId: UUID) async throws -> CachedSession? {
        try await learningLogService.fetchSession(remoteId: sessionRemoteId)
    }
}
