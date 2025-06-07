// KTranslate/ViewModels/SettingsViewModel.swift
import SwiftUI
import Combine

class SettingsViewModel: ObservableObject {
    // MARK: - AppStorage Properties
    @AppStorage("selectedService") private var storedSelectedServiceRaw: String = TranslationServiceType.openAI.rawValue
    @AppStorage("openAIAPIKey") private var storedOpenAIAPIKey: String = ""
    @AppStorage("openAIHost") private var storedOpenAIHost: String = "https://api.openai.com"
    @AppStorage("openAIModel") private var storedOpenAIModelId: String = ""
    @AppStorage("geminiAPIKey") private var storedGeminiAPIKey: String = ""
    @AppStorage("geminiModel") private var storedGeminiModelId: String = ""

    // MARK: - Published Properties
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

    init() {
        // Stage 1: Initialize all @Published properties with default/empty values.
        // This ensures they are all fully initialized before any potential cross-access.
        self.selectedService = .openAI // Default, will be overwritten
        self.openAIAPIKey = ""
        self.openAIHost = ""
        self.selectedOpenAIModelId = ""
        self.geminiAPIKey = ""
        self.selectedGeminiModelId = ""

        // Stage 2: Now assign actual values from @AppStorage or other defaults.
        let initialService = TranslationServiceType(rawValue: storedSelectedServiceRaw) ?? .openAI
        self.selectedService = initialService
        self.openAIAPIKey = storedOpenAIAPIKey
        self.openAIHost = storedOpenAIHost.isEmpty ? "https://api.openai.com" : storedOpenAIHost
        self.selectedOpenAIModelId = storedOpenAIModelId
        self.geminiAPIKey = storedGeminiAPIKey
        self.selectedGeminiModelId = storedGeminiModelId

        updateModelsForSelectedService(service: initialService, isInitialLoad: true)
        setupApiKeyListeners()
        setupServiceChangeListener()
    }

    private func setupServiceChangeListener() {
        $selectedService
            .dropFirst()
            .sink { [weak self] newService in
                self?.updateModelsForSelectedService(service: newService, isInitialLoad: false)
            }
            .store(in: &cancellables)
    }

    private func updateModelsForSelectedService(service: TranslationServiceType, isInitialLoad: Bool) {
        if service == .openAI {
            geminiModels = []
            geminiModelErrorMessage = nil
            if !openAIAPIKey.isEmpty || (isInitialLoad && !storedOpenAIAPIKey.isEmpty) {
                fetchOpenAIModels()
            } else if openAIAPIKey.isEmpty { // If API key is empty, clear models
                openAIModels = []
                selectedOpenAIModelId = ""
            }
        } else { // Gemini
            openAIModels = []
            openAIModelErrorMessage = nil
            if !geminiAPIKey.isEmpty || (isInitialLoad && !storedGeminiAPIKey.isEmpty) {
                fetchGeminiModels()
            } else if geminiAPIKey.isEmpty { // If API key is empty, clear models
                geminiModels = []
                selectedGeminiModelId = ""
            }
        }
    }

    private func setupApiKeyListeners() {
        $openAIAPIKey
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] key in
                guard let self = self, self.selectedService == .openAI else { return }
                if key.isEmpty {
                    self.openAIModels = []
                    self.selectedOpenAIModelId = ""
                    self.openAIModelErrorMessage = "OpenAI API Key is missing."
                } else {
                    self.fetchOpenAIModels()
                }
            }
            .store(in: &cancellables)

        $openAIHost
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] host in
                guard let self = self, self.selectedService == .openAI, !self.openAIAPIKey.isEmpty else { return }
                // Host change implies re-fetching models.
                self.fetchOpenAIModels()
            }
            .store(in: &cancellables)

        $geminiAPIKey
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] key in
                guard let self = self, self.selectedService == .gemini else { return }
                if key.isEmpty {
                    self.geminiModels = []
                    self.selectedGeminiModelId = ""
                    self.geminiModelErrorMessage = "Gemini API Key is missing."
                } else {
                    self.fetchGeminiModels()
                }
            }
            .store(in: &cancellables)
    }

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
            selectedOpenAIModelId = ""
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
                if models.isEmpty && self.openAIModelErrorMessage == nil { // Only set if no other error occurred
                    self.openAIModelErrorMessage = "No text models found for this API key/host."
                }
            } catch let error as APIServiceError {
                self.openAIModelErrorMessage = "Failed to fetch OpenAI models: \(error.localizedDescription)"
                self.openAIModels = []
                self.selectedOpenAIModelId = ""
            } catch {
                self.openAIModelErrorMessage = "An unexpected error: \(error.localizedDescription)"
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
            selectedGeminiModelId = ""
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
                if models.isEmpty && self.geminiModelErrorMessage == nil { // Only set if no other error occurred
                    self.geminiModelErrorMessage = "No text models found for this API key."
                }
            } catch let error as APIServiceError {
                self.geminiModelErrorMessage = "Failed to fetch Gemini models: \(error.localizedDescription)"
                self.geminiModels = []
                self.selectedGeminiModelId = ""
            } catch {
                self.geminiModelErrorMessage = "An unexpected error: \(error.localizedDescription)"
                self.geminiModels = []
                self.selectedGeminiModelId = ""
            }
            self.isLoadingGeminiModels = false
        }
    }

    func saveSettings() {
        storedSelectedServiceRaw = selectedService.rawValue
        storedOpenAIAPIKey = openAIAPIKey
        storedOpenAIHost = openAIHost.isEmpty ? "https://api.openai.com" : openAIHost
        storedOpenAIModelId = selectedOpenAIModelId
        storedGeminiAPIKey = geminiAPIKey
        storedGeminiModelId = selectedGeminiModelId
    }

    func restoreDefaultSettings() {
        // Set to defaults
        let defaultService = TranslationServiceType.openAI
        let defaultAPIKey = ""
        let defaultHost = "https://api.openai.com"
        let defaultModelId = ""

        self.selectedService = defaultService
        self.openAIAPIKey = defaultAPIKey
        self.openAIHost = defaultHost
        self.selectedOpenAIModelId = defaultModelId
        self.geminiAPIKey = defaultAPIKey
        self.selectedGeminiModelId = defaultModelId

        saveSettings() // Persist these defaults immediately

        // Update model lists based on these new defaults
        // This will clear models as keys are now empty.
        updateModelsForSelectedService(service: self.selectedService, isInitialLoad: false)
    }

    func revertChanges() {
        self.selectedService = TranslationServiceType(rawValue: storedSelectedServiceRaw) ?? .openAI
        self.openAIAPIKey = storedOpenAIAPIKey
        self.openAIHost = storedOpenAIHost.isEmpty ? "https://api.openai.com" : storedOpenAIHost
        self.selectedOpenAIModelId = storedOpenAIModelId
        self.geminiAPIKey = storedGeminiAPIKey
        self.selectedGeminiModelId = storedGeminiModelId

        openAIModelErrorMessage = nil
        geminiModelErrorMessage = nil

        updateModelsForSelectedService(service: self.selectedService, isInitialLoad: true) // isInitialLoad true to force model load if keys exist
    }

    func presentAlert(title: String, message: String) {
        self.alertTitle = title
        self.alertMessage = message
        self.showAlert = true
    }
}
