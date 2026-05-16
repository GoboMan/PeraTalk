import Foundation

/// AuthService がミラーしている認証状態を `AuthSessionSnapshot` にまとめて返す読取用ユースケース。
/// ScreenModel から `authService.isAuthenticated` などのプロパティを直接読まないために用意する。
struct ReadAuthSessionSnapshotUseCase {
    let authService: any AuthService

    func execute() -> AuthSessionSnapshot {
        AuthSessionSnapshot(
            isAuthenticated: authService.isAuthenticated,
            currentUserId: authService.currentUserId,
            currentUserEmail: authService.currentUserEmail
        )
    }
}
