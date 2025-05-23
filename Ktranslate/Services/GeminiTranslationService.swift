import Foundation

struct GeminiTranslationService: TranslationService {

    // MARK: - Codable Structs for Gemini API

    struct GeminiRequest: Codable {
        let contents: [Content]
    }

    struct Content: Codable {
        let parts: [Part]
    }

    struct Part: Codable {
        let text: String
    }

    struct GeminiResponse: Codable {
        let candidates: [Candidate]?
        let error: GeminiError? // For structured errors from the API
    }

    struct Candidate: Codable {
        let content: Content
    }
    
    struct GeminiError: Codable {
        let code: Int?
        let message: String
        let status: String?
    }
    
    // MARK: - TranslationService Implementation

    func translate(text: String, sourceLang: String?, targetLang: String, apiKey: String, apiHost: String, model: String) async throws -> String {
        // Construct the URL. Note: Gemini's API key is often passed as a query parameter.
        // Example Host: generativelanguage.googleapis.com
        // Example Path: /v1beta/models/gemini-pro:generateContent
        guard var urlComponents = URLComponents(string: "\(apiHost)/v1beta/models/\(model):generateContent") else {
            throw TranslationError.apiError(message: "Invalid API host URL for Gemini.")
        }
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        guard let url = urlComponents.url else {
            throw TranslationError.apiError(message: "Could not construct Gemini API URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = "Translate the following text from \(sourceLang ?? "auto-detected") to \(targetLang): \(text)"
        let requestBody = GeminiRequest(contents: [Content(parts: [Part(text: prompt)])])

        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
        } catch {
            throw TranslationError.encodingError(error)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranslationError.networkError(NSError(domain: "HTTPError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"]))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to decode a structured error message from Gemini if possible
                if let geminiError = try? JSONDecoder().decode(GeminiResponse.self, from: data).error {
                     throw TranslationError.apiError(message: "Gemini API Error: \(geminiError.message) (Status code: \(httpResponse.statusCode))")
                } else if let geminiError = try? JSONDecoder().decode(GeminiError.self, from: data) {
                     throw TranslationError.apiError(message: "Gemini API Error: \(geminiError.message) (Status code: \(httpResponse.statusCode))")
                }
                throw TranslationError.apiError(message: "Gemini API request failed with status code: \(httpResponse.statusCode)")
            }

            do {
                let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
                if let translatedText = geminiResponse.candidates?.first?.content.parts.first?.text {
                    return translatedText
                } else if let apiError = geminiResponse.error {
                    throw TranslationError.apiError(message: "Gemini API Error: \(apiError.message)")
                }
                else {
                    throw TranslationError.decodingError(NSError(domain: "DecodingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not find translated text in Gemini response."]))
                }
            } catch {
                // If decoding the GeminiResponse fails, try to see if it's a direct GeminiError object
                if let geminiError = try? JSONDecoder().decode(GeminiError.self, from: data) {
                    throw TranslationError.apiError(message: "Gemini API Error: \(geminiError.message)")
                }
                throw TranslationError.decodingError(error)
            }
        } catch let error as TranslationError {
            throw error
        } catch {
            throw TranslationError.networkError(error)
        }
    }
}
