import Foundation

/// 設定画面のプロフィール・サブスク読み書きを束ねるアプリケーションサービス。
@MainActor
protocol SettingsService {
    func fetchProfile() async throws -> CachedProfile?
    func updateAuxiliaryLanguage(_ language: AuxiliaryLanguage) async throws -> CachedProfile?
    func fetchScreenDisplayPreferences() async throws -> ScreenDisplayPreferences
    func updateScreenDisplayPreferences(_ preferences: ScreenDisplayPreferences) async throws -> CachedProfile?
    func fetchSubscription() async throws -> CachedSubscription?
}
