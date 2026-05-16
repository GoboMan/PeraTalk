import AuthenticationServices
import SwiftData
import SwiftUI

struct SignInScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.authService) private var authService
    @Environment(\.supabaseTableClient) private var tableClient
    @State private var model: SignInScreenModel?

    private static func composeDisplayName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .default
        let formatted = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
        return formatted.isEmpty ? nil : formatted
    }

    var body: some View {
        Group {
            if let model {
                content(model: model)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if model == nil {
                model = SignInScreenModel.live(
                    modelContext: modelContext,
                    authService: authService,
                    tableClient: tableClient
                )
            }
        }
    }

    @ViewBuilder
    private func content(model: SignInScreenModel) -> some View {
        let supabaseReady = tableClient != nil

        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text("PeraTalk へようこそ")
                    .font(.title.weight(.bold))
                Text("続けるには Apple でサインインしてください。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            if model.isBusy {
                ProgressView()
            }

            if let err = model.lastErrorDescription {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            VStack(spacing: 12) {
                // nonce なし（supabase-swift と同様）。独自 nonce が必要になった場合は SHA256 等で Apple と揃える。
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case let .success(authorization):
                        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
                        guard let tokenData = credential.identityToken else { return }
                        guard let idToken = String(data: tokenData, encoding: .utf8) else { return }
                        let displayName = Self.composeDisplayName(from: credential.fullName)
                        Task { await model.signInWithApple(idToken: idToken, nonce: nil, displayName: displayName) }
                    case let .failure(error):
                        Task { @MainActor in model.ingestAuthorizationError(error) }
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .disabled(!supabaseReady || model.isBusy)

                if !supabaseReady {
                    Text("Supabase が未構成のためサインインできません。AppAuthInfo.plist の SUPABASE_REST_HOST と SUPABASE_PUBLISHABLE_KEY を確認してください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
