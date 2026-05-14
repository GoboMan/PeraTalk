import SwiftUI

private enum AuthServiceEnvironmentKey: EnvironmentKey {
    private static let stub = StubAuthService()

    static var defaultValue: any AuthService { stub }
}

extension EnvironmentValues {
    var authService: any AuthService {
        get { self[AuthServiceEnvironmentKey.self] }
        set { self[AuthServiceEnvironmentKey.self] = newValue }
    }
}
