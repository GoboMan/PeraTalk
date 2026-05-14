import SwiftData
import SwiftUI

struct ConversationDisplaySettingsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @State private var model: ScreenDisplaySettingsScreenModel?

    var body: some View {
        Group {
            if let model {
                Form {
                    Section {
                        Toggle("開始画面のガイドを表示", isOn: ScreenDisplaySettingsViewBindings.showConversationGuide(model))
                    } footer: {
                        Text("会話タブの説明テキストやプレースホルダーUIの表示を切り替えられます。")
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("会話")
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

#Preview("会話") {
    NavigationStack {
        ConversationDisplaySettingsScreen()
    }
    .modelContainer(previewContainer)
}
