import Foundation

/// Supabase Auth（Google OAuth 等）のリダイレクト先。ダッシュボードの Redirect URLs にも同じ値を登録する。
enum SupabaseOAuthRedirect {
    static let callbackURL = URL(string: "com.tsay.peratalk://auth-callback")!
}
