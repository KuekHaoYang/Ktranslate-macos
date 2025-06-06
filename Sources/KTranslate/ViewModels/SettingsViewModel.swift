// Sources/KTranslate/ViewModels/SettingsViewModel.swift
import SwiftUI
import Combine
// For Keychain access, you'd typically use a wrapper or `Security.framework` directly.
// For this example, we'll use @AppStorage for simplicity for API keys,
// but acknowledge that Keychain is the proper way for sensitive data.
// A placeholder for a proper Keychain service:
// import KeychainAccess // A popular third-party library, or implement your own.

class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties (UI State)
    @Published var selectedService: TranslationServiceType {
        didSet {
            // When service changes, clear models for the other service if they were fetched
            if selectedService == .openAI {
                geminiModels = []
                geminiModelErrorMessage = nil
            } else {
                openAIModels = []
                openAIModelErrorMessage = nil
            }
            // Automatically try to fetch models if API key for the new service is present
            if !apiKeyForSelectedService.isEmpty {
                fetchModelsForCurrentService()
            }
        }
    }

    // OpenAI Settings
    @Published var openAIAPIKey: String
    @Published var openAIHost: String
    @Published var selectedOpenAIModelId: String
    @Published var openAIModels: [OpenAIModel] = []
    @Published var isLoadingOpenAIModels: Bool = false
    @Published var openAIModelErrorMessage: String?

    // Gemini Settings
    @Published var geminiAPIKey: String
    @Published var selectedGeminiModelId: String
    @Published var geminiModels: [GeminiModel] = []
    @Published var isLoadingGeminiModels: Bool = false
    @Published var geminiModelErrorMessage: String?

    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""

    // MARK: - AppStorage Properties (Persistent Storage)
    // These @AppStorage properties will reflect the actual stored values.
    // The @Published properties above are for live editing in the Settings view.
    @AppStorage("selectedService") private var storedSelectedServiceRaw: String = TranslationServiceType.openAI.rawValue
    @AppStorage("openAIAPIKey") private var storedOpenAIAPIKey: String = "" // TODO: Replace with Keychain
    @AppStorage("openAIHost") private var storedOpenAIHost: String = "https://api.openai.com"
    @AppStorage("openAIModel") private var storedOpenAIModelId: String = ""
    @AppStorage("geminiAPIKey") private var storedGeminiAPIKey: String = "" // TODO: Replace with Keychain
    @AppStorage("geminiModel") private var storedGeminiModelId: String = ""

    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared

    var apiKeyForSelectedService: String {
        selectedService == .openAI ? openAIAPIKey : geminiAPIKey
    }

    var isModelSelectionDisabled: Bool {
        switch selectedService {
        case .openAI:
            return openAIAPIKey.isEmpty || isLoadingOpenAIModels
        case .gemini:
            return geminiAPIKey.isEmpty || isLoadingGeminiModels
        }
    }

    // MARK: - Initialization
    init() {
        // Initialize @Published properties from @AppStorage
        selectedService = TranslationServiceType(rawValue: storedSelectedServiceRaw) ?? .openAI
        openAIAPIKey = storedOpenAIAPIKey
        openAIHost = storedOpenAIHost.isEmpty ? "https://api.openai.com" : storedOpenAIHost
        selectedOpenAIModelId = storedOpenAIModelId
        geminiAPIKey = storedGeminiAPIKey
        selectedGeminiModelId = storedGeminiModelId

        // If API keys are already present, try to fetch models on init
        if !openAIAPIKey.isEmpty && selectedService == .openAI {
            fetchOpenAIModels()
        }
        if !geminiAPIKey.isEmpty && selectedService == .gemini {
            fetchGeminiModels()
        }

        // Setup listeners for API key changes to trigger model fetching
        setupApiKeyListeners()
    }

    private func setupApiKeyListeners() {
        $openAIAPIKey
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] key in
                guard let self = self, self.selectedService == .openAI, !key.isEmpty else { return }
                self.openAIModels = [] // Clear previous models
                self.selectedOpenAIModelId = "" // Reset selected model
                self.fetchOpenAIModels()
            }
            .store(in: &cancellables)

        $openAIHost // Also listen to host changes for OpenAI
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] host in
                guard let self = self, self.selectedService == .openAI, !self.openAIAPIKey.isEmpty, !host.isEmpty else { return }
                self.openAIModels = []
                self.selectedOpenAIModelId = ""
                self.fetchOpenAIModels()
            }
            .store(in: &cancellables)

        $geminiAPIKey
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] key in
                guard let self = self, self.selectedService == .gemini, !key.isEmpty else { return }
                self.geminiModels = [] // Clear previous models
                self.selectedGeminiModelId = "" // Reset selected model
                self.fetchGeminiModels()
            }
            .store(in: &cancellables)
    }

    // MARK: - Model Fetching
    func fetchModelsForCurrentService() {
        switch selectedService {
        case .openAI:
            fetchOpenAIModels()
        case .gemini:
            fetchGeminiModels()
        }
    }

    func fetchOpenAIModels() {
        guard !openAIAPIKey.isEmpty else {
            openAIModelErrorMessage = "OpenAI API Key is missing."
            openAIModels = []
            return
        }
        isLoadingOpenAIModels = true
        openAIModelErrorMessage = nil
        Task { @MainActor in
            do {
                let models = try await apiService.fetchOpenAIModels(apiKey: openAIAPIKey, apiHost: openAIHost.isEmpty ? "https://api.openai.com" : openAIHost)
                self.openAIModels = models.sorted(by: { $0.id < $1.id })
                // If previously selected model is still valid, keep it. Otherwise, clear or pick a default.
                if !self.openAIModels.contains(where: { $0.id == self.selectedOpenAIModelId }) {
                    self.selectedOpenAIModelId = self.openAIModels.first?.id ?? ""
                }
                 if models.isEmpty {
                    self.openAIModelErrorMessage = "No text models found for this API key/host."
                }
            } catch let error as APIServiceError {
                self.openAIModelErrorMessage = "Failed to fetch OpenAI models: \(error.localizedDescription)"
                self.openAIModels = []
                self.selectedOpenAIModelId = ""
            } catch {
                self.openAIModelErrorMessage = "An unexpected error occurred while fetching OpenAI models: \(error.localizedDescription)"
                self.openAIModels = []
                self.selectedOpenAIModelId = ""
            }
            self.isLoadingOpenAIModels = false
        }
    }

    func fetchGeminiModels() {
        guard !geminiAPIKey.isEmpty else {
            geminiModelErrorMessage = "Gemini API Key is missing."
            geminiModels = []
            return
        }
        isLoadingGeminiModels = true
        geminiModelErrorMessage = nil
        Task { @MainActor in
            do {
                let models = try await apiService.fetchGeminiModels(apiKey: geminiAPIKey)
                self.geminiModels = models.sorted(by: { $0.id < $1.id })
                // If previously selected model is still valid, keep it.
                if !self.geminiModels.contains(where: { $0.id == self.selectedGeminiModelId }) {
                     self.selectedGeminiModelId = self.geminiModels.first?.id ?? ""
                }
                if models.isEmpty {
                    self.geminiModelErrorMessage = "No text models found for this API key."
                }
            } catch let error as APIServiceError {
                self.geminiModelErrorMessage = "Failed to fetch Gemini models: \(error.localizedDescription)"
                self.geminiModels = []
                self.selectedGeminiModelId = ""
            } catch {
                self.geminiModelErrorMessage = "An unexpected error occurred while fetching Gemini models: \(error.localizedDescription)"
                self.geminiModels = []
                self.selectedGeminiModelId = ""
            }
            self.isLoadingGeminiModels = false
        }
    }

    // MARK: - Settings Management
    func saveSettings() {
        // Store current UI values into @AppStorage
        storedSelectedServiceRaw = selectedService.rawValue
        storedOpenAIAPIKey = openAIAPIKey // TODO: Replace with Keychain saving
        storedOpenAIHost = openAIHost.isEmpty ? "https://api.openai.com" : openAIHost
        storedOpenAIModelId = selectedOpenAIModelId
        storedGeminiAPIKey = geminiAPIKey // TODO: Replace with Keychain saving
        storedGeminiModelId = selectedGeminiModelId

        // Optionally, notify other parts of the app (like TranslationViewModel)
        // This can be done via a shared service, NotificationCenter, or by passing a callback.
        // For now, we assume TranslationViewModel reads @AppStorage directly or has a refresh mechanism.

        // Show a confirmation or handle errors if saving to Keychain fails.
        // For this example, direct @AppStorage write is assumed to succeed.
    }

    func restoreDefaultSettings() {
        // Reset @Published properties to their defaults
        selectedService = .openAI
        openAIAPIKey = ""
        openAIHost = "https://api.openai.com"
        selectedOpenAIModelId = ""
        openAIModels = []
        openAIModelErrorMessage = nil

        geminiAPIKey = ""
        selectedGeminiModelId = ""
        geminiModels = []
        geminiModelErrorMessage = nil

        // Persist these defaults
        saveSettings() // This will write the empty/default values to @AppStorage
    }

    // Call this method when the view is about to be dismissed without saving
    func revertChanges() {
        // Re-load settings from @AppStorage to discard any changes made in the UI
        selectedService = TranslationServiceType(rawValue: storedSelectedServiceRaw) ?? .openAI
        openAIAPIKey = storedOpenAIAPIKey
        openAIHost = storedOpenAIHost.isEmpty ? "https://api.openai.com" : storedOpenAIHost
        selectedOpenAIModelId = storedOpenAIModelId
        geminiAPIKey = storedGeminiAPIKey
        selectedGeminiModelId = storedGeminiModelId

        // Clear any error messages that might have occurred during editing
        openAIModelErrorMessage = nil
        geminiModelErrorMessage = nil

        // Re-fetch models if API keys were present to restore picker states
        if selectedService == .openAI && !openAIAPIKey.isEmpty && openAIModels.isEmpty {
            fetchOpenAIModels()
        } else if selectedService == .openAI && openAIAPIKey.isEmpty {
            openAIModels = [] // Clear models if API key was cleared
        }

        if selectedService == .gemini && !geminiAPIKey.isEmpty && geminiModels.isEmpty {
            fetchGeminiModels()
        } else if selectedService == .gemini && geminiAPIKey.isEmpty {
            geminiModels = [] // Clear models if API key was cleared
        }
    }

    func presentAlert(title: String, message: String) {
        self.alertTitle = title
        self.alertMessage = message
        self.showAlert = true
    }
}
