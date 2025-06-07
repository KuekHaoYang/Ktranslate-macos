// KTranslate/ViewModels/SettingsViewModel.swift
import SwiftUI
import Combine

class SettingsViewModel: ObservableObject {
    // MARK: - AppStorage Properties (Persistent Storage)
    // These must be declared before they are used by @Published properties in init
    @AppStorage("selectedService") private var storedSelectedServiceRaw: String = TranslationServiceType.openAI.rawValue
    @AppStorage("openAIAPIKey") private var storedOpenAIAPIKey: String = "" // TODO: Replace with Keychain
    @AppStorage("openAIHost") private var storedOpenAIHost: String = "https://api.openai.com"
    @AppStorage("openAIModel") private var storedOpenAIModelId: String = ""
    @AppStorage("geminiAPIKey") private var storedGeminiAPIKey: String = "" // TODO: Replace with Keychain
    @AppStorage("geminiModel") private var storedGeminiModelId: String = ""

    // MARK: - Published Properties (UI State)
    @Published var selectedService: TranslationServiceType
    @Published var openAIAPIKey: String
    @Published var openAIHost: String
    @Published var selectedOpenAIModelId: String
    @Published var geminiAPIKey: String
    @Published var selectedGeminiModelId: String

    @Published var openAIModels: [OpenAIModel] = []
    @Published var isLoadingOpenAIModels: Bool = false
    @Published var openAIModelErrorMessage: String?

    @Published var geminiModels: [GeminiModel] = []
    @Published var isLoadingGeminiModels: Bool = false
    @Published var geminiModelErrorMessage: String?

    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""

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
        // Initialize @Published properties from @AppStorage values
        // This is the correct place to do it, after all stored properties (incl. @AppStorage) are initialized.
        let initialService = TranslationServiceType(rawValue: storedSelectedServiceRaw) ?? .openAI
        self.selectedService = initialService
        self.openAIAPIKey = storedOpenAIAPIKey
        self.openAIHost = storedOpenAIHost.isEmpty ? "https://api.openai.com" : storedOpenAIHost
        self.selectedOpenAIModelId = storedOpenAIModelId
        self.geminiAPIKey = storedGeminiAPIKey
        self.selectedGeminiModelId = storedGeminiModelId

        // Setup didSet equivalent for selectedService because direct didSet on @Published property initialized
        // from another property wrapper in init might not behave as expected for the *initial* set.
        // We need to react to changes *after* initial setup.
        // However, for the *initial* load, we can directly call the logic.
        updateModelsForSelectedService(service: initialService, isInitialLoad: true)

