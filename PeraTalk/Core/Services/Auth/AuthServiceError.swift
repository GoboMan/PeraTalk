import Foundation

enum AuthServiceError: LocalizedError {
    /// `SUPABASE_REST_HOST` / `SUPABASE_PUBLISHABLE_KEY` が Bundle に載らず `StubAuthService` が使われている。
    case supabaseNotConfigured

    var errorDescription: String? {
        switch self {
        case .supabaseNotConfigured:
            "クラウド認証には Supabase の設定が必要です。開発者向け: AppAuthInfo.plist の SUPABASE_REST_HOST と SUPABASE_PUBLISHABLE_KEY（xcconfig の展開）を確認してください。"
        }
    }
}
