import SwiftUI
import SwiftData
import Observation
import Supabase

struct ConversationSessionScreen: View {
    let sessionRemoteId: UUID

    /// フローティング入力バーとホームインジケータ周りの余白ぶん、最終行が隠れないように確保する。
    private static let floatingComposerScrollPadding: CGFloat = 96

    @Environment(\.modelContext) private var modelContext
    @Environment(\.supabaseClient) private var supabaseClient
    @Environment(\.authService) private var authService

    @State private var model: ConversationSessionScreenModel?

    var body: some View {
        Group {
            if let model {
                sessionContent(with: model)
            } else {
                ProgressView("読み込み中…").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: sessionRemoteId) {
            await authService.warmUpSessionMirror()
            let useEdge = supabaseClient != nil && authService.isAuthenticated
            let created = ConversationPresentationFactory.makeSessionScreenModel(
                modelContext: modelContext,
                supabase: supabaseClient,
                useEdgeAuthenticatedStream: useEdge,
                sessionRemoteId: sessionRemoteId
            )
            model = created
            try? await created.hydrate()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("セッション終了") {
                    Task { await model?.endSessionTap() }
                }
                .help("セッション終了処理（総括フィードバックスタブのみ）")
                .disabled(model == nil)
            }
        }
    }

    @ViewBuilder
    private func sessionContent(with observationModel: ConversationSessionScreenModel) -> some View {
        @Bindable var vm = observationModel

        ZStack(alignment: .bottom) {
            VStack(spacing: 12) {
                let phaseLabel = phaseText(vm.assistantStreamPhase)
                if !phaseLabel.isEmpty {
                    Text(phaseLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 16)
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(sortedUtterances(vm.transcript), id: \.remoteId) { row in
                                chatBubbleRow(for: row)
                            }

                            streamingAssistantRow(
                                phase: vm.assistantStreamPhase,
                                draft: vm.assistantAccumulatedDraft
                            )

                            Color.clear
                                .frame(height: 1)
                                .id("chatBottom")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .padding(.bottom, Self.floatingComposerScrollPadding)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: vm.transcript.count) { _, _ in
                        scrollChatToBottom(proxy: proxy)
                    }
                    .onChange(of: vm.assistantAccumulatedDraft) { _, _ in
                        scrollChatToBottom(proxy: proxy)
                    }
                    .onChange(of: vm.assistantStreamPhase) { _, _ in
                        scrollChatToBottom(proxy: proxy)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            floatingMessageComposer(
                streamPhase: vm.assistantStreamPhase,
                text: $vm.inputText,
                send: { Task { await vm.sendUserTurn() } },
                stop: { vm.cancelAssistantGeneration() }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private func floatingMessageComposer(
        streamPhase: AssistantReplyStreamPhase,
        text: Binding<String>,
        send: @escaping () -> Void,
        stop: @escaping () -> Void
    ) -> some View {
        let awaitingAssistant = streamPhase == .connecting || streamPhase == .streaming
        let canSend = !text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        HStack(alignment: .bottom, spacing: 10) {
            TextField("英語メッセージ", text: text, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)

            if awaitingAssistant {
                Button(action: stop) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
                .accessibilityLabel("停止")
            } else {
                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(!canSend)
                .accessibilityLabel("送信")
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .clipShape(Capsule(style: .continuous))
        .shadow(color: Color.black.opacity(0.14), radius: 16, x: 0, y: 6)
        .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    private func sortedUtterances(_ rows: [CachedUtterance]) -> [CachedUtterance] {
        rows.sorted { $0.sequenceIndex < $1.sequenceIndex }
    }

    @ViewBuilder
    private func chatBubbleRow(for row: CachedUtterance) -> some View {
        let isUser = row.role != "assistant"
        HStack(alignment: .top, spacing: 8) {
            if isUser { Spacer(minLength: 56) }

            Text(isUser ? row.text : ConversationAssistantReplyDisplaySanitizer.stripAllLeadingRoleLabels(from: row.text))
                .multilineTextAlignment(isUser ? .trailing : .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .foregroundStyle(.primary)
                .background(bubbleFill(isUser: isUser))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if !isUser { Spacer(minLength: 56) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    @ViewBuilder
    private func streamingAssistantRow(
        phase: AssistantReplyStreamPhase,
        draft: String
    ) -> some View {
        let showStreamingOrHeldDraft = !draft.isEmpty &&
            (phase == .connecting
                || phase == .streaming
                || phase == .failedCancelled
                || phase == .failedError)

        let showThinking = (phase == .connecting || phase == .streaming) && draft.isEmpty

        if showStreamingOrHeldDraft {
            HStack(alignment: .top, spacing: 8) {
                Text(draft)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .foregroundStyle(.primary)
                    .background(Color.gray.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Spacer(minLength: 56)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if showThinking {
            HStack(alignment: .center, spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Spacer(minLength: 56)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func bubbleFill(isUser: Bool) -> some ShapeStyle {
        if isUser {
            Color.blue.opacity(0.22)
        } else {
            Color.gray.opacity(0.14)
        }
    }

    private func scrollChatToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("chatBottom", anchor: .bottom)
        }
    }

    private func phaseText(_ phase: AssistantReplyStreamPhase) -> String {
        switch phase {
        case .idle:
            ""
        case .connecting:
            "接続中…"
        case .streaming:
            "応答ストリーム受信中…"
        case .completedNormally:
            "完了"
        case .completedTruncatedStream:
            "部分応答を保存しました（計画ポリシー A）"
        case .failedCancelled:
            "キャンセル"
        case .failedError:
            "エラーまたは空応答"
        }
    }
}
