// KTranslate/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    var onSettingsSaved: () -> Void

    @StateObject private var viewModel = SettingsViewModel()
    @FocusState private var focusedField: FocusableField?

    enum FocusableField: Hashable {
        case openAIKey, openAIHost, geminiKey
    }

    private func handleFocusChange(oldValue: FocusableField?, newValue: FocusableField?) {
        if (oldValue == .openAIKey && newValue != .openAIKey) || (oldValue == .openAIHost && newValue != .openAIHost) {
            if !viewModel.openAIAPIKey.isEmpty && !viewModel.openAIHost.isEmpty && viewModel.selectedService == .openAI {
                 viewModel.fetchOpenAIModels()
            }
        }
        if oldValue == .geminiKey && newValue != .geminiKey {
            if !viewModel.geminiAPIKey.isEmpty && viewModel.selectedService == .gemini {
                viewModel.fetchGeminiModels()
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Settings")
                .font(.largeTitle.weight(.light))
                .padding(.vertical)
            Divider()
            Form {
                Section {
                    Picker("Translation Service", selection: $viewModel.selectedService) {
                        ForEach(TranslationServiceType.allCases) { service in
                            Text(service.rawValue).tag(service)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 5)
                } header: {
                    Text("Translation Provider")
                        .font(.headline)
                        .padding(.top)
                }

                Group {
                    if viewModel.selectedService == .openAI {
                        openAISettings()
                    } else {
                        geminiSettings()
                    }
                }
                .animation(.easeInOut, value: viewModel.selectedService)
            }
            .formStyle(.grouped)
            Divider()
            footerButtons()
                .padding()
        }
        .frame(minWidth: 480, idealWidth: 520, maxWidth: 600, minHeight: 500, idealHeight: 580, maxHeight: 700)
        .background(.ultraThinMaterial)
        .onChange(of: focusedField) { oldValue, newValue in // Updated signature
            handleFocusChange(oldValue: oldValue, newValue: newValue)
        }
        .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage)
        }
        // Apply a default tint to the whole view for consistency if desired,
        // or tint individual elements like buttons.
        // For Settings, often buttons are explicitly styled.
    }

    @ViewBuilder
    private func openAISettings() -> some View {
        Section {
            VStack(alignment: .leading, spacing: 3) {
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
                models: viewModel.geminiModels.map { PickerableModel(id: $0.id, name: $0.id) },
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
                .pickerStyle(.menu)
                .disabled(isDisabled || models.isEmpty && !isLoading && errorMessage == nil)
                // .tint(Color.accentColor) // Picker can also be tinted if desired

                if isLoading {
                    ProgressView().scaleEffect(0.7).frame(width: 20, height: 20)
                }
            }
        }
    }

    @ViewBuilder
    private func footerButtons() -> some View {
        HStack {
            Button("Restore Defaults") {
                viewModel.restoreDefaultSettings()
                viewModel.presentAlert(title: "Settings Reset", message: "All settings have been restored to their default values.")
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .tint(Color.accentColor) // Apply accent color

            Spacer()

            Button("Cancel") {
                viewModel.revertChanges()
                isPresented = false
            }
            .keyboardShortcut(.escape, modifiers: [])
            // Cancel buttons usually don't get the primary accent color

            Button("Save") {
                viewModel.saveSettings()
                onSettingsSaved()
                isPresented = false
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled( (viewModel.selectedService == .openAI && (viewModel.openAIAPIKey.isEmpty || viewModel.selectedOpenAIModelId.isEmpty)) ||
                       (viewModel.selectedService == .gemini && (viewModel.geminiAPIKey.isEmpty || viewModel.selectedGeminiModelId.isEmpty)) )
            .tint(Color.accentColor) // Apply accent color to the primary save action
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        @State var isPresented: Bool = true
        SettingsView(isPresented: $isPresented, onSettingsSaved: {
            print("Settings saved (preview)")
        })
    }
}
