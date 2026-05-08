import SwiftUI

struct VocabularyCardView: View {
    let headword: String
    /// 単語一覧では `false` 固定（複数用法の代表品詞を決めない）。詳細など別画面から再利用するときのみ `true` にできる。
    var showPartOfSpeech: Bool = false
    var kind: VocabularyKind?
    var japaneseDefinition: String?
    var englishDefinition: String?
    var ipa: String?
    /// 辞典レマへのリンク表示（一覧用の短い行）。
    var lemmaCaption: String? = nil
    var density: ListRowDensity = .comfortable

    var body: some View {
        VStack(alignment: .leading, spacing: density == .compact ? 2 : 4) {
            // 見出しと（任意で）品詞バッジを同一行にまとめる。
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(headword)
                    .font(density == .compact ? .subheadline : .headline)
                    .fontWeight(.bold)
                    .lineLimit(2)
                    .layoutPriority(1)

                if showPartOfSpeech {
                    VocabularyPartOfSpeechBadge(kind: kind)
                }

                Spacer(minLength: 0)
            }

            // 発音は見出しブロック直下（形と意味のあいだを埋めるのに一般的な位置）。
            if let ipa, !ipa.isEmpty {
                Text(ipa)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let japaneseDefinition, !japaneseDefinition.isEmpty {
                Text(japaneseDefinition)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let englishDefinition, !englishDefinition.isEmpty {
                Text(englishDefinition)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let lemmaCaption, !lemmaCaption.isEmpty {
                Text(lemmaCaption)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, density == .compact ? 8 : 14)
        .padding(.horizontal, density == .compact ? 12 : 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}
