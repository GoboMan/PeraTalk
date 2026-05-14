import SwiftUI

/// `ScreenDisplaySettingsScreenModel` の入れ子フィールドへの `Binding` をまとめて提供する補助。
/// 各タブ別画面（学習ログ・会話・単語帳）がこれを参照して `Toggle`/`Picker` を組み立てる。
enum ScreenDisplaySettingsViewBindings {
    static func calendarFirstWeekday(_ model: ScreenDisplaySettingsScreenModel) -> Binding<CalendarFirstWeekdayPreference> {
        Binding(
            get: { model.preferences.learningLog.calendarFirstWeekday },
            set: { newValue in
                Task { await model.update { $0.learningLog.calendarFirstWeekday = newValue } }
            }
        )
    }

    static func showConversationGuide(_ model: ScreenDisplaySettingsScreenModel) -> Binding<Bool> {
        Binding(
            get: { model.preferences.conversation.showStartScreenGuide },
            set: { newValue in
                Task { await model.update { $0.conversation.showStartScreenGuide = newValue } }
            }
        )
    }

    static func vocabularySortOrder(_ model: ScreenDisplaySettingsScreenModel) -> Binding<VocabularyListSortOrder> {
        Binding(
            get: { model.preferences.vocabularyList.sortOrder },
            set: { newValue in
                Task { await model.update { $0.vocabularyList.sortOrder = newValue } }
            }
        )
    }

    static func vocabularyListDensity(_ model: ScreenDisplaySettingsScreenModel) -> Binding<ListRowDensity> {
        Binding(
            get: { model.preferences.vocabularyList.listDensity },
            set: { newValue in
                Task { await model.update { $0.vocabularyList.listDensity = newValue } }
            }
        )
    }

    static func vocabularyShowJapaneseDefinition(_ model: ScreenDisplaySettingsScreenModel) -> Binding<Bool> {
        Binding(
            get: { model.preferences.vocabularyList.showJapaneseDefinition },
            set: { newValue in
                Task { await model.update { $0.vocabularyList.showJapaneseDefinition = newValue } }
            }
        )
    }

    static func vocabularyShowEnglishDefinition(_ model: ScreenDisplaySettingsScreenModel) -> Binding<Bool> {
        Binding(
            get: { model.preferences.vocabularyList.showEnglishDefinition },
            set: { newValue in
                Task { await model.update { $0.vocabularyList.showEnglishDefinition = newValue } }
            }
        )
    }

    static func vocabularyShowPronunciation(_ model: ScreenDisplaySettingsScreenModel) -> Binding<Bool> {
        Binding(
            get: { model.preferences.vocabularyList.showPronunciation },
            set: { newValue in
                Task { await model.update { $0.vocabularyList.showPronunciation = newValue } }
            }
        )
    }
}
