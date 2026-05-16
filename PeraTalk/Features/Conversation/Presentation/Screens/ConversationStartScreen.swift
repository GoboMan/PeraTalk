import SwiftUI
import SwiftData
import Supabase

private enum ConversationNavDestination: Hashable {
    case session(UUID)
}

struct ConversationStartScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.supabaseClient) private var supabaseClient

    @Query private var profiles: [CachedProfile]
    @State private var path = NavigationPath()
    @State private var model = ConversationStartScreenModel()

    /// 英会話カードから開くセットアップシート
    @State private var showEnglishConversationSheet = false

    private var showStartScreenGuide: Bool {
        profiles.first?.screenDisplayPreferencesOrDefault.conversation.showStartScreenGuide ?? true
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    hubHeaderStrip
                        .padding(.top, 4)

                    hubSection(title: "英会話") {
                        hubCard(
                            title: "パートナーと英会話",
                            subtitle: "AI ペルソナとテーマを選んで、テキストで往復します。",
                            systemImage: "bubble.left.and.bubble.right.fill"
                        ) {
                            model.prepareEnglishConversationDefaults()
                            showEnglishConversationSheet = true
                        }
                    }

                    hubSection(title: "独り言") {
                        hubCard(
                            title: "英語で独り言",
                            subtitle: "AI の返答なしで、自分のペースで英語のアウトプット練習をします。",
                            systemImage: "person.fill.questionmark"
                        ) {
                            Task { await launchSelfSoliloquyIfPossible() }
                        }
                    }

                    if showStartScreenGuide {
                        guidePanel
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .navigationTitle("会話")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: ConversationNavDestination.self) { dest in
                switch dest {
                case .session(let sessionId):
                    ConversationSessionScreen(sessionRemoteId: sessionId)
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(isPresented: $showEnglishConversationSheet) {
                EnglishConversationSetupSheet(model: model) { session in
                    path.append(ConversationNavDestination.session(session.remoteId))
                }
                .presentationDetents([.large])
                .presentationCornerRadius(24)
            }
        }
        .task {
            model = ConversationPresentationFactory.makeStartScreenModel(
                modelContext: modelContext,
                supabase: supabaseClient
            )
            await model.loadConversationStartData()
        }
    }

    /// 参考レイアウトの上部帯に相当する余白確保・簡易装飾（ストリーク等は製品未定のため未配置）。
    private var hubHeaderStrip: some View {
        HStack {
            Spacer(minLength: 0)
        }
        .frame(height: 8)
    }

    private func hubSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
            content()
        }
    }

    private func hubCard(title: String, subtitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 16) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemGray6))
                    .frame(width: 76, height: 76)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 32))
                            .foregroundStyle(Color.accentColor.opacity(0.85))
                    }
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(18)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var guidePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("開発・同期メモ（表示は設定で無効にできます）", systemImage: "info.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("英会話: AI と往復／独り言: LLM の会話応答なし。ペルソナは英会話で使用します。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func launchSelfSoliloquyIfPossible() async {
        model.resetForSelfSoliloquy()
        guard model.canStartSession else { return }
        do {
            let session = try await model.beginSession()
            path.append(ConversationNavDestination.session(session.remoteId))
        } catch {
            path = NavigationPath()
        }
    }
}
