import SwiftUI

struct MainView: View {
    @StateObject var viewModel = TranslationViewModel()
    @State private var showingSettings = false

    // Mock language list - replace with actual data later
    let mockLanguages = ["auto", "en", "es", "fr", "de", "ja", "ko", "zh"]

    var body: some View {
        NavigationView {
            VStack(spacing: 20) { // Increased global spacing
                // Source Text Input
                VStack(alignment: .leading, spacing: 5) {
                    Text("Translate:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ZStack(alignment: .topLeading) {
                        if viewModel.sourceText.isEmpty {
                            Text("Enter text to translate...")
                                .foregroundColor(Color.gray.opacity(0.6))
                                .padding(.top, 8)
                                .padding(.leading, 6) // Ensure this aligns with TextEditor's internal padding
                        }
                        TextEditor(text: $viewModel.sourceText)
                            .frame(minHeight: 150, maxHeight: 300) // Min height, expandable
                            .padding(4) // Internal padding
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(CGColor(gray: 0.96, alpha: 1.0))) // Distinct background
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1) // Subtle border
                            )
                    }
                    .accessibilityLabel("Source text to translate")
                }

                // Language Selection
                HStack(spacing: 10) {
                    HStack {
                        Text("From:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $viewModel.sourceLanguage) {
                            ForEach(mockLanguages, id: \.self) { lang in
                                Text(lang.uppercased()).tag(lang)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .accentColor(.blue)
                    }
                    
                    Button {
                        let tempLang = viewModel.sourceLanguage
                        viewModel.sourceLanguage = viewModel.targetLanguage
                        viewModel.targetLanguage = tempLang
                    } label: {
                        Image(systemName: "arrow.right.arrow.left.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .accessibilityLabel("Swap source and target languages")
                    }
                    
                    HStack {
                        Text("To:")
                           .font(.caption)
                           .foregroundColor(.secondary)
                        Picker("", selection: $viewModel.targetLanguage) {
                            ForEach(mockLanguages.filter { $0 != "auto" }, id: \.self) { lang in
                                Text(lang.uppercased()).tag(lang)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .accentColor(.blue)
                    }
                }
                .padding(.horizontal, 5)


                // Translate Button
                Button(action: {
                    Task {
                        await viewModel.translate()
                    }
                }) {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                        Text("Translate")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent) // Prominent style
                .tint(.blue) // iOS 15+ for prominent button color
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .disabled(viewModel.isLoading || viewModel.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityHint(viewModel.isLoading ? "Translation in progress" : "Tap to translate source text")

                // Loading Indicator & Error Display
                if viewModel.isLoading {
                    ProgressView("Translating...")
                        .padding(.vertical, 5)
                } else if let errorMsg = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(errorMsg)
                            .foregroundColor(.red)
                            .font(.caption)
                        Spacer()
                        Button { viewModel.errorMessage = nil } label: {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }


                // Translated Text Display
                VStack(alignment: .leading, spacing: 5) {
                    Text("Translation:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextEditor(text: .constant(viewModel.translatedText)) // Read-only
                        .frame(minHeight: 150, maxHeight: .infinity) // Expandable
                        .padding(4) // Internal padding
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(CGColor(gray: 0.92, alpha: 1.0))) // Slightly different background
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1) // Subtle border
                        )
                        .accessibilityLabel("Translated text")
                }
                
                Spacer() // Pushes content to the top

            }
            .padding() // Overall padding for the main VStack
            .navigationTitle("Ktranslate")
            // .navigationBarTitleDisplayMode(.inline) // Removed for macOS compatibility
            .toolbar {
                ToolbarItem(placement: .automatic) { // Changed for macOS compatibility
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .accessibilityLabel("Open settings")
                    }
                    .tint(.blue) // Ensure toolbar items are visible
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .onAppear {
                viewModel.updateAvailableModels(for: viewModel.selectedService)
            }
            .onChange(of: viewModel.selectedService.rawValue) { newServiceRawValue in
                if let newService = AIService(rawValue: newServiceRawValue) {
                    viewModel.updateAvailableModels(for: newService)
                }
            }
        }
        // Apply theme based on settings
        // .preferredColorScheme(viewModel.appTheme.toColorScheme()) // Assuming ViewModel manages theme
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .preferredColorScheme(.light)
        MainView()
            .preferredColorScheme(.dark)
            .environmentObject(TranslationViewModel()) // For dark mode preview with viewmodel
    }
}
