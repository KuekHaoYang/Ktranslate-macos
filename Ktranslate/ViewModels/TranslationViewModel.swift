import SwiftUI
import Combine

class TranslationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var sourceText: String = ""
    @Published var translatedText: String = ""
    @Published var sourceLanguage: String = "en" // TODO: Load from AppSettings default
    @Published var targetLanguage: String = "es" // TODO: Load from AppSettings default
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var availableModels: [String] = []

    // MARK: - App Settings (Loaded from AppStorage)
    @AppStorage("settings_apiHost") private var apiHost: String = "" // Default set in SettingsView if not set here
    @AppStorage("settings_apiKey") private var apiKey: String = ""
    @AppStorage("settings_selectedModel") private var selectedModelKey: String = "gpt-3.5-turbo"
    @AppStorage("settings_selectedService") private var selectedServiceRawValue: String = AIService.openAI.rawValue

    var selectedService: AIService {
        AIService(rawValue: selectedServiceRawValue) ?? .openAI
    }

    // MARK: - Translation Service Instances
    private let openAIService = OpenAITranslationService()
    private let geminiService = GeminiTranslationService()

    private var currentTranslationService: TranslationService {
        switch selectedService {
        case .openAI:
            // Ensure default host is set if AppStorage is empty for OpenAI
            if apiHost.isEmpty || apiHost == "https://generativelanguage.googleapis.com" { // A bit of a hack, better to have service-specific hosts
                 DispatchQueue.main.async { // Avoid modifying AppStorage during view updates
                    self.apiHost = "https://api.openai.com/v1"
                 }
            }
            return openAIService
        case .gemini:
            // Ensure default host is set if AppStorage is empty for Gemini
             if apiHost.isEmpty || apiHost == "https://api.openai.com/v1" {
                 DispatchQueue.main.async {
                    self.apiHost = "https://generativelanguage.googleapis.com"
                 }
            }
            return geminiService
        }
    }

    // MARK: - Initializer
    init() {
        updateAvailableModels(for: selectedService)
        // Observe changes to selectedServiceRawValue to update models
        // This is a common pattern for AppStorage observation.
        // However, direct observation of @AppStorage from an ObservableObject is tricky
        // and often better handled by passing the value in or using Combine's features
        // if more complex reactions are needed. For now, this init call and
        // potential re-init or manual call from view is a simpler approach.
    }

    // MARK: - Public Methods
    @MainActor
    func translate() async {
        isLoading = true
        errorMessage = nil
        translatedText = ""

        // Get current values from AppStorage properties
        let currentApiKey = apiKey
        let currentApiHost = apiHost
        let currentSelectedModel = selectedModelKey
        let currentSelectedService = selectedService // to ensure it's the most up-to-date

        if currentApiKey.isEmpty {
            errorMessage = "API Key not set in Settings."
            isLoading = false
            return
        }
        
        // Ensure the correct host is used based on the *current* service
        // This is important if the user changes service and AppStorage hasn't updated the viewmodel's host yet
        var effectiveApiHost = currentApiHost
        if currentSelectedService == .openAI && (effectiveApiHost.isEmpty || !effectiveApiHost.contains("openai")) {
            effectiveApiHost = "https://api.openai.com/v1"
        } else if currentSelectedService == .gemini && (effectiveApiHost.isEmpty || !effectiveApiHost.contains("googleapis")) {
            effectiveApiHost = "https://generativelanguage.googleapis.com"
        }


        // Update available models for the *current* service, in case it changed
        // and init() didn't pick it up or a view didn't trigger an update.
        if self.availableModels.isEmpty || (currentSelectedService == .openAI && !self.availableModels.contains("gpt-3.5-turbo")) || (currentSelectedService == .gemini && !self.availableModels.contains("gemini-pro")) {
            updateAvailableModels(for: currentSelectedService)
        }
        // Ensure selectedModelKey is valid for the current service
        if !self.availableModels.contains(currentSelectedModel) {
            self.selectedModelKey = self.availableModels.first ?? ""
        }
        let modelToUse = self.selectedModelKey


        do {
            let serviceToUse = currentTranslationService // This will pick based on selectedService
            translatedText = try await serviceToUse.translate(
                text: sourceText,
                sourceLang: sourceLanguage.isEmpty ? nil : sourceLanguage, // Pass nil if empty
                targetLang: targetLanguage,
                apiKey: currentApiKey,
                apiHost: effectiveApiHost, // Use the dynamically checked host
                model: modelToUse
            )
        } catch let error as TranslationError {
            switch error {
            case .networkError(let underlyingError):
                errorMessage = "Network error: \(underlyingError.localizedDescription)"
            case .apiError(let message):
                errorMessage = "API error: \(message)"
            case .decodingError(let underlyingError):
                errorMessage = "Decoding error: \(underlyingError.localizedDescription)"
            case .encodingError(let underlyingError): // Added this case
                errorMessage = "Encoding error: \(underlyingError.localizedDescription)"
            case .unknownError:
                errorMessage = "An unknown error occurred."
            // No default needed if all cases are handled as it's exhaustive now
            }
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func updateAvailableModels(for service: AIService) {
        switch service {
        case .openAI:
            self.availableModels = ["gpt-3.5-turbo", "gpt-4", "gpt-4-turbo-preview", "gpt-4o"]
        case .gemini:
            // Note: Gemini model names for API calls might be just "gemini-pro"
            self.availableModels = ["gemini-pro", "gemini-1.0-pro", "gemini-1.5-pro-latest"]
        }
        // If the currently selected model is not in the new list, update it.
        if !self.availableModels.contains(selectedModelKey) {
            // This write to @AppStorage might be better done in the View or a settings manager
            // to avoid potential issues with view updates during @AppStorage changes.
            // For now, we update it and it should reflect back.
            self.selectedModelKey = availableModels.first ?? ""
        }
    }
}
