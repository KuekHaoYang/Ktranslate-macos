// Sources/KTranslate/Services/APIService.swift
import Foundation
import Combine // For Combine-based networking if preferred, or use async/await

// Enum to represent which translation service to use
enum TranslationServiceType: String, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case gemini = "Gemini"
    var id: String { self.rawValue }
}

// Errors that APIService can throw
enum APIServiceError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case apiError(String) // For errors returned by the API itself
    case apiKeyNotSet
    case invalidAPIKeyOrHost
    case modelNotSelected
    case unsupportedService

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The API endpoint URL is invalid."
        case .networkError(let err): return "Network request failed: \(err.localizedDescription)"
        case .decodingError(let err): return "Failed to decode the server response: \(err.localizedDescription)"
        case .apiError(let message): return "API Error: \(message)"
        case .apiKeyNotSet: return "API Key is not set for the selected service."
        case .invalidAPIKeyOrHost: return "Invalid API Key or Host. Please check your settings."
        case .modelNotSelected: return "Please select a model in settings."
        case .unsupportedService: return "The selected translation service is not supported."
        }
    }
}

class APIService {

    static let shared = APIService()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - OpenAI Model Fetching
    func fetchOpenAIModels(apiKey: String, apiHost: String) async throws -> [OpenAIModel] {
        guard !apiKey.isEmpty else { throw APIServiceError.apiKeyNotSet }

        let host = apiHost.isEmpty ? "https://api.openai.com" : apiHost
        let urlString = "\(host)/v1/models"

        guard let url = URL(string: urlString) else {
            throw APIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if let errorData = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                    throw APIServiceError.apiError(errorData.error.message)
                }
                throw APIServiceError.invalidAPIKeyOrHost
            }
            let decodedResponse = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
            return decodedResponse.data.filter { model in
                // Filter out models not typically used for text generation/translation
                let id = model.id.lowercased()
                let unwantedKeywords = ["vision", "image", "embed", "audio", "whisper", "tts", "davinci-002", "babbage-002", "ada", "curie"]
                let requiredKeywords = ["gpt", "text-"] // Should include gpt models or general text models

                if unwantedKeywords.contains(where: { id.contains($0) }) { return false }
                if id.contains("gpt") { return true } // Keep all gpt models not explicitly excluded
                // Add more specific filtering if needed, e.g. by checking capabilities if available
                return false // Default to false if not matching desired criteria
            }
        } catch let error as APIServiceError {
            throw error
        } catch let error as DecodingError {
            throw APIServiceError.decodingError(error)
        } catch {
            throw APIServiceError.networkError(error)
        }
    }

    struct OpenAIErrorResponse: Decodable {
        struct ErrorDetail: Decodable {
            let message: String
            let type: String?
        }
        let error: ErrorDetail
    }

    // MARK: - Gemini Model Fetching
    func fetchGeminiModels(apiKey: String) async throws -> [GeminiModel] {
        guard !apiKey.isEmpty else { throw APIServiceError.apiKeyNotSet }

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw APIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                 if let errorData = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data) {
                    throw APIServiceError.apiError(errorData.error.message)
                }
                throw APIServiceError.invalidAPIKeyOrHost
            }
            let decodedResponse = try JSONDecoder().decode(GeminiModelsResponse.self, from: data)
            return decodedResponse.models.filter { model in
                // Filter for models that support 'generateContent' (text generation)
                // These are typically the "gemini-pro", "gemini-1.0-pro", "gemini-1.5-pro", "gemini-1.5-flash" models.
                // The 'name' property is like "models/gemini-1.5-pro-latest".
                let modelId = model.id.lowercased() // Using the computed 'id' property
                return (modelId.contains("gemini-1.0-pro") || modelId.contains("gemini-1.5-pro") || modelId.contains("gemini-1.5-flash") || modelId.contains("gemini-pro")) && !modelId.contains("vision")
            }
        } catch let error as APIServiceError {
            throw error
        } catch let error as DecodingError {
            throw APIServiceError.decodingError(error)
        } catch {
            throw APIServiceError.networkError(error)
        }
    }

    struct GeminiErrorResponse: Decodable {
        struct ErrorDetail: Decodable {
            let code: Int
            let message: String
            let status: String?
        }
        let error: ErrorDetail
    }

    // MARK: - Translation
    func translate(
        text: String,
        from sourceLanguage: Language,
        to targetLanguage: Language,
        service: TranslationServiceType,
        apiKey: String,
        model: String, // This is the model ID like "gpt-4o" or "gemini-1.5-pro-latest"
        openAIHost: String = "https://api.openai.com"
    ) async throws -> String {
        guard !apiKey.isEmpty else { throw APIServiceError.apiKeyNotSet }
        guard !model.isEmpty else { throw APIServiceError.modelNotSelected }

        let effectiveSourceLanguageName = sourceLanguage.code == "auto" ? "the detected language" : sourceLanguage.name
        let targetLanguageName = targetLanguage.name

        // Constructing the system prompt carefully
        var systemPrompt = "You are a professional, expert translator. "
        systemPrompt += "Your sole purpose is to translate the user's text from \(effectiveSourceLanguageName) to \(targetLanguageName) "
        systemPrompt += "with the highest possible accuracy and fluency.\n"
        if sourceLanguage.code == "auto" {
            systemPrompt += "If the source language is specified as \"the detected language\", you must first attempt to detect the language of the provided text.\n"
        }
        systemPrompt += "\nFollow these rules strictly:\n"
        systemPrompt += "1.  Your output must ONLY be the translated text. Do not include any preambles, apologies, explanations, or conversational text like \"Here is the translation:\".\n"
        systemPrompt += "2.  Preserve the original formatting, including line breaks, paragraphs, and spacing.\n"
        systemPrompt += "3.  Identify and preserve proper nouns, brand names, technical terms, and code snippets (e.g., 'SwiftUI', 'API Key', 'KTranslate', '`gemini-1.5-pro`'). Do not translate them unless the context absolutely demands it for fluency.\n"
        systemPrompt += "4.  Translate idiomatically, capturing the nuance and intent of the original text, not just a literal word-for-word translation."

        switch service {
        case .openAI:
            return try await translateWithOpenAI(text: text, systemPrompt: systemPrompt, apiKey: apiKey, model: model, host: openAIHost)
        case .gemini:
            // For Gemini, the model parameter might need to be "models/gemini-1.5-pro-latest"
            // The 'model' variable here is the ID like "gemini-1.5-pro-latest"
            let geminiModelName = model.starts(with: "models/") ? model : "models/\(model)"
            return try await translateWithGemini(text: text, systemPrompt: systemPrompt, apiKey: apiKey, model: geminiModelName)
        }
    }

    private func translateWithOpenAI(text: String, systemPrompt: String, apiKey: String, model: String, host: String) async throws -> String {
        let effectiveHost = host.isEmpty ? "https://api.openai.com" : host
        let urlString = "\(effectiveHost)/v1/chat/completions"
        guard let url = URL(string: urlString) else {
            throw APIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = OpenAICompletionRequestBody(
            model: model, // Model ID like "gpt-4o"
            messages: [
                OpenAICompletionRequestBody.Message(role: "system", content: systemPrompt),
                OpenAICompletionRequestBody.Message(role: "user", content: text)
            ]
        )

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIServiceError.networkError(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server."]))
            }

            if httpResponse.statusCode != 200 {
                 if let errorData = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                    throw APIServiceError.apiError("OpenAI API Error (\(httpResponse.statusCode)): \(errorData.error.message)")
                }
                throw APIServiceError.apiError("OpenAI API request failed with status code: \(httpResponse.statusCode)")
            }

            let decodedResponse = try JSONDecoder().decode(OpenAICompletionResponse.self, from: data)
            return decodedResponse.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        } catch let error as APIServiceError {
            throw error
        } catch let error as DecodingError {
            throw APIServiceError.decodingError(error)
        } catch {
            throw APIServiceError.networkError(error)
        }
    }

    private func translateWithGemini(text: String, systemPrompt: String, apiKey: String, model: String /* e.g. models/gemini-1.5-pro-latest */) async throws -> String {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw APIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = GeminiCompletionRequestBody(
            systemInstruction: GeminiCompletionRequestBody.ContentPart(parts: [
                GeminiCompletionRequestBody.Part(text: systemPrompt)
            ]),
            contents: [
                GeminiCompletionRequestBody.ContentPart(parts: [
                    GeminiCompletionRequestBody.Part(text: text)
                ], role: "user")
            ],
            generationConfig: GeminiCompletionRequestBody.GenerationConfig(
                temperature: 0.7, // Example, adjust as needed
                topP: 0.9,      // Example, adjust as needed
                candidateCount: 1
            )
        )

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIServiceError.networkError(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server."]))
            }

            if httpResponse.statusCode != 200 {
                if let errorData = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data) {
                   throw APIServiceError.apiError("Gemini API Error (\(httpResponse.statusCode)): \(errorData.error.message)")
               }
               throw APIServiceError.apiError("Gemini API request failed with status code: \(httpResponse.statusCode)")
            }

            let decodedResponse = try JSONDecoder().decode(GeminiCompletionResponse.self, from: data)
            guard let firstCandidate = decodedResponse.candidates.first,
                  let firstPart = firstCandidate.content.parts.first else {
                if let finishReason = decodedResponse.candidates.first?.finishReason, finishReason != "STOP" {
                     throw APIServiceError.apiError("Translation failed: \(finishReason). Content may be blocked by API safety filters.")
                }
                return "" // Or throw a specific error like "noTranslationFound"
            }
            return firstPart.text.trimmingCharacters(in: .whitespacesAndNewlines)

        } catch let error as APIServiceError {
            throw error
        } catch let error as DecodingError {
            throw APIServiceError.decodingError(error)
        } catch {
            throw APIServiceError.networkError(error)
        }
    }
}

