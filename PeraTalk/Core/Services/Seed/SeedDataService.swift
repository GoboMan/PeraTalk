import Foundation
import SwiftData

struct SeedDataService {
    static func loadIfNeeded(context: ModelContext) {
        insertProfileIfNeeded(context: context)

        try? ImportEmbeddedDictionarySampleUseCase().execute(context: context)

        let descriptor = FetchDescriptor<CachedVocabulary>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        let tags = insertTags(context: context)
        insertVocabulary(context: context, tags: tags)
        insertPersonas(context: context)

        try? context.save()
    }

    // MARK: - Tags

    private static func insertTags(context: ModelContext) -> [String: CachedTag] {
        let names = ["TOEIC", "ビジネス", "旅行", "IT", "slang"]
        var tagMap: [String: CachedTag] = [:]
        for name in names {
            let tag = CachedTag(name: name, dirty: false)
            context.insert(tag)
            tagMap[name] = tag
        }
        return tagMap
    }

    // MARK: - Vocabulary

    private static func insertVocabulary(
        context: ModelContext,
        tags: [String: CachedTag]
    ) {
        let entries: [(String, String, String?, [String], [(String, String?, String?, String?, [String])])] = [
            // (headword, source, notes, tagNames, [(kind, ipa, defTarget, defAux, [sentence])])
            ("allocate", "manual",
             "From Latin allocāre: ad- (to) + locāre (to place). The word originally meant to assign a place or position, and later evolved to mean distributing resources.",
             ["TOEIC", "ビジネス"],
             [
                ("verb", "/ˈæləkeɪt/", "to distribute resources or duties for a particular purpose", "割り当てる、配分する", [
                    "We need to allocate more budget to marketing.",
                    "The manager allocated tasks to each team member.",
                ]),
                ("adjective", "/ˈæləkeɪtɪd/", "designated or set apart for a specific purpose", "割り当てられた", [
                    "The allocated funds were insufficient for the project.",
                ]),
             ]),
            ("nuance", "manual", nil, ["TOEIC"], [
                ("noun", "/ˈnuːɑːns/", "a subtle shade of meaning", "ニュアンス、微妙な違い", [
                    "There's a subtle nuance between the two words.",
                ]),
            ]),
            ("carry on", "manual", nil, ["旅行"], [
                ("phrasal_verb", nil, "to continue despite difficulty", "続ける、やり通す", [
                    "We decided to carry on with the project.",
                    "She carried on working even after midnight.",
                ]),
            ]),
            ("perhaps", "manual", nil, [], [
                ("adverb", "/pərˈhæps/", "maybe; used to express soft tone", "おそらく、もしかすると", [
                    "Perhaps we should reconsider our approach.",
                ]),
            ]),
            ("scrutiny", "manual", nil, ["ビジネス"], [
                ("noun", "/ˈskruːtəni/", "close, careful examination", "精査、詳しい調査", [
                    "The proposal came under intense scrutiny.",
                    "Public scrutiny of government spending has increased.",
                ]),
            ]),
            ("eloquent", "conversation_candidate", nil, ["TOEIC"], [
                ("adjective", "/ˈeləkwənt/", "fluent or persuasive in speaking", "雄弁な、説得力のある", [
                    "She gave an eloquent speech at the conference.",
                ]),
            ]),
            ("procrastinate", "manual", nil, [], [
                ("verb", "/prəˈkræstɪneɪt/", "to delay or postpone action", "先延ばしにする", [
                    "Stop procrastinating and start writing your essay.",
                ]),
            ]),
        ]

        for (headword, source, notes, tagNames, usages) in entries {
            let vocab = CachedVocabulary(
                headword: headword,
                source: source,
                dirty: false
            )
            vocab.notes = notes
            context.insert(vocab)

            switch headword {
            case "allocate":
                vocab.lemma = DictionaryScaffoldLemmaLinking.cachedLemma(
                    stableLemmaId: DictionaryScaffoldLemmaLinking.StableLemmaId.allocate,
                    in: context
                )
            case "carry on":
                vocab.lemma = DictionaryScaffoldLemmaLinking.cachedLemma(
                    stableLemmaId: DictionaryScaffoldLemmaLinking.StableLemmaId.carryOnPhrasal,
                    in: context
                )
            case "procrastinate":
                vocab.lemma = DictionaryScaffoldLemmaLinking.cachedLemma(
                    stableLemmaId: DictionaryScaffoldLemmaLinking.StableLemmaId.procrastinate,
                    in: context
                )
            case "eloquent":
                vocab.lemma = DictionaryScaffoldLemmaLinking.cachedLemma(
                    stableLemmaId: DictionaryScaffoldLemmaLinking.StableLemmaId.eloquent,
                    in: context
                )
            default:
                break
            }

            for tagName in tagNames {
                if let tag = tags[tagName] {
                    let vocabularyTagLink = CachedVocabularyTagLink(dirty: false)
                    vocabularyTagLink.vocabulary = vocab
                    vocabularyTagLink.tag = tag
                    context.insert(vocabularyTagLink)
                }
            }

            for (i, (kind, ipa, defTarget, defAux, examples)) in usages.enumerated() {
                let usage = CachedVocabularyUsage(kind: kind, position: i, dirty: false)
                usage.ipa = ipa
                usage.definitionTarget = defTarget
                usage.definitionAux = defAux
                if headword == "allocate", kind == "adjective" {
                    usage.studyHeadword = "allocated"
                } else if headword == "allocate", kind == "verb" {
                    usage.studyHeadword = "allocate"
                } else {
                    let h = headword.trimmingCharacters(in: .whitespacesAndNewlines)
                    usage.studyHeadword = h.isEmpty ? nil : h
                }
                usage.vocabulary = vocab
                context.insert(usage)

                for (j, sentence) in examples.enumerated() {
                    let example = CachedVocabularyExample(
                        sentenceTarget: sentence,
                        position: j,
                        dirty: false
                    )
                    example.usage = usage
                    context.insert(example)
                }
            }
        }
    }

    // MARK: - Personas

    private static func insertPersonas(context: ModelContext) {
        let personas: [(String, String, String, String)] = [
            ("us-male-ethan", "Ethan", "en-US", "male"),
            ("us-female-chloe", "Chloe", "en-US", "female"),
            ("gb-male-oliver", "Oliver", "en-GB", "male"),
            ("gb-female-sophie", "Sophie", "en-GB", "female"),
            ("au-male-liam", "Liam", "en-AU", "male"),
            ("au-female-isla", "Isla", "en-AU", "female"),
        ]

        for (slug, name, locale, gender) in personas {
            context.insert(CachedPersona(
                slug: slug,
                displayName: name,
                locale: locale,
                gender: gender
            ))
        }
    }

    // MARK: - Profile

    private static func insertProfileIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<CachedProfile>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        let profile = CachedProfile(auxiliaryLanguage: AuxiliaryLanguage.systemDefault.rawValue)
        context.insert(profile)
    }
}
