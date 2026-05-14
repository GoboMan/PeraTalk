import Foundation

struct SignInWithAppleUseCase {
    let authService: any AuthService

    func execute(idToken: String, nonce: String?) async throws {
        try await authService.signInWithApple(idToken: idToken, nonce: nonce)
    }
}
