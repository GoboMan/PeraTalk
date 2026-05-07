import Foundation
import SwiftData

@Model
final class CachedProfile {
    @Attribute(.unique) var remoteId: UUID
    var displayName: String?
    var auxiliaryLanguage: String
    var appearanceTheme: String?
    /// `ScreenDisplayPreferences` の JSON（主要タブごとの表示設定）。
    var screenDisplayPreferencesData: Data?
    var remoteUpdatedAt: Date
    var cachedAt: Date

    init(
        remoteId: UUID = UUID(),
        auxiliaryLanguage: String = "ja",
        remoteUpdatedAt: Date = Date(),
        screenDisplayPreferencesData: Data? = nil
    ) {
        self.remoteId = remoteId
        self.displayName = nil
        self.auxiliaryLanguage = auxiliaryLanguage
        self.appearanceTheme = nil
        self.screenDisplayPreferencesData = screenDisplayPreferencesData
        self.remoteUpdatedAt = remoteUpdatedAt
        self.cachedAt = Date()
    }
}
