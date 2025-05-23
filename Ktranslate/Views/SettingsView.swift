import SwiftUI

struct SettingsView: View {
    @AppStorage("settings_apiHost") private var apiHost: String = "https://api.openai.com/v1" // Default for OpenAI
    @AppStorage("settings_apiKey") private var apiKey: String = ""
    @AppStorage("settings_selectedModel") private var selectedModel: String = "gpt-3.5-turbo"
    @AppStorage("settings_selectedService") private var selectedService: AIService = .openAI {
        didSet {
            // Update API host and model when service changes
            if oldValue != selectedService {
                switch selectedService {
                case .openAI:
                    apiHost = "https://api.openai.com/v1"
                    // Consider setting a default OpenAI model if current is not suitable
                    if !openAIModels.contains(selectedModel) {
                        selectedModel = openAIModels.first ?? "gpt-3.5-turbo"
                    }
                case .gemini:
                    apiHost = "https://generativelanguage.googleapis.com"
                     // Consider setting a default Gemini model if current is not suitable
                    if !geminiModels.contains(selectedModel) {
                        selectedModel = geminiModels.first ?? "gemini-pro"
                    }
                }
            }
        }
    }
    @AppStorage("settings_theme") private var theme: AppTheme = .system

    // Available models - these could be fetched or updated remotely in a real app
    private var openAIModels = ["gpt-3.5-turbo", "gpt-4", "gpt-4-turbo-preview", "gpt-4o"]
    private var geminiModels = ["gemini-pro", "gemini-1.0-pro", "gemini-1.5-pro-latest"]

    private var currentModels: [String] {
        switch selectedService {
        case .openAI:
            return openAIModels
        case .gemini:
            return geminiModels
        }
    }
    
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    // Picker("Service", selection: $selectedService) {
                    //     ForEach(AIService.allCases) { service in
                    //         Text(service.rawValue.capitalized).tag(service)
                    //     }
                    // }
                    // .padding(.vertical, 4)

                    // LabeledContent {
                    //     TextField("API Host", text: $apiHost, prompt: Text("e.g., https://api.openai.com/v1"))
                    //         .autocapitalization(.none)
                    //         .disableAutocorrection(true)
                    //         .multilineTextAlignment(.trailing) // Align text to the right for better readability
                    // } label: {
                    //     Text("API Host")
                    // }
                    // .padding(.vertical, 4)

                    // LabeledContent {
                    //      SecureField("API Key", text: $apiKey, prompt: Text("Enter your API key"))
                    //         .multilineTextAlignment(.trailing)
                    // } label: {
                    //     Text("API Key")
                    // }
                    // .padding(.vertical, 4)
                    Text("Placeholder Content") // New simplified content
                } header: {
                    Text("API Configuration") // Simplified header
                }

                Section {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(currentModels, id: \.self) { modelName in
                            Text(modelName).tag(modelName)
                        }
                    }
                    .padding(.vertical, 4)
                    .disabled(apiKey.isEmpty) // Disable if API key is not set
                    .onChange(of: selectedService) { _ in
                        // Ensure the selected model is valid for the new service
                        if !currentModels.contains(selectedModel) {
                            selectedModel = currentModels.first ?? ""
                        }
                    }
                } header: {
                    Text("Model Selection").font(.headline)
                }

                Section {
                    Picker("Theme", selection: $theme) {
                        ForEach(AppTheme.allCases) { appTheme in
                            Text(appTheme.rawValue.capitalized).tag(appTheme)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Appearance").font(.headline)
                }
                
                // Display current app version (example)
                Section {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Settings")
            // .navigationBarTitleDisplayMode(.inline) // Removed for macOS compatibility
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { // Changed for macOS compatibility
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