// MARK: - OpenAI Request/Response Structures for Translation
struct OpenAICompletionRequestBody: Codable {
    struct Message: Codable {
        let role: String
        let content: String
    }
    let model: String // e.g. "gpt-4o"
    let messages: [Message]
    // Add other parameters like temperature, max_tokens if needed
}

struct OpenAICompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String
            let content: String
        }
        let message: Message
        let finishReason: String? // E.g., "stop", "length"
    }
    let id: String?
    let choices: [Choice]
    // let usage: UsageData?
}

// MARK: - Gemini Request/Response Structures for Translation
struct GeminiCompletionRequestBody: Codable {
    struct Part: Codable {
        let text: String
    }
    struct ContentPart: Codable { // Represents a single turn in the conversation
        let parts: [Part]
        let role: String? // "user" or "model". System instructions are separate.

        init(parts: [Part], role: String? = nil) {
            self.parts = parts
            self.role = role
        }
    }
    struct GenerationConfig: Codable {
        let temperature: Double?
        let topP: Double?
        // let topK: Int?
        let candidateCount: Int?
        // let maxOutputTokens: Int?
        // let stopSequences: [String]?
    }

    let systemInstruction: ContentPart? // For system prompt
    let contents: [ContentPart] // User input and model responses for multi-turn
    let generationConfig: GenerationConfig?

    // CodingKeys to match Gemini's expected "system_instruction"
    enum CodingKeys: String, CodingKey {
        case systemInstruction = "system_instruction"
        case contents
        case generationConfig = "generation_config"
    }
}


struct GeminiCompletionResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String
            }
            let parts: [Part]
            let role: String? // "model"
        }
        let content: Content
        let finishReason: String? // e.g. "STOP", "MAX_TOKENS", "SAFETY", "RECITATION"
        // let safetyRatings: [SafetyRating]?
    }
    let candidates: [Candidate]
    // let promptFeedback: PromptFeedback?
}
