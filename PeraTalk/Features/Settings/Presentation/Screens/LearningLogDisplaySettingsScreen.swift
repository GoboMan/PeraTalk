import SwiftData
import SwiftUI

struct LearningLogDisplaySettingsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @State private var model: ScreenDisplaySettingsScreenModel?

    var body: some View {
        Group {
            if let model {
                Form {
                    Section {
                        Picker("週の始まり", selection: ScreenDisplaySettingsViewBindings.calendarFirstWeekday(model)) {
                            ForEach(CalendarFirstWeekdayPreference.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                    } footer: {
                        Text("カレンダー実装時に、この設定が週グリッドの並びに反映されます。")
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("学習ログ")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadModelIfNeeded()
        }
    }

    private func loadModelIfNeeded() async {
        if model == nil {
            model = ScreenDisplaySettingsScreenModel.live(modelContext: modelContext)
        }
        await model?.load()
    }
}

#Preview("学習ログ") {
    NavigationStack {
        LearningLogDisplaySettingsScreen()
    }
    .modelContainer(previewContainer)
}
