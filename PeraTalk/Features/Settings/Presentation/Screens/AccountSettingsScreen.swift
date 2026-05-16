import SwiftUI

struct AccountSettingsScreen: View {
    @Environment(\.authService) private var authService
    @State private var model: AccountScreenModel?

    var body: some View {
        Group {
            if let model {
                accountList(model: model)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("アカウント")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil {
                model = AccountScreenModel.live(authService: authService)
            }
            await model?.startObservingAuthChanges()
        }
    }

    @ViewBuilder
    private func accountList(model: AccountScreenModel) -> some View {
        List {
            if model.authBusy {
                Section {
                    ProgressView()
                }
            }

            if let err = model.lastErrorDescription {
                Section {
                    Text(err)
                        .foregroundStyle(.red)
                }
            }

            Section {
                if let email = model.email, !email.isEmpty {
                    LabeledContent("ログイン", value: email)
                } else {
                    Text("ログイン済み")
                }
                Button("ログアウト", role: .destructive) {
                    Task { await model.signOut() }
                }
                Button("アカウントを削除", role: .destructive) {
                    Task { await model.deleteAccount() }
                }
            } header: {
                Text("サインイン")
            }
        }
    }
}

#Preview {
    NavigationStack {
        AccountSettingsScreen()
    }
}
