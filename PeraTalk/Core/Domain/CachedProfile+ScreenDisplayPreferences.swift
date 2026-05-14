import Foundation

extension CachedProfile {
    var screenDisplayPreferencesOrDefault: ScreenDisplayPreferences {
        ScreenDisplayPreferences.decodeOrDefault(screenDisplayPreferencesData)
    }
}
