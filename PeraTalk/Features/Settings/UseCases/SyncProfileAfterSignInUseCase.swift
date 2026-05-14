import Foundation

struct SyncProfileAfterSignInUseCase {
    let reconciliation: LiveProfileRemoteReconciliationService?

    func execute(authenticatedUserId: UUID) async throws {
        guard let reconciliation else { return }
        try await reconciliation.pullMergeAndTouchLastSeen(authenticatedUserId: authenticatedUserId)
    }
}
