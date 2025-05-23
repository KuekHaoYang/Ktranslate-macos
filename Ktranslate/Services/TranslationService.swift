import Foundation

enum TranslationError: Error {
    case networkError(Error)
    case apiError(message: String)
    case decodingError(Error)
    case encodingError(Error) // Added this line
    case unknownError
}

protocol TranslationService {
    func translate(text: String, sourceLang: String?, targetLang: String, apiKey: String, apiHost: String, model: String) async throws -> String
}
