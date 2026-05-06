import Foundation

final class CMUDictPronunciationRepository: PronunciationRepository {
    private let dictionary: [String: String]

    init() {
        guard let url = Bundle.main.url(forResource: "cmudict_ipa", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            dictionary = [:]
            return
        }
        dictionary = dict
    }

    func lookupIPA(for word: String) -> String? {
        dictionary[word.lowercased()]
    }
}
