import AuthenticationServices
import SwiftData
import SwiftUI

struct AccountSettingsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.authService) private var authService
    @Environment(\.supabaseTableClient) private var tableClient
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
                model = AccountScreenModel.live(
                    modelContext: modelContext,
                    authService: authService,
                    tableClient: tableClient
                )
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
                if model.isAuthenticatedSnapshot {
                    if let email = model.emailSnapshot, !email.isEmpty {
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
                } else {
                    // nonce は無しで進める（supabase-swift 公式サンプルと同様）。独自 nonce を付ける場合は
                    // Apple が期待する SHA256 の表現（多くは Base64 付きハッシュ）に合わせる必要がある。
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        switch result {
                        case let .success(authorization):
                            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
                            guard let tokenData = credential.identityToken else { return }
                            guard let idToken = String(data: tokenData, encoding: .utf8) else { return }
                            Task { await model.signInWithApple(idToken: idToken, nonce: nil) }
                        case let .failure(error):
                            Task { @MainActor in model.ingestError(error) }
                        }
                    }
                    .frame(height: 44)

                    Button {
                        Task { await model.signInWithGoogle() }
                    } label: {
                        Text("Google で続ける")
                    }
                }
            } header: {
                Text("サインイン")
            } footer: {
                if tableClient == nil {
                    Text("Supabase が未構成の環境ではクラウド会話にサインインできません。")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AccountSettingsScreen()
    }
    .modelContainer(previewContainer)
}
