import SwiftUI
import SwiftData
import StoreKit

struct SettingsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @State private var model: SettingsScreenModel?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("言語", selection: Binding(
                        get: { model?.auxiliaryLanguage ?? .systemDefault },
                        set: { lang in Task { await model?.changeLanguage(lang) } }
                    )) {
                        ForEach(AuxiliaryLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                } header: {
                    Text("アプリ")
                }

                Section {
                    NavigationLink {
                        AccountSettingsScreen()
                    } label: {
                        Text("アカウント")
                    }

                    NavigationLink {
                        PlanSettingsScreen()
                    } label: {
                        Text("プラン")
                    }
                } header: {
                    Text("アカウントとプラン")
                }

                Section {
                    NavigationLink {
                        AppearanceSettingsScreen()
                    } label: {
                        Text("テーマ・外観")
                    }

                    NavigationLink {
                        LearningLogDisplaySettingsScreen()
                    } label: {
                        Text("学習ログ")
                    }

                    NavigationLink {
                        ConversationDisplaySettingsScreen()
                    } label: {
                        Text("会話")
                    }

                    NavigationLink {
                        VocabularyTabDisplaySettingsScreen()
                    } label: {
                        Text("単語帳")
                    }
                } header: {
                    Text("画面の表示")
                } footer: {
                    Text("タブごとに一覧やガイド表示などを調整できます。")
                }

                Section {
                    NavigationLink {
                        TermsScreen()
                    } label: {
                        Text("利用規約")
                    }

                    NavigationLink {
                        PrivacyPolicyScreen()
                    } label: {
                        Text("プライバシーポリシー")
                    }
                } header: {
                    Text("法的情報")
                }

                Section {
                    Button {
                        requestReview()
                    } label: {
                        HStack {
                            Text("レビュー")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                    }
                    .tint(.primary)
                } header: {
                    Text("このアプリについて")
                }
            }
            .navigationTitle("設定")
            .task {
                if model == nil {
                    model = SettingsScreenModel.live(modelContext: modelContext)
                }
                await model?.loadProfile()
            }
        }
    }
}

// MARK: - Placeholder Screens

private struct AccountSettingsScreen: View {
    var body: some View {
        List {
            Text("アカウント情報")
        }
        .navigationTitle("アカウント")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PlanSettingsScreen: View {
    var body: some View {
        List {
            Text("プラン情報")
        }
        .navigationTitle("プラン")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AppearanceSettingsScreen: View {
    var body: some View {
        List {
            Text("テーマ・外観設定")
        }
        .navigationTitle("テーマ・外観")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TermsScreen: View {
    var body: some View {
        ScrollView {
            Text("利用規約の内容")
                .padding()
        }
        .navigationTitle("利用規約")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacyPolicyScreen: View {
    var body: some View {
        ScrollView {
            Text("プライバシーポリシーの内容")
                .padding()
        }
        .navigationTitle("プライバシーポリシー")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsScreen()
}
