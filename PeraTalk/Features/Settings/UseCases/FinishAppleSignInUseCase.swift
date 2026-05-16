import Foundation

/// Apple ID トークンによるサインインから、プロフィール同期までを 1 ユースケース内で順実行する。
/// 旧 `SignInWithAppleUseCase` と `SyncProfileAfterSignInUseCase` の連鎖を ScreenModel から消すために統合した。
struct FinishAppleSignInUseCase {
    let authService: any AuthService
    let syncProfileAfterSignInUseCase: SyncProfileAfterSignInUseCase
    let readAuthSessionSnapshotUseCase: ReadAuthSessionSnapshotUseCase

    func execute(idToken: String, nonce: String?, appleProvidedDisplayName: String?) async throws {
        try await authService.signInWithApple(idToken: idToken, nonce: nonce)
        let snapshot = readAuthSessionSnapshotUseCase.execute()
        guard let userId = snapshot.currentUserId else { return }
        try await syncProfileAfterSignInUseCase.execute(
            authenticatedUserId: userId,
            appleProvidedDisplayName: appleProvidedDisplayName
        )
    }
}
