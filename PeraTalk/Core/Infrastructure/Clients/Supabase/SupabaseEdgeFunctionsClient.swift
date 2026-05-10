import Foundation

/// Supabase Edge Functions の呼び出し口（各関数の本体は未実装スタブ）。
/// SSOT: リポジトリの `PeraTalk/docs/アーキテクチャ/データベース設計-サーバー.md`・`PeraTalk/docs/運営/収益とサブスク.md`。
protocol SupabaseEdgeFunctionsClient: Sendable {
    /// App Store Server Notifications V2。本番では Apple → 同関数へ直接 POST。結合テスト用にクライアントからも呼べる。
    func postAppleAppStoreServerNotification() async throws
    /// StoreKit 購入のクライアント検証（補助経路）。
    func verifyStoreKitPurchase() async throws
    /// アカウント削除（service role 側処理へのプロキシ。クライアントはログイン JWT で呼ぶ想定）。
    func deleteAuthenticatedAccount() async throws
    /// 記憶用要約・ベクトルチャンクの取り込み。
    func ingestSessionMemory() async throws
    /// 長期非ログイン時の通知・削除バッチ（主に Cron。手動検証用にも公開可）。
    func runDataRetentionBatch() async throws
}
