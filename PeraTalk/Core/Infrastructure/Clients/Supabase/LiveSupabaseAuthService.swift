import Foundation
import Supabase

private struct EmptyInvokeBody: Encodable {}

@MainActor
final class LiveSupabaseAuthService: AuthService {
    private let client: SupabaseClient

    private(set) var mirroredSession: Session?

    init(client: SupabaseClient) {
        self.client = client
        Task { await self.listenAuthEvents() }
    }

    var currentUserId: UUID? {
        mirroredSession?.user.id
    }

    var isAuthenticated: Bool {
        mirroredSession != nil
    }

    var currentUserEmail: String? {
        mirroredSession?.user.email
    }

    func warmUpSessionMirror() async {
        do {
            mirroredSession = try await client.auth.session
        } catch {
            mirroredSession = nil
        }
    }

    private func listenAuthEvents() async {
        for await (_, session) in client.auth.authStateChanges {
            mirroredSession = session
        }
    }

    func authSessionChanges() -> AsyncStream<Bool> {
        let (stream, continuation) = AsyncStream.makeStream(of: Bool.self)
        Task { @MainActor in
            continuation.yield(isAuthenticated)
            for await (_, session) in client.auth.authStateChanges {
                continuation.yield(session != nil)
            }
        }
        return stream
    }

    func signUp(email: String, password: String) async throws {
        _ = try await client.auth.signUp(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
    }

    func signInWithApple(idToken: String, nonce: String?) async throws {
        _ = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }

    func signInWithGoogleOAuth() async throws {
        _ = try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: SupabaseOAuthRedirect.callbackURL
        )
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func deleteAccount() async throws {
        try await client.functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions(body: EmptyInvokeBody())
        )
        try await client.auth.signOut()
    }
}