        // Setup listeners for API key changes to trigger model fetching
        setupApiKeyListeners()
        setupServiceChangeListener()
    }

    private func setupServiceChangeListener() {
        $selectedService
            .dropFirst() // Ignore the initial value set in init()
            .sink { [weak self] newService in
                self?.updateModelsForSelectedService(service: newService, isInitialLoad: false)
            }
            .store(in: &cancellables)
    }

    private func updateModelsForSelectedService(service: TranslationServiceType, isInitialLoad: Bool) {
        if service == .openAI {
            geminiModels = [] // Clear other service's models
            geminiModelErrorMessage = nil
            if !openAIAPIKey.isEmpty || isInitialLoad && !storedOpenAIAPIKey.isEmpty { // On initial load, check stored key
                fetchOpenAIModels()
            }
        } else { // Gemini
            openAIModels = [] // Clear other service's models
            openAIModelErrorMessage = nil
            if !geminiAPIKey.isEmpty || isInitialLoad && !storedGeminiAPIKey.isEmpty { // On initial load, check stored key
                fetchGeminiModels()
            }
        }
    }


    private func setupApiKeyListeners() {
        $openAIAPIKey
            .dropFirst() // Ignore initial value
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] key in
                guard let self = self, self.selectedService == .openAI, !key.isEmpty else { return }
                self.openAIModels = []
                self.selectedOpenAIModelId = ""
                self.fetchOpenAIModels()
            }
            .store(in: &cancellables)

        $openAIHost
            .dropFirst() // Ignore initial value
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
            .dropFirst() // Ignore initial value
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] key in
                guard let self = self, self.selectedService == .gemini, !key.isEmpty else { return }
                self.geminiModels = []
                self.selectedGeminiModelId = ""
                self.fetchGeminiModels()
            }
            .store(in: &cancellables)
    }

    // MARK: - Model Fetching
    func fetchModelsForCurrentService() { // Renamed from original for clarity, or keep if used elsewhere
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
            selectedOpenAIModelId = "" // Clear selected model
            return
        }
        isLoadingOpenAIModels = true
        openAIModelErrorMessage = nil
        Task { @MainActor in
            do {
                let models = try await apiService.fetchOpenAIModels(apiKey: openAIAPIKey, apiHost: openAIHost.isEmpty ? "https://api.openai.com" : openAIHost)
                self.openAIModels = models.sorted(by: { $0.id < $1.id })
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
            selectedGeminiModelId = "" // Clear selected model
            return
        }
        isLoadingGeminiModels = true
        geminiModelErrorMessage = nil
        Task { @MainActor in
            do {
                let models = try await apiService.fetchGeminiModels(apiKey: geminiAPIKey)
                self.geminiModels = models.sorted(by: { $0.id < $1.id })
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
        storedSelectedServiceRaw = selectedService.rawValue
        storedOpenAIAPIKey = openAIAPIKey
        storedOpenAIHost = openAIHost.isEmpty ? "https://api.openai.com" : openAIHost
        storedOpenAIModelId = selectedOpenAIModelId
        storedGeminiAPIKey = geminiAPIKey
        storedGeminiModelId = selectedGeminiModelId
    }

    func restoreDefaultSettings() {
        selectedService = .openAI
        openAIAPIKey = ""
        openAIHost = "https://api.openai.com"
        // selectedOpenAIModelId = "" // Let model fetching handle this
        // openAIModels = []
        // openAIModelErrorMessage = nil

        geminiAPIKey = ""
        // selectedGeminiModelId = "" // Let model fetching handle this
        // geminiModels = []
        // geminiModelErrorMessage = nil

        // After resetting API keys, the model lists will clear / re-fetch via listeners.
        // Explicitly call save to persist these cleared/default values.
        saveSettings()

        // Manually trigger model fetching logic as API keys are now empty
        // or service might have changed.
        // The listeners for API keys will handle clearing models.
        // The listener for selectedService will handle fetching for the new default service.
        // If current selectedService is already default, call explicitly.
        if self.selectedService == .openAI {
             self.openAIModels = []
             self.selectedOpenAIModelId = ""
             self.geminiModels = [] // Ensure other service models are cleared
             self.selectedGeminiModelId = ""
        } else { // if default was Gemini, though current code defaults to OpenAI
             self.geminiModels = []
             self.selectedGeminiModelId = ""
             self.openAIModels = []
             self.selectedOpenAIModelId = ""
        }
    }

    func revertChanges() {
        selectedService = TranslationServiceType(rawValue: storedSelectedServiceRaw) ?? .openAI
        openAIAPIKey = storedOpenAIAPIKey
        openAIHost = storedOpenAIHost.isEmpty ? "https://api.openai.com" : storedOpenAIHost
        selectedOpenAIModelId = storedOpenAIModelId
        geminiAPIKey = storedGeminiAPIKey
        selectedGeminiModelId = storedGeminiModelId

        openAIModelErrorMessage = nil
        geminiModelErrorMessage = nil

        // Re-fetch models for the loaded service to restore picker states correctly
        updateModelsForSelectedService(service: selectedService, isInitialLoad: true)
    }

    func presentAlert(title: String, message: String) {
        self.alertTitle = title
        self.alertMessage = message
        self.showAlert = true
    }
}
