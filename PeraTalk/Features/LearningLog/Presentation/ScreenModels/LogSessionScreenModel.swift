import Foundation
import Observation

@MainActor
@Observable
final class LogSessionScreenModel {
    var session: CachedSession?

    private let fetchSessionDetailUseCase: FetchSessionDetailUseCase

    init(fetchSessionDetailUseCase: FetchSessionDetailUseCase = FetchSessionDetailUseCase(learningLogService: StubLearningLogService())) {
        self.fetchSessionDetailUseCase = fetchSessionDetailUseCase
    }

    func load(sessionRemoteId: UUID) async {
        session = try? await fetchSessionDetailUseCase.execute(sessionRemoteId: sessionRemoteId)
    }
}
