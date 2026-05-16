import Observation
import SwiftData
import SwiftUI

/// 英会話モード開始前のペルソナ・テーマ選択（参考レイアウト: 下部シート＋横スクロール）。
struct EnglishConversationSetupSheet: View {
    @Bindable var model: ConversationStartScreenModel
    @Environment(\.dismiss) private var dismiss

    let onStart: (CachedSession) -> Void

    private static let modalEdgePadding = CGFloat(24)
    /// 横スクロールの先頭・末尾でカードの枠線や影が切れないようにする。
    private static let horizontalScrollGutter = CGFloat(20)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    partnerSection
                    topicStartSection
                }
                .padding(.horizontal, Self.modalEdgePadding)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .navigationTitle("英会話")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("閉じる")
                }
            }
            .safeAreaInset(edge: .bottom) {
                startButton
            }
            .task {
                await model.loadConversationStartData()
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var partnerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("会話パートナー")
            if model.personas.isEmpty {
                Text("ペルソナを読み込み中です。しばらく待ってから再度お試しください。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(model.personas, id: \.remoteId) { persona in
                            PersonaChoiceCard(
                                persona: persona,
                                isSelected: model.selectedPersonaId == persona.remoteId
                            ) {
                                model.selectedPersonaId = persona.remoteId
                            }
                        }
                    }
                    .padding(.vertical, 10)
                }
                .contentMargins(.horizontal, Self.horizontalScrollGutter, for: .scrollContent)
            }
        }
    }

    private var topicStartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("会話の始め方")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ThemeStyleCard(
                        title: "フリートーク",
                        systemImage: "bubble.left.and.bubble.right.fill",
                        isSelected: model.selectedMode == .aiFree
                    ) {
                        model.selectEnglishFreeTalk()
                    }
                    ForEach(model.themes, id: \.remoteId) { theme in
                        ThemeStyleCard(
                            title: theme.name,
                            systemImage: "text.book.closed.fill",
                            isSelected: model.selectedMode == .aiThemed && model.selectedThemeId == theme.remoteId
                        ) {
                            model.selectEnglishTheme(theme.remoteId)
                        }
                    }
                }
                .padding(.vertical, 10)
            }
            .contentMargins(.horizontal, Self.horizontalScrollGutter, for: .scrollContent)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private var startButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                Task {
                    do {
                        let session = try await model.beginSession()
                        onStart(session)
                        dismiss()
                    } catch {}
                }
            } label: {
                Text("この内容で始める")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canStartSession)
            .padding(.horizontal, Self.modalEdgePadding)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }
}

// MARK: - Subviews

private struct PersonaChoiceCard: View {
    let persona: CachedPersona
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 72, height: 72)
                        .overlay {
                            Text(persona.displayName.prefix(1).uppercased())
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    // 参考 UI のメニュー相当は未使用のため省略
                }
                HStack(spacing: 4) {
                    Text(ConversationLocalePresentation.flagEmoji(for: persona.locale))
                    Text(ConversationLocalePresentation.regionLabel(for: persona.locale))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(persona.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(width: 108)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            }
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

private struct ThemeStyleCard: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.systemGray6))
                    .frame(width: 88, height: 88)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 32))
                            .foregroundStyle(Color.accentColor.opacity(0.85))
                    }
                Text(title)
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 96)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            }
            .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }
}
