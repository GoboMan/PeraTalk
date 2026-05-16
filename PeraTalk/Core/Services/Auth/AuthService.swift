import Foundation

/// Supabase Auth（メール／OAuth）の窓口。Live 実装は `LiveSupabaseAuthService`。
protocol AuthService {
    var currentUserId: UUID? { get }
    var isAuthenticated: Bool { get }
    var currentUserEmail: String? { get }

    /// 起動直後など、端末に保持されたセッションを `currentUserId` / `isAuthenticated` に反映する。
    func warmUpSessionMirror() async

    /// `isAuthenticated` の変化を追跡する。初回も必ず 1 回以上 yield する。
    func authSessionChanges() -> AsyncStream<Bool>

    func signUp(email: String, password: String) async throws
    func signIn(email: String, password: String) async throws
    func signInWithApple(idToken: String, nonce: String?) async throws
    func signOut() async throws
    func deleteAccount() async throws
}
