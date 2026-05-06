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
                Picker("言語", selection: Binding(
                    get: { model?.auxiliaryLanguage ?? .systemDefault },
                    set: { lang in Task { await model?.changeLanguage(lang) } }
                )) {
                    ForEach(AuxiliaryLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }

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

                NavigationLink {
                    AppearanceSettingsScreen()
                } label: {
                    Text("テーマ・外観")
                }

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
