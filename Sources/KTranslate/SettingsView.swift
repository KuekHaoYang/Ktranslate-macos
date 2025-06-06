// Sources/KTranslate/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    var onSettingsSaved: () -> Void // Callback to notify ContentView

    @StateObject private var viewModel = SettingsViewModel()
    @FocusState private var focusedField: FocusableField? // For managing focus, e.g., after API key entry

    enum FocusableField: Hashable {
        case openAIKey, openAIHost, geminiKey
    }

    // To trigger model fetch when focus leaves API key fields
    private func handleFocusChange(oldValue: FocusableField?, newValue: FocusableField?) {
        // OpenAI: Fetch if focus moves away from API key or Host, and both are filled
        if (oldValue == .openAIKey && newValue != .openAIKey) || (oldValue == .openAIHost && newValue != .openAIHost) {
            if !viewModel.openAIAPIKey.isEmpty && !viewModel.openAIHost.isEmpty && viewModel.selectedService == .openAI {
                 viewModel.fetchOpenAIModels()
            }
        }
        // Gemini: Fetch if focus moves away from API key, and it's filled
        if oldValue == .geminiKey && newValue != .geminiKey {
            if !viewModel.geminiAPIKey.isEmpty && viewModel.selectedService == .gemini {
                viewModel.fetchGeminiModels()
            }
        }
    }


    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            Text("Settings")
                .font(.largeTitle.weight(.light)) // Adjusted font
                .padding(.vertical) // More vertical padding

            Divider()

            // MARK: - Form Content
            Form {
                // MARK: Service Selection
                Section {
                    Picker("Translation Service", selection: $viewModel.selectedService) {
                        ForEach(TranslationServiceType.allCases) { service in
                            Text(service.rawValue).tag(service)
                        }
                    }
                    .pickerStyle(.segmented) // More prominent style for service selection
                    .padding(.vertical, 5)
                } header: {
                    Text("Translation Provider")
                        .font(.headline)
                        .padding(.top) // Add padding to section headers
                }

                // MARK: Service-Specific Configuration
                Group {
                    if viewModel.selectedService == .openAI {
                        openAISettings()
                    } else {
                        geminiSettings()
                    }
                }
                .animation(.easeInOut, value: viewModel.selectedService) // Animate change between sections
            }
            .formStyle(.grouped) // Grouped style for better visual separation on macOS

            // MARK: - Footer Buttons
            Divider()
            footerButtons()
                .padding()
        }
        .frame(minWidth: 480, idealWidth: 520, maxWidth: 600, minHeight: 500, idealHeight: 580, maxHeight: 700) // Adjusted frame size
        .background(.ultraThinMaterial)
        .onChange(of: focusedField, perform: { oldVal, newVal in // Use new onChange syntax
            handleFocusChange(oldValue: oldVal, newValue: newVal)
        })
        .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage)
        }
    }

    // MARK: - OpenAI Settings Section
    @ViewBuilder
    private func openAISettings() -> some View {
        Section {
            VStack(alignment: .leading, spacing: 3) { // Reduced spacing
                Text("API Key").font(.caption).foregroundColor(.gray)
                SecureField("Enter your OpenAI API Key", text: $viewModel.openAIAPIKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .openAIKey)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("API Host (Optional)").font(.caption).foregroundColor(.gray)
                TextField("e.g., https://api.openai.com", text: $viewModel.openAIHost)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .openAIHost)
                Text("Default: https://api.openai.com")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            modelPicker(
                models: viewModel.openAIModels.map { PickerableModel(id: $0.id, name: $0.id) },
                selection: $viewModel.selectedOpenAIModelId,
                isLoading: viewModel.isLoadingOpenAIModels,
                errorMessage: viewModel.openAIModelErrorMessage,
                isDisabled: viewModel.isModelSelectionDisabled,
                serviceName: "OpenAI"
            )
        } header: {
            Text("OpenAI Configuration")
                .font(.headline)
        } footer: {
            if let error = viewModel.openAIModelErrorMessage, !error.isEmpty {
                Text(error).font(.caption).foregroundColor(.red).padding(.top, 2)
            } else if viewModel.isLoadingOpenAIModels {
                 Text("Fetching OpenAI models...").font(.caption).foregroundColor(.orange).padding(.top, 2)
            }
        }
    }

    // MARK: - Gemini Settings Section
    @ViewBuilder
    private func geminiSettings() -> some View {
        Section {
            VStack(alignment: .leading, spacing: 3) {
                Text("API Key").font(.caption).foregroundColor(.gray)
                SecureField("Enter your Gemini API Key", text: $viewModel.geminiAPIKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .geminiKey)
            }

            modelPicker(
                models: viewModel.geminiModels.map { PickerableModel(id: $0.id, name: $0.id) }, // Use computed 'id' for display
                selection: $viewModel.selectedGeminiModelId,
                isLoading: viewModel.isLoadingGeminiModels,
                errorMessage: viewModel.geminiModelErrorMessage,
                isDisabled: viewModel.isModelSelectionDisabled,
                serviceName: "Gemini"
            )
        } header: {
            Text("Gemini Configuration")
                .font(.headline)
        } footer: {
             if let error = viewModel.geminiModelErrorMessage, !error.isEmpty {
                Text(error).font(.caption).foregroundColor(.red).padding(.top, 2)
            } else if viewModel.isLoadingGeminiModels {
                 Text("Fetching Gemini models...").font(.caption).foregroundColor(.orange).padding(.top, 2)
            }
        }
    }

    // MARK: - Generic Model Picker
    struct PickerableModel: Identifiable, Hashable {
        let id: String
        let name: String
    }

    @ViewBuilder
    private func modelPicker(
        models: [PickerableModel],
        selection: Binding<String>,
        isLoading: Bool,
        errorMessage: String?,
        isDisabled: Bool,
        serviceName: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Model").font(.caption).foregroundColor(.gray)
            HStack {
                Picker("Select Model", selection: selection) {
                    if models.isEmpty && !isLoading && errorMessage == nil {
                        Text("No models available").tag("")
                    } else if isLoading {
                        Text("Loading models...").tag("")
                    } else if errorMessage != nil && models.isEmpty {
                         Text("Unavailable (check API key/host)").tag("")
                    }

                    ForEach(models) { model in
                        Text(model.name).tag(model.id)
                    }
                }
                .pickerStyle(.menu) // Standard dropdown
                .disabled(isDisabled || models.isEmpty && !isLoading && errorMessage == nil)

                if isLoading {
                    ProgressView().scaleEffect(0.7).frame(width: 20, height: 20)
                }
            }
        }
    }


    // MARK: - Footer Buttons
    @ViewBuilder
    private func footerButtons() -> some View {
        HStack {
            Button("Restore Defaults") {
                viewModel.restoreDefaultSettings()
                // Optionally show an alert or confirmation
                viewModel.presentAlert(title: "Settings Reset", message: "All settings have been restored to their default values.")
            }
            .keyboardShortcut(.delete, modifiers: .command) // Example shortcut

            Spacer()

            Button("Cancel") {
                viewModel.revertChanges() // Discard changes
                isPresented = false
            }
            .keyboardShortcut(.escape, modifiers: []) // Standard cancel shortcut

            Button("Save") {
                viewModel.saveSettings()
                onSettingsSaved() // Notify ContentView to potentially refresh
                isPresented = false
            }
            .keyboardShortcut("s", modifiers: .command) // Standard save shortcut
            .disabled( (viewModel.selectedService == .openAI && (viewModel.openAIAPIKey.isEmpty || viewModel.selectedOpenAIModelId.isEmpty)) ||
                       (viewModel.selectedService == .gemini && (viewModel.geminiAPIKey.isEmpty || viewModel.selectedGeminiModelId.isEmpty)) )
        }
    }
}


// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a dummy binding for isPresented
        @State var isPresented: Bool = true
        SettingsView(isPresented: $isPresented, onSettingsSaved: {
            print("Settings saved (preview)")
        })
        .onAppear {
            // You can configure the viewModel for different preview states here if needed
            // For example, to show OpenAI selected:
            // let vm = SettingsViewModel()
            // vm.selectedService = .openAI
            // return SettingsView(isPresented: $isPresented, onSettingsSaved: {}, viewModel: vm) // if you pass vm as param
        }
    }
}
