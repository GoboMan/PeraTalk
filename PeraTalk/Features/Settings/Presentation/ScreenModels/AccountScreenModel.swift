import AuthenticationServices
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AccountScreenModel {
    private(set) var isAuthenticatedSnapshot = false
    private(set) var emailSnapshot: String?
    private(set) var authBusy = false
    private(set) var lastErrorDescription: String?

    private let authService: any AuthService
    private let signInWithAppleUseCase: SignInWithAppleUseCase
    private let signInWithGoogleUseCase: SignInWithGoogleUseCase
    private let signOutUseCase: SignOutUseCase
    private let deleteAccountUseCase: DeleteAccountUseCase
    private let syncProfileAfterSignInUseCase: SyncProfileAfterSignInUseCase

    init(
        authService: any AuthService,
        signInWithAppleUseCase: SignInWithAppleUseCase,
        signInWithGoogleUseCase: SignInWithGoogleUseCase,
        signOutUseCase: SignOutUseCase,
        deleteAccountUseCase: DeleteAccountUseCase,
        syncProfileAfterSignInUseCase: SyncProfileAfterSignInUseCase
    ) {
        self.authService = authService
        self.signInWithAppleUseCase = signInWithAppleUseCase
        self.signInWithGoogleUseCase = signInWithGoogleUseCase
        self.signOutUseCase = signOutUseCase
        self.deleteAccountUseCase = deleteAccountUseCase
        self.syncProfileAfterSignInUseCase = syncProfileAfterSignInUseCase
    }

    func startObservingAuthChanges() async {
        await authService.warmUpSessionMirror()
        refreshAuthSnapshot()
        for await _ in authService.authSessionChanges() {
            refreshAuthSnapshot()
        }
    }

    private func refreshAuthSnapshot() {
        isAuthenticatedSnapshot = authService.isAuthenticated
        emailSnapshot = authService.currentUserEmail
    }

    func ingestError(_ error: Error) {
        if let authorizationError = error as? ASAuthorizationError {
            lastErrorDescription = Self.userFacingMessage(for: authorizationError)
        } else {
            lastErrorDescription = error.localizedDescription
        }
    }

    private static func userFacingMessage(for error: ASAuthorizationError) -> String {
        switch error.code {
        case .canceled:
            "サインインがキャンセルされました。"
        case .failed:
            "Sign in with Apple に失敗しました。Apple ID とネットワークを確認してください。"
        case .invalidResponse:
            "応答が無効でした。しばらくしてから再度お試しください。"
        case .notHandled:
            "サインイン要求を処理できませんでした。アプリを再起動してからお試しください。"
        case .unknown:
            """
            Sign in with Apple が利用できません（端末側の許可または開発者設定の不足がよくあります）。

            【実機・TestFlight】Xcode でターゲットの Signing & Capabilities に「Sign In with Apple」を追加し、Certificates, Identifiers & Profiles で App ID（Bundle ID）に Sign in with Apple をオンにしてください。

            【シミュレータ】「設定」で Apple アカウント／iCloud にサインインしてから試してください。
            """
        case .notInteractive:
            error.localizedDescription
        case .matchedExcludedCredential:
            error.localizedDescription
        case .credentialImport:
            error.localizedDescription
        case .credentialExport:
            error.localizedDescription
        case .preferSignInWithApple:
            error.localizedDescription
        case .deviceNotConfiguredForPasskeyCreation:
            error.localizedDescription
        @unknown default:
            error.localizedDescription
        }
    }

    func signInWithApple(idToken: String, nonce: String?) async {
        await run {
            try await signInWithAppleUseCase.execute(idToken: idToken, nonce: nonce)
            try await syncIfPossible()
        }
    }

    func signInWithGoogle() async {
        await run {
            try await signInWithGoogleUseCase.execute()
            try await syncIfPossible()
        }
    }

    func signOut() async {
        await run {
            try await signOutUseCase.execute()
        }
    }

    func deleteAccount() async {
        await run {
            try await deleteAccountUseCase.execute()
        }
    }

    private func syncIfPossible() async throws {
        guard let userId = authService.currentUserId else { return }
        try await syncProfileAfterSignInUseCase.execute(authenticatedUserId: userId)
    }

    private func run(_ work: @Sendable () async throws -> Void) async {
        authBusy = true
        lastErrorDescription = nil
        defer { authBusy = false }
        do {
            try await work()
            refreshAuthSnapshot()
        } catch {
            lastErrorDescription = error.localizedDescription
        }
    }

    static func live(
        modelContext: ModelContext,
        authService: any AuthService,
        tableClient: (any SupabaseTableClient)?
    ) -> AccountScreenModel {
        let profileRepo = SwiftDataProfileRepository(context: modelContext)
        let reconciliation: LiveProfileRemoteReconciliationService?
        if let tableClient {
            reconciliation = LiveProfileRemoteReconciliationService(tableClient: tableClient, profileRepository: profileRepo)
        } else {
            reconciliation = nil
        }
        let sync = SyncProfileAfterSignInUseCase(reconciliation: reconciliation)
        return AccountScreenModel(
            authService: authService,
            signInWithAppleUseCase: SignInWithAppleUseCase(authService: authService),
            signInWithGoogleUseCase: SignInWithGoogleUseCase(authService: authService),
            signOutUseCase: SignOutUseCase(authService: authService),
            deleteAccountUseCase: DeleteAccountUseCase(authService: authService),
            syncProfileAfterSignInUseCase: sync
        )
    }
}
