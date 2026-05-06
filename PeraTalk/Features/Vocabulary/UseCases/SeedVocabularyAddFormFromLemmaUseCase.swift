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

enum SeedVocabularyFromLemmaError: LocalizedError {
    case lemmaNotFound

    var errorDescription: String? {
        switch self {
        case .lemmaNotFound: "辞典に該当するレマが見つかりませんでした。"
        }
    }
}

// MARK: - Mapping

private enum LemmaToVocabularyUsageLinesBuilder {

    static func lines(from lemma: CachedLemma) -> [VocabularyAddFormUsageLine] {
        let primary = VocabularyKind(rawValue: lemma.posRaw) ?? .noun
        let surfaceRows = lemma.surfaces
        func hasForm(_ k: LemmaSurfaceFormKind) -> Bool {
            surfaceRows.contains { $0.formKindRaw == k.rawValue }
        }
        let hasVerbSurface = LemmaSurfaceFormKind.verbInflectionDisplayOrder.contains { hasForm($0) }
        let hasAdjSurface = LemmaSurfaceFormKind.adjectiveInflectionDisplayOrder.contains { hasForm($0) }

        func ipa(_ k: LemmaSurfaceFormKind) -> String {
            surfaceRows.first { $0.formKindRaw == k.rawValue }?.ipa ?? ""
        }

        func ipaNounSingular() -> String {
            ipa(.nounSingular)
        }

        func ipaLemmaBase() -> String {
            ipa(.lemmaBase)
        }

        func usageLine(kind: VocabularyKind, ipaString: String = "", lemma: CachedLemma) -> VocabularyAddFormUsageLine {
            let defs = lemma.packUsageDefinitions(for: kind)
            return VocabularyAddFormUsageLine(
                kind: kind,
                ipa: ipaString,
                definitionAux: defs.aux,
                definitionTarget: defs.target,
                examples: [VocabularyAddFormExampleLine(sentence: "")]
            )
        }

        switch primary {
        case .verb:
            var out: [VocabularyAddFormUsageLine] = []
            if hasVerbSurface {
                out.append(usageLine(kind: .verb, ipaString: ipa(.verbBase), lemma: lemma))
            }
            if hasAdjSurface {
                out.append(usageLine(kind: .adjective, ipaString: ipa(.adjPositive), lemma: lemma))
            }
            if !out.isEmpty { return out }
            return [usageLine(kind: .verb, lemma: lemma)]

        case .phrasalVerb:
            if hasVerbSurface {
                return [usageLine(kind: .phrasalVerb, ipaString: ipa(.verbBase), lemma: lemma)]
            }
            return [usageLine(kind: .phrasalVerb, lemma: lemma)]

        case .adjective:
            if hasAdjSurface {
                return [usageLine(kind: .adjective, ipaString: ipa(.adjPositive), lemma: lemma)]
            }
            return [usageLine(kind: .adjective, lemma: lemma)]

        case .noun:
            if hasForm(.nounSingular) || hasForm(.nounPlural) {
                return [usageLine(kind: .noun, ipaString: ipaNounSingular(), lemma: lemma)]
            }
            return [usageLine(kind: .noun, lemma: lemma)]

        case .adverb:
            let advOrder: [LemmaSurfaceFormKind] = [.advPositive, .advComparative, .advSuperlative]
            if advOrder.contains(where: hasForm) {
                return [usageLine(kind: .adverb, ipaString: ipa(.advPositive), lemma: lemma)]
            }
            if hasForm(.lemmaBase) {
                return [usageLine(kind: .adverb, ipaString: ipaLemmaBase(), lemma: lemma)]
            }
            return [usageLine(kind: .adverb, lemma: lemma)]

        default:
            if hasForm(.lemmaBase) {
                return [usageLine(kind: primary, ipaString: ipaLemmaBase(), lemma: lemma)]
            }
            return [usageLine(kind: primary, lemma: lemma)]
        }
    }
}
