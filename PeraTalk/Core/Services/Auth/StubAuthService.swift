import Foundation

struct StubAuthService: AuthService {
    var currentUserId: UUID? { nil }
    var isAuthenticated: Bool { false }
    func signUp(email: String, password: String) async throws {}
    func signIn(email: String, password: String) async throws {}
    func signOut() async throws {}
    func deleteAccount() async throws {}
}
