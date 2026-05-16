import Foundation
import Observation

@MainActor
@Observable
final class AccountScreenModel {
    private(set) var snapshot: AuthSessionSnapshot = .signedOut
    private(set) var authBusy = false
    private(set) var lastErrorDescription: String?

    private let warmUpAuthMirrorUseCase: WarmUpAuthMirrorUseCase
    private let authSessionChangesUseCase: AuthSessionChangesUseCase
    private let readAuthSessionSnapshotUseCase: ReadAuthSessionSnapshotUseCase
    private let signOutUseCase: SignOutUseCase
    private let deleteAccountUseCase: DeleteAccountUseCase

    init(
        warmUpAuthMirrorUseCase: WarmUpAuthMirrorUseCase,
        authSessionChangesUseCase: AuthSessionChangesUseCase,
        readAuthSessionSnapshotUseCase: ReadAuthSessionSnapshotUseCase,
        signOutUseCase: SignOutUseCase,
        deleteAccountUseCase: DeleteAccountUseCase
    ) {
        self.warmUpAuthMirrorUseCase = warmUpAuthMirrorUseCase
        self.authSessionChangesUseCase = authSessionChangesUseCase
        self.readAuthSessionSnapshotUseCase = readAuthSessionSnapshotUseCase
        self.signOutUseCase = signOutUseCase
        self.deleteAccountUseCase = deleteAccountUseCase
    }

    var isAuthenticated: Bool { snapshot.isAuthenticated }
    var email: String? { snapshot.currentUserEmail }

    func startObservingAuthChanges() async {
        await warmUpAuthMirrorUseCase.execute()
        refreshSnapshot()
        for await _ in authSessionChangesUseCase.execute() {
            refreshSnapshot()
        }
    }

    private func refreshSnapshot() {
        snapshot = readAuthSessionSnapshotUseCase.execute()
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

    private func run(_ work: @Sendable () async throws -> Void) async {
        authBusy = true
        lastErrorDescription = nil
        defer { authBusy = false }
        do {
            try await work()
            refreshSnapshot()
        } catch {
            lastErrorDescription = error.localizedDescription
        }
    }

    static func live(authService: any AuthService) -> AccountScreenModel {
        AccountScreenModel(
            warmUpAuthMirrorUseCase: WarmUpAuthMirrorUseCase(authService: authService),
            authSessionChangesUseCase: AuthSessionChangesUseCase(authService: authService),
            readAuthSessionSnapshotUseCase: ReadAuthSessionSnapshotUseCase(authService: authService),
            signOutUseCase: SignOutUseCase(authService: authService),
            deleteAccountUseCase: DeleteAccountUseCase(authService: authService)
        )
    }
}
