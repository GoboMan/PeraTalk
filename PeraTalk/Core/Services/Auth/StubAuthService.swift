import Foundation

struct StubAuthService: AuthService {
    var currentUserId: UUID? { nil }
    var isAuthenticated: Bool { false }
    var currentUserEmail: String? { nil }

    func warmUpSessionMirror() async {}

    func authSessionChanges() -> AsyncStream<Bool> {
        let (stream, continuation) = AsyncStream.makeStream(of: Bool.self)
        continuation.yield(false)
        continuation.finish()
        return stream
    }

    func signUp(email: String, password: String) async throws {
        throw AuthServiceError.supabaseNotConfigured
    }

    func signIn(email: String, password: String) async throws {
        throw AuthServiceError.supabaseNotConfigured
    }

    func signInWithApple(idToken: String, nonce: String?) async throws {
        throw AuthServiceError.supabaseNotConfigured
    }

    func signOut() async throws {}

    func deleteAccount() async throws {
        throw AuthServiceError.supabaseNotConfigured
    }
}
