import Foundation

/// AuthService がミラーしている認証状態の表示用スナップショット。
/// ScreenModel は AuthService を直接見ず、`ReadAuthSessionSnapshotUseCase` 経由でこの値だけを参照する。
struct AuthSessionSnapshot: Equatable, Sendable {
    let isAuthenticated: Bool
    let currentUserId: UUID?
    let currentUserEmail: String?

    static let signedOut = AuthSessionSnapshot(
        isAuthenticated: false,
        currentUserId: nil,
        currentUserEmail: nil
    )
}
