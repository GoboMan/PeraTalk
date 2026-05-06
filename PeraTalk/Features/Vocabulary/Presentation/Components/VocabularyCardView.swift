import SwiftUI

struct VocabularyCardView: View {
    let headword: String
    let ipa: String?
    let definition: String?
    var kind: VocabularyKind?
    /// 辞典レマへのリンク表示（一覧用の短い行）。
    var lemmaCaption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(headword)
                    .font(.headline)
                    .fontWeight(.bold)

                if let kind {
                    Text(kind.englishLabel)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(kind.badgeColor.opacity(0.15))
                        .foregroundStyle(kind.badgeColor)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            if let ipa, !ipa.isEmpty {
                Text(ipa)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let definition, !definition.isEmpty {
                Text(definition)
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
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}
