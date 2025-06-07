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
            // Models should be selectable if already loaded, even if API key is then cleared (user might want to see what was selected)
            // Disabling should primarily be if models are loading, or if no API key/host has EVER been validly entered for this session.
            // Or if an error occurred that prevents model selection.
            return isLoadingOpenAIModels || (openAIModels.isEmpty && (openAIAPIKey.isEmpty || openAIHost.isEmpty))
        case .gemini:
            return isLoadingGeminiModels || (geminiModels.isEmpty && geminiAPIKey.isEmpty)
        }
    }

    init() {
        self.selectedService = .openAI
        self.openAIAPIKey = ""
        self.openAIHost = ""
        self.selectedOpenAIModelId = ""
        self.geminiAPIKey = ""
        self.selectedGeminiModelId = ""

        let initialService = TranslationServiceType(rawValue: storedSelectedServiceRaw) ?? .openAI
        self.selectedService = initialService
        self.openAIAPIKey = storedOpenAIAPIKey
        self.openAIHost = storedOpenAIHost.isEmpty ? "https://api.openai.com" : storedOpenAIHost
        self.selectedOpenAIModelId = storedOpenAIModelId
        self.geminiAPIKey = storedGeminiAPIKey
        self.selectedGeminiModelId = storedGeminiModelId

        // Initial model load logic
        updateModelsForSelectedService(service: initialService, isInitialLoad: true)

        setupServiceChangeListener() // Handles subsequent service changes
        setupApiKeyListeners()       // Handles subsequent key/host changes
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
            geminiModels = [] // Clear other service's models and error
            geminiModelErrorMessage = nil
            // Use current @Published values unless it's the very first load from @AppStorage
            let keyToUse = isInitialLoad ? storedOpenAIAPIKey : openAIAPIKey
            let hostToUse = isInitialLoad ? (storedOpenAIHost.isEmpty ? "https://api.openai.com" : storedOpenAIHost) : openAIHost

            if !keyToUse.isEmpty && !hostToUse.isEmpty {
                fetchOpenAIModels() // fetchOpenAIModels uses self.openAIAPIKey and self.openAIHost internally
            } else {
                openAIModels = []
                selectedOpenAIModelId = ""
                if keyToUse.isEmpty { openAIModelErrorMessage = "OpenAI API Key is missing." }
                else if hostToUse.isEmpty { openAIModelErrorMessage = "OpenAI API Host is missing." } // Should only happen if user clears a non-empty default
            }
        } else { // Gemini
            openAIModels = [] // Clear other service's models and error
            openAIModelErrorMessage = nil
            let keyToUse = isInitialLoad ? storedGeminiAPIKey : geminiAPIKey

            if !keyToUse.isEmpty {
                fetchGeminiModels() // fetchGeminiModels uses self.geminiAPIKey internally
            } else {
                geminiModels = []
                selectedGeminiModelId = ""
                if keyToUse.isEmpty { geminiModelErrorMessage = "Gemini API Key is missing." }
            }
        }
    }

    private func setupApiKeyListeners() {
        // Listener for OpenAI API Key
        $openAIAPIKey
            .dropFirst() // Handled by init or service change
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] key in
                guard let self = self else { return }
                if self.selectedService == .openAI {
                    if key.isEmpty {
                        self.openAIModels = []; self.selectedOpenAIModelId = ""; self.openAIModelErrorMessage = "OpenAI API Key is missing."
                    } else if self.openAIHost.isEmpty {
                        self.openAIModels = []; self.selectedOpenAIModelId = ""; self.openAIModelErrorMessage = "OpenAI API Host is missing."
                    } else { // Key and host are present
                        self.fetchOpenAIModels()
                    }
                }
            }
            .store(in: &cancellables)

        // Listener for OpenAI Host
        $openAIHost
            .dropFirst() // Handled by init or service change
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] host in
                guard let self = self else { return }
                if self.selectedService == .openAI {
                    if host.isEmpty {
                        self.openAIModels = []; self.selectedOpenAIModelId = ""; self.openAIModelErrorMessage = "OpenAI API Host is missing."
                    } else if self.openAIAPIKey.isEmpty {
                        self.openAIModels = []; self.selectedOpenAIModelId = ""; self.openAIModelErrorMessage = "OpenAI API Key is missing."
                    } else { // Host and key are present
                        self.fetchOpenAIModels()
                    }
                }
            }
            .store(in: &cancellables)

        // Listener for Gemini API Key
        $geminiAPIKey
            .dropFirst() // Handled by init or service change
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] key in
                guard let self = self else { return }
                if self.selectedService == .gemini {
                    if key.isEmpty {
                        self.geminiModels = []; self.selectedGeminiModelId = ""; self.geminiModelErrorMessage = "Gemini API Key is missing."
                    } else { // Key is present
                        self.fetchGeminiModels()
                    }
                }
            }
            .store(in: &cancellables)
    }

    // fetchModelsForCurrentService() can be removed if not called externally,
    // as specific fetchOpenAIModels/fetchGeminiModels are called by listeners/updaters.
    // Keeping it for now if SettingsView's handleFocusChange still uses it.
    func fetchModelsForCurrentService() {
        switch selectedService {
        case .openAI:
            if !openAIAPIKey.isEmpty && !openAIHost.isEmpty { fetchOpenAIModels() }
            else if openAIAPIKey.isEmpty { openAIModelErrorMessage = "OpenAI API Key is missing."; openAIModels=[]; selectedOpenAIModelId="" }
            else { openAIModelErrorMessage = "OpenAI API Host is missing."; openAIModels=[]; selectedOpenAIModelId="" }
        case .gemini:
            if !geminiAPIKey.isEmpty { fetchGeminiModels() }
            else { geminiModelErrorMessage = "Gemini API Key is missing."; geminiModels=[]; selectedGeminiModelId="" }
        }
    }

    func fetchOpenAIModels() {
        guard !openAIAPIKey.isEmpty else { /* Handled by callers */ return }
        guard !openAIHost.isEmpty else { /* Handled by callers */ return }

        isLoadingOpenAIModels = true
        openAIModelErrorMessage = nil // Clear previous errors before fetching
        Task { @MainActor in
            do {
                // Pass current (potentially updated via @Published) values
                let models = try await apiService.fetchOpenAIModels(apiKey: self.openAIAPIKey, apiHost: self.openAIHost)
                self.openAIModels = models.sorted(by: { $0.id < $1.id })
                if !self.openAIModels.contains(where: { $0.id == self.selectedOpenAIModelId }) {
                    self.selectedOpenAIModelId = self.openAIModels.first?.id ?? ""
                }
                if models.isEmpty && self.openAIModelErrorMessage == nil {
                    self.openAIModelErrorMessage = "No text models found for this API key/host."
                }
            } catch let error as APIServiceError {
                self.openAIModelErrorMessage = "Fetch Error: \(error.localizedDescription)"
                self.openAIModels = []; self.selectedOpenAIModelId = ""
            } catch {
                self.openAIModelErrorMessage = "Unexpected Error: \(error.localizedDescription)"
                self.openAIModels = []; self.selectedOpenAIModelId = ""
            }
            self.isLoadingOpenAIModels = false
        }
    }

    func fetchGeminiModels() {
        guard !geminiAPIKey.isEmpty else { /* Handled by callers */ return }

        isLoadingGeminiModels = true
        geminiModelErrorMessage = nil // Clear previous errors
        Task { @MainActor in
            do {
                let models = try await apiService.fetchGeminiModels(apiKey: self.geminiAPIKey)
                self.geminiModels = models.sorted(by: { $0.id < $1.id })
                if !self.geminiModels.contains(where: { $0.id == self.selectedGeminiModelId }) {
                     self.selectedGeminiModelId = self.geminiModels.first?.id ?? ""
                }
                if models.isEmpty && self.geminiModelErrorMessage == nil {
                    self.geminiModelErrorMessage = "No text models found for this API key."
                }
            } catch let error as APIServiceError {
                self.geminiModelErrorMessage = "Fetch Error: \(error.localizedDescription)"
                self.geminiModels = []; self.selectedGeminiModelId = ""
            } catch {
                self.geminiModelErrorMessage = "Unexpected Error: \(error.localizedDescription)"
                self.geminiModels = []; self.selectedGeminiModelId = ""
            }
            self.isLoadingGeminiModels = false
        }
    }

    func saveSettings() {
        storedSelectedServiceRaw = selectedService.rawValue
        storedOpenAIAPIKey = openAIAPIKey
        storedOpenAIHost = openAIHost // Save the actual value, even if empty. Defaulting is for display/use.
        storedOpenAIModelId = selectedOpenAIModelId
        storedGeminiAPIKey = geminiAPIKey
        storedGeminiModelId = selectedGeminiModelId
    }

    func restoreDefaultSettings() {
        let defaultService = TranslationServiceType.openAI
        let defaultAPIKey = ""
        let defaultHost = "https://api.openai.com" // Standard default
        let defaultModelId = ""

        self.selectedService = defaultService
        self.openAIAPIKey = defaultAPIKey
        self.openAIHost = defaultHost
        self.selectedOpenAIModelId = defaultModelId
        self.geminiAPIKey = defaultAPIKey
        self.selectedGeminiModelId = defaultModelId

        saveSettings()
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

        updateModelsForSelectedService(service: self.selectedService, isInitialLoad: true)
    }

    func presentAlert(title: String, message: String) {
        self.alertTitle = title
        self.alertMessage = message
        self.showAlert = true
    }
}
