import Foundation
import SwiftData

struct SeedVocabularyAddFormFromLemmaUseCase {
    let lemmaLookupRepository: any LemmaLookupRepository

    func execute(stableLemmaId: UUID) throws -> LemmaVocabularyDraftSeed {
        guard let lemma = try lemmaLookupRepository.fetchLemma(stableLemmaId: stableLemmaId) else {
            throw SeedVocabularyFromLemmaError.lemmaNotFound
        }
        let lines = LemmaToVocabularyUsageLinesBuilder.lines(from: lemma)
        return LemmaVocabularyDraftSeed(
            suggestedHeadword: lemma.lemmaText,
            usageLines: lines
        )
    }
}

// MARK: - Mapping

private enum LemmaToVocabularyUsageLinesBuilder {

    static func lines(from lemma: CachedLemma) -> [VocabularyAddFormUsageLine] {
        let usages = lemma.usages.sorted { $0.position < $1.position }
        return usages.compactMap { usageLine(from: $0) }
    }

    private static func usageLine(from usage: CachedLemmaUsage) -> VocabularyAddFormUsageLine? {
        guard let kind = VocabularyKind(rawValue: usage.kind) ?? VocabularyKind(kindString: usage.kind) else {
            return nil
        }

        let ipaFromUsage = usage.ipa?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let ipaFromSurfaces = ipa(for: kind, surfaces: usage.surfaces)
        let ipa = ipaFromUsage.isEmpty ? ipaFromSurfaces : ipaFromUsage

        let aux = usage.definitionAux?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let target = usage.definitionTarget?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let studyFromUsage = usage.studyHeadword?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let study = studyFromUsage.isEmpty
            ? (LemmaStudyEmbeddingText.embeddingText(for: kind, usage: usage) ?? "")
            : studyFromUsage

        return VocabularyAddFormUsageLine(
            kind: kind,
            ipa: ipa,
            definitionAux: aux,
            definitionTarget: target,
            studyHeadword: study,
            examples: [VocabularyAddFormExampleLine(sentence: "")]
        )
    }

    private static func ipa(for kind: VocabularyKind, surfaces: [CachedLemmaSurface]) -> String {
        func ipa(_ form: LemmaSurfaceFormKind) -> String {
            surfaces.first { $0.formKindRaw == form.rawValue }?.ipa?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        switch kind {
        case .verb, .phrasalVerb:
            return ipa(.verbBase)
        case .adjective:
            return ipa(.adjPositive)
        case .noun:
            return ipa(.nounSingular)
        case .adverb:
            let adv = ipa(.advPositive)
            return adv.isEmpty ? ipa(.lemmaBase) : adv
        default:
            return ipa(.lemmaBase)
        }
    }
}
