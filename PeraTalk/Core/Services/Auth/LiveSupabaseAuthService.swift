import Foundation
import Supabase

private struct EmptyInvokeBody: Encodable {}

@MainActor
final class LiveSupabaseAuthService: AuthService {
    private let client: SupabaseClient

    private(set) var mirroredSession: Session?

    /// `authStateChanges` は参照のたびに独立ストリームになるため、複数画面が別 Task で await するとミラーと yield の順序が崩れる。
    /// 単一ポンプでセッションを反映し、登録された購読へだけブロードキャストする。
    private var authSessionContinuations: [UUID: AsyncStream<Bool>.Continuation] = [:]
    private var authStatePump: Task<Void, Never>?

    init(client: SupabaseClient) {
        self.client = client
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

    /// 単一購読系統で `mirroredSession` を更新したうえで購読者に通知する。
    func authSessionChanges() -> AsyncStream<Bool> {
        startAuthStatePumpIfNeeded()
        let registrationID = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: Bool.self)
        authSessionContinuations[registrationID] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in
                self?.authSessionContinuations.removeValue(forKey: registrationID)
            }
        }
        continuation.yield(isAuthenticated)
        return stream
    }

    private func startAuthStatePumpIfNeeded() {
        guard authStatePump == nil else { return }
        authStatePump = Task { @MainActor in
            for await (_, session) in client.auth.authStateChanges {
                applyMirroredSession(session)
            }
        }
    }

    private func applyMirroredSession(_ session: Session?) {
        mirroredSession = session
        yieldAuthenticatedToAllSubscribers(session != nil)
    }

    /// SDK イベントが届かない場合でもルートゲートを確実に更新する。
    private func yieldAuthenticatedToAllSubscribers(_ isAuthenticated: Bool) {
        for continuation in authSessionContinuations.values {
            continuation.yield(isAuthenticated)
        }
    }

    private func syncMirrorAfterAuthMutation() async {
        await warmUpSessionMirror()
        yieldAuthenticatedToAllSubscribers(isAuthenticated)
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

    func signOut() async throws {
        try await client.auth.signOut()
        await syncMirrorAfterAuthMutation()
    }

    func deleteAccount() async throws {
        try await client.functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions(body: EmptyInvokeBody())
        )
        try await signOut()
    }
}
