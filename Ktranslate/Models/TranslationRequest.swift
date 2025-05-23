import Foundation

struct TranslationRequest: Codable {
    let textToTranslate: String
    let sourceLanguage: String?
    let targetLanguage: String
}
