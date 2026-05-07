import SwiftUI
import SwiftData

struct ConversationStartScreen: View {
    @Query private var profiles: [CachedProfile]
    @State private var model = ConversationStartScreenModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("SCR-CONV-START")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("会話開始画面")
                    .font(.title)

                if showStartScreenGuide {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("モード選択:")
                        Text("  ・Self（独り言）")
                        Text("  ・AI 自由テーマ")
                        Text("  ・AI テーマあり")

                        Divider()

                        Text("ペルソナ選択（6 体）:")
                        Text("  US: Ethan / Chloe")
                        Text("  GB: Oliver / Sophie")
                        Text("  AU: Liam / Isla")

                        Divider()

                        Text("テーマ選択（テーマありモード時）")

                        Divider()

                        Text("「会話を始める」ボタン → セッション画面へ")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.fill.tertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("会話")
        }
    }

    private var showStartScreenGuide: Bool {
        profiles.first?.screenDisplayPreferencesOrDefault.conversation.showStartScreenGuide ?? true
    }
}
