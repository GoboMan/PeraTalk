import Foundation

protocol AuthService {
    var currentUserId: UUID? { get }
    var isAuthenticated: Bool { get }
    func signUp(email: String, password: String) async throws
    func signIn(email: String, password: String) async throws
    func signOut() async throws
    func deleteAccount() async throws
}
