import Foundation

struct SyncProfileAfterSignInUseCase {
    let reconciliation: LiveProfileRemoteReconciliationService?

    func execute(authenticatedUserId: UUID, appleProvidedDisplayName: String? = nil) async throws {
        guard let reconciliation else { return }
        try await reconciliation.pullMergeAndTouchLastSeen(
            authenticatedUserId: authenticatedUserId,
            appleProvidedDisplayName: appleProvidedDisplayName
        )
    }
}
