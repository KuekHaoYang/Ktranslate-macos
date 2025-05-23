import Foundation

struct OpenAITranslationService: TranslationService {

    // MARK: - Codable Structs for OpenAI API

    struct OpenAIRequest: Codable {
        let model: String
        let messages: [Message]
    }

    struct Message: Codable {
        let role: String
        let content: String
    }

    struct OpenAIResponse: Codable {
        let choices: [Choice]?
        let error: OpenAIError?
    }

    struct Choice: Codable {
        let message: MessageContent
    }

    struct MessageContent: Codable {
        let content: String
    }
    
    struct OpenAIError: Codable {
        let message: String
        let type: String?
        let param: String?
        let code: String?
    }

    // MARK: - TranslationService Implementation

    func translate(text: String, sourceLang: String?, targetLang: String, apiKey: String, apiHost: String, model: String) async throws -> String {
        guard let url = URL(string: "\(apiHost)/chat/completions") else {
            throw TranslationError.apiError(message: "Invalid API host URL for OpenAI.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemMessageContent = "You are a translation assistant."
        let userMessageContent = "Translate the following text from \(sourceLang ?? "auto-detected") to \(targetLang): \(text)"
        
        let messages = [
            Message(role: "system", content: systemMessageContent),
            Message(role: "user", content: userMessageContent)
        ]
        
        let requestBody = OpenAIRequest(model: model, messages: messages)

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
                // Try to decode an error message from OpenAI if possible
                if let openAIError = try? JSONDecoder().decode(OpenAIResponse.self, from: data).error {
                    throw TranslationError.apiError(message: "OpenAI API Error: \(openAIError.message) (Status code: \(httpResponse.statusCode))")
                }
                throw TranslationError.apiError(message: "OpenAI API request failed with status code: \(httpResponse.statusCode)")
            }

            do {
                let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                if let translatedText = openAIResponse.choices?.first?.message.content {
                    return translatedText
                } else if let apiError = openAIResponse.error {
                     throw TranslationError.apiError(message: "OpenAI API Error: \(apiError.message)")
                }
                else {
                    throw TranslationError.decodingError(NSError(domain: "DecodingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not find translated text in OpenAI response."]))
                }
            } catch {
                throw TranslationError.decodingError(error)
            }
        } catch let error as TranslationError {
            throw error
        } catch {
            throw TranslationError.networkError(error)
        }
    }
}
