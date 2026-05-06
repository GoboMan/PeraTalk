import Foundation

struct DeleteAccountUseCase {
    let authService: any AuthService

    func execute() async throws {
        try await authService.deleteAccount()
    }
}
