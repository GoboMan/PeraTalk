import SwiftUI
import SwiftData
import Observation
import Supabase

struct ConversationSessionScreen: View {
    let sessionRemoteId: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.supabaseClient) private var supabaseClient

    @State private var model: ConversationSessionScreenModel?

    var body: some View {
        Group {
            if let model {
                sessionContent(with: model)
            } else {
                ProgressView("準備中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: sessionRemoteId) {
            let created = ConversationPresentationFactory.makeSessionScreenModel(
                modelContext: modelContext,
                supabase: supabaseClient,
                sessionRemoteId: sessionRemoteId
            )
            model = created
            await created.bootstrap()
        }
        .onDisappear {
            Task { await model?.discardOngoingRecording() }
        }
    }

    @ViewBuilder
    private func sessionContent(with model: ConversationSessionScreenModel) -> some View {
        @Bindable var vm = model
        VStack(spacing: 0) {
            transcriptList(model: vm)
            phaseStatusBar(model: vm)
            chatComposer(model: vm)
        }
    }

    @ViewBuilder
    private func transcriptList(model: ConversationSessionScreenModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(model.transcript) { turn in
                        chatBubble(role: turn.role, text: turn.text)
                            .id(turn.id)
                    }
                    Color.clear.frame(height: 1).id("voiceChatBottom")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: model.transcript.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("voiceChatBottom", anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private func chatBubble(role: String, text: String) -> some View {
        let isUser = role.lowercased() == "user"
        HStack(alignment: .top, spacing: 8) {
            if isUser { Spacer(minLength: 56) }
            Text(text)
                .multilineTextAlignment(isUser ? .trailing : .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .foregroundStyle(.primary)
                .background(isUser ? Color.blue.opacity(0.22) : Color.gray.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            if !isUser { Spacer(minLength: 56) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    @ViewBuilder
    private func phaseStatusBar(model: ConversationSessionScreenModel) -> some View {
        let label = phaseText(model.phase)
        if !label.isEmpty {
            HStack(spacing: 8) {
                if needsSpinner(model.phase) {
                    ProgressView().controlSize(.small)
                }
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func chatComposer(model: ConversationSessionScreenModel) -> some View {
        @Bindable var vm = model
        VStack(spacing: 4) {
            if case let .failed(message) = vm.phase {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField(textFieldPlaceholder(vm.phase), text: $vm.inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .disabled(composerDisabled(vm.phase))

                trailingActionButton(model: vm)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .overlay(alignment: .top) {
                Divider()
            }
        }
    }

    @ViewBuilder
    private func trailingActionButton(model: ConversationSessionScreenModel) -> some View {
        let hasText = !model.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if model.phase == .recording {
            Button {
                Task { await model.toggleRecording() }
            } label: {
                actionIcon(systemName: "stop.fill", tint: .red)
            }
            .accessibilityLabel("録音停止")
        } else if hasText && !composerDisabled(model.phase) {
            Button {
                Task { await model.sendTextMessage() }
            } label: {
                actionIcon(systemName: "arrow.up", tint: .accentColor)
            }
            .accessibilityLabel("送信")
        } else {
            Button {
                Task { await model.toggleRecording() }
            } label: {
                actionIcon(systemName: "mic.fill", tint: micTint(model.phase))
            }
            .disabled(micDisabled(model.phase))
            .accessibilityLabel("音声入力")
        }
    }

    private func actionIcon(systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(tint)
            .clipShape(Circle())
    }

    private func micTint(_ phase: VoiceTurnPhase) -> Color {
        switch phase {
        case .loadingModel, .transcribing, .awaitingAssistant, .speakingAssistant: .gray
        default: .accentColor
        }
    }

    private func micDisabled(_ phase: VoiceTurnPhase) -> Bool {
        switch phase {
        case .loadingModel, .transcribing, .awaitingAssistant, .speakingAssistant: true
        default: false
        }
    }

    private func composerDisabled(_ phase: VoiceTurnPhase) -> Bool {
        switch phase {
        case .recording, .transcribing, .awaitingAssistant, .speakingAssistant: true
        default: false
        }
    }

    private func textFieldPlaceholder(_ phase: VoiceTurnPhase) -> String {
        switch phase {
        case .recording: "録音中…"
        case .transcribing: "文字起こし中…"
        case .awaitingAssistant: "AI が応答中…"
        case .speakingAssistant: "AI が話しています…"
        default: "メッセージまたは右のマイクで音声入力"
        }
    }

    private func phaseText(_ phase: VoiceTurnPhase) -> String {
        switch phase {
        case .idle: ""
        case .loadingModel: "音声認識モデルを準備中…（初回はダウンロードに数十秒〜数分かかります）"
        case .recording: "録音中… マイクを再度タップで停止"
        case .transcribing: "文字起こし中…"
        case .awaitingAssistant: "AI が応答を準備中…"
        case .speakingAssistant: "AI が話しています…"
        case .failed: ""
        }
    }

    private func needsSpinner(_ phase: VoiceTurnPhase) -> Bool {
        switch phase {
        case .loadingModel, .transcribing, .awaitingAssistant: true
        default: false
        }
    }
}
