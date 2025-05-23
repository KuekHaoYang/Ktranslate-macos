import Foundation

struct TranslationResponse: Codable {
    let translatedText: String
    let errorMessage: String?
}
