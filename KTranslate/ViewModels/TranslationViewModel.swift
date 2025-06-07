// Sources/KTranslate/ViewModels/TranslationViewModel.swift
import SwiftUI
import Combine
import Speech // For Text-to-Speech

class TranslationViewModel: ObservableObject {
    // MARK: - Published Properties (UI State)
    @Published var sourceText: String = "" {
        didSet {
            characterCount = sourceText.count
            // Trigger debounced translation
            debouncedTranslateAction?.send()
        }
    }
    @Published var translatedText: String = ""
    @Published var characterCount: Int = 0

    @Published var sourceLanguage: Language = supportedLanguages.first(where: { $0.code == "auto" }) ?? Language(code: "auto", name: "Auto Detect")
    @Published var targetLanguage: Language = supportedLanguages.first(where: { $0.code == "en" }) ?? Language(code: "en", name: "English")

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil // For displaying errors to the user

    // MARK: - AppStorage for Settings (dependencies)
    @AppStorage("selectedService") private var selectedServiceRaw: String = TranslationServiceType.openAI.rawValue
    @AppStorage("openAIAPIKey") private var openAIAPIKey: String = "" // Keychain access is ideal here
    @AppStorage("openAIHost") private var openAIHost: String = ""
    @AppStorage("openAIModel") private var openAIModelId: String = ""
    @AppStorage("geminiAPIKey") private var geminiAPIKey: String = "" // Keychain access is ideal here
    @AppStorage("geminiModel") private var geminiModelId: String = ""

    // MARK: - Debouncing for Translation
    private var debouncedTranslateAction: PassthroughSubject<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let debounceInterval: TimeInterval = 0.75 // 750ms

    // MARK: - Text-to-Speech
    private let speechSynthesizer = AVSpeechSynthesizer()

    // MARK: - Initialization
    init() {
        setupDebouncer()
    }

    private func setupDebouncer() {
        debouncedTranslateAction = PassthroughSubject<Void, Never>()
        debouncedTranslateAction?
            .debounce(for: .seconds(debounceInterval), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.performTranslation()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods
    func swapLanguages() {
        guard sourceLanguage.code != "auto" else {
            // Cannot swap if source is "Auto Detect"
            // Optionally, show an alert or handle this case differently
            errorMessage = "Cannot swap languages when 'Auto Detect' is selected as the source."
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { // Clear message after a delay
                self.errorMessage = nil
            }
            return
        }
        let temp = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = temp

        // If source text exists, re-translate with new languages
        if !sourceText.isEmpty {
            performTranslation()
        }
    }

    func clearSourceText() {
        sourceText = ""
        translatedText = "" // Also clear translated text
    }

    func copyTranslatedTextToClipboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translatedText, forType: .string)
        #else
        // iOS/iPadOS clipboard handling (if ever needed)
        // UIPasteboard.general.string = translatedText
        #endif
    }

    func speakTranslatedText() {
        guard !translatedText.isEmpty else { return }

        // Stop any ongoing speech
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: translatedText)

        // Attempt to set voice based on target language
        // AVSpeechSynthesisVoice(language: targetLanguage.code) might not always find a perfect match
        // or a high-quality voice. The system will use a default if a specific one isn't found.
        if let voice = AVSpeechSynthesisVoice(language: targetLanguage.code) {
            utterance.voice = voice
        } else {
            // Try with a more general language code if specific (e.g., "en-US") is not found
            let generalLangCode = String(targetLanguage.code.prefix(2))
            if let generalVoice = AVSpeechSynthesisVoice(language: generalLangCode) {
                utterance.voice = generalVoice
            }
            // If still no voice, system default will be used.
        }

        // Adjust speech rate and pitch if desired
        // utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        // utterance.pitchMultiplier = 1.0

        speechSynthesizer.speak(utterance)
    }

    func performTranslation(force: Bool = false) {
        guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            translatedText = "" // Clear translation if source is empty
            return
        }

        // Do not translate if source language is auto and target is the same as auto (which is not logical)
        // Or if source and target languages are identical (and not auto)
        if (sourceLanguage.code == "auto" && targetLanguage.code == "auto") || (sourceLanguage.code != "auto" && sourceLanguage.code == targetLanguage.code) {
            translatedText = sourceText // No translation needed
            return
        }

        isLoading = true
        errorMessage = nil // Clear previous errors

        Task { @MainActor in // Ensure UI updates are on the main thread
            do {
                let serviceType = TranslationServiceType(rawValue: selectedServiceRaw) ?? .openAI
                let apiKey: String
                let model: String
                let host: String // Only for OpenAI

                switch serviceType {
                case .openAI:
                    apiKey = openAIAPIKey
                    model = openAIModelId
                    host = openAIHost
                    if apiKey.isEmpty || model.isEmpty {
                        throw APIServiceError.apiKeyNotSet // or modelNotSelected
                    }
                case .gemini:
                    apiKey = geminiAPIKey
                    model = geminiModelId
                    host = "" // Not used for Gemini
                    if apiKey.isEmpty || model.isEmpty {
                        throw APIServiceError.apiKeyNotSet // or modelNotSelected
                    }
                }

                // Guard against Auto-Detect for target language
                if targetLanguage.code == "auto" {
                    // This case should ideally be prevented by the UI,
                    // but as a safeguard:
                    self.translatedText = "Target language cannot be 'Auto Detect'."
                    self.isLoading = false
                    return
                }

                let result = try await APIService.shared.translate(
                    text: sourceText,
                    from: sourceLanguage,
                    to: targetLanguage,
                    service: serviceType,
                    apiKey: apiKey,
                    model: model,
                    openAIHost: host
                )
                self.translatedText = result
            } catch let error as APIServiceError {
                self.translatedText = "" // Clear previous translation on error
                self.errorMessage = error.localizedDescription
            } catch {
                self.translatedText = ""
                self.errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            }
            self.isLoading = false
        }
    }

    // Call this when settings change that might affect translation (e.g., API key, model)
    func settingsDidChange() {
        // If source text exists, re-translate with new settings
        if !sourceText.isEmpty {
            // Give a slight delay if a modal was just dismissed, to ensure UI is ready.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                 self.performTranslation(force: true) // Force re-translation
            }
        }
    }
}

// Helper to provide initial values for languages if needed elsewhere
let initialSourceLanguage: Language = supportedLanguages.first(where: { $0.code == "auto" }) ?? Language(code: "auto", name: "Auto Detect")
let initialTargetLanguage: Language = supportedLanguages.first(where: { $0.code == "en" }) ?? Language(code: "en", name: "English")
