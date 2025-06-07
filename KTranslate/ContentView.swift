// Sources/KTranslate/ContentView.swift
import SwiftUI
import AVFoundation // For AVSpeechSynthesizer

struct ContentView: View {
    @StateObject private var viewModel = TranslationViewModel()
    @State private var showingSettings = false

    // Available languages for pickers (excluding "Auto Detect" for target)
    private var sourceLanguages: [Language] = supportedLanguages
    private var targetLanguages: [Language] = supportedLanguages.filter { $0.code != "auto" }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Language Selection Area
            languageSelectionHeader()
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 8)

            // MARK: - Main Text Areas
            HSplitView { // Or VStack for top/bottom layout
                sourceTextView()
                    .frame(minWidth: 300, idealWidth: 400, maxWidth: .infinity, minHeight: 200, idealHeight: 300, maxHeight: .infinity)
                translatedTextView()
                    .frame(minWidth: 300, idealWidth: 400, maxWidth: .infinity, minHeight: 200, idealHeight: 300, maxHeight: .infinity)
            }
            .padding(.horizontal)
            .padding(.bottom)

            // MARK: - Status Bar / Error Message
            statusBar()
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .frame(minWidth: 700, minHeight: 450) // Default window size
        .background(.ultraThinMaterial) // Translucent background
        .sheet(isPresented: $showingSettings) {
            // Ensure SettingsView is defined, even if as a placeholder initially
            SettingsView(isPresented: $showingSettings, onSettingsSaved: {
                viewModel.settingsDidChange()
            })
        }
    }

    // MARK: - Subviews
    @ViewBuilder
    private func languageSelectionHeader() -> some View {
        HStack {
            Picker("Source Language", selection: $viewModel.sourceLanguage) {
                ForEach(sourceLanguages) { lang in
                    Text(lang.name).tag(lang)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.swapLanguages()
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.title3) // Slightly smaller for balance
            }
            .buttonStyle(.borderless)
            .contentShape(Rectangle())
            .padding(.horizontal, 4)
            .disabled(viewModel.sourceLanguage.code == "auto" || viewModel.isLoading) // Already good

            Picker("Target Language", selection: $viewModel.targetLanguage) {
                ForEach(targetLanguages) { lang in
                    Text(lang.name).tag(lang)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)

            Spacer()

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .padding(.leading)
        }
    }

    @ViewBuilder
    private func sourceTextView() -> some View {
        VStack(alignment: .leading, spacing: 5) { // Increased spacing slightly
            Text("Source (\(viewModel.sourceLanguage.name))")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.leading, 5) // Indent header slightly

            ZStack(alignment: .topTrailing) {
                TextEditor(text: $viewModel.sourceText)
                    .font(.system(.body, design: .rounded))
                    .frame(maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)) // Smoother corners
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1.5) // Slightly thicker border
                    )
                    .disabled(viewModel.isLoading)

                if !viewModel.sourceText.isEmpty {
                    Button {
                        viewModel.clearSourceText()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.gray.opacity(0.8))
                    }
                    .buttonStyle(.plain) // Use plain for better interaction with ZStack content
                    .padding(10) // Increased padding
                    .transition(.opacity.combined(with: .scale))
                    .animation(.easeInOut(duration: 0.2), value: viewModel.sourceText.isEmpty)
                }
            }

            Text("\(viewModel.characterCount) characters")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 5)
        }
        .padding(EdgeInsets(top: 8, leading: 8, bottom: 12, trailing: 8)) // Adjusted padding
        .background(Color.primary.opacity(0.04)) // Subtle background for the text area box
        .cornerRadius(12, antialiased: true) // Larger corner radius
    }

    @ViewBuilder
    private func translatedTextView() -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Translation (\(viewModel.targetLanguage.name))")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.leading, 5)
                Spacer()
                if !viewModel.translatedText.isEmpty && !viewModel.isLoading {
                    HStack(spacing: 15) {
                        Button { viewModel.copyTranslatedTextToClipboard() } label: { Image(systemName: "doc.on.doc.fill").font(.title3) }
                            .buttonStyle(.plain)
                            .help("Copy to Clipboard")

                        Button { viewModel.speakTranslatedText() } label: { Image(systemName: "speaker.wave.2.fill").font(.title3) }
                            .buttonStyle(.plain)
                            .help("Read Aloud")
                    }
                    .padding(.trailing, 5)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3))) // Ensure tools fade in/out
                }
            }

            ZStack {
                // Translated Text Content Area
                ScrollView { // Use ScrollView for potentially long text, TextEditor is not ideal for read-only if formatting is key
                    Text(viewModel.translatedText)
                        .font(.system(.body, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)) // Padding inside the scroll view content
                        .opacity(viewModel.isLoading || viewModel.translatedText.isEmpty && viewModel.sourceText.isEmpty ? 0 : 1) // Hide when loading or truly empty
                        .animation(.easeInOut(duration: 0.4), value: viewModel.translatedText) // Animate text changes
                        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading) // Animate opacity on loading change
                }
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1.5)
                )
                .opacity(viewModel.isLoading ? 0.5 : 1.0) // Dim overall container slightly when loading

                // Loading/Placeholder Content
                if viewModel.isLoading {
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Translating...")
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    .transition(.opacity.animation(.easeInOut(duration: 0.2))) // Smooth appearance of loader
                } else if viewModel.translatedText.isEmpty && !viewModel.sourceText.isEmpty && viewModel.errorMessage == nil {
                    Text("Translation will appear here.")
                        .font(.system(.callout, design: .rounded))
                        .foregroundColor(Color.gray.opacity(0.7))
                        .transition(.opacity.animation(.easeInOut(duration: 0.3))) // Smooth appearance of placeholder
                } else if viewModel.translatedText.isEmpty && viewModel.sourceText.isEmpty && viewModel.errorMessage == nil {
                     Text("Enter text to translate.") // More specific initial placeholder
                        .font(.system(.callout, design: .rounded))
                        .foregroundColor(Color.gray.opacity(0.7))
                        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                }
            }
        }
        .padding(EdgeInsets(top: 8, leading: 8, bottom: 12, trailing: 8))
        .background(Color.primary.opacity(0.04))
        .cornerRadius(12, antialiased: true)
        // Consolidate animations for the whole block if general, or keep specific ones as above
        // .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
        // .animation(.easeInOut(duration: 0.3), value: viewModel.translatedText)
    }

    @ViewBuilder
    private func statusBar() -> some View {
        HStack {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundColor(.red)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3))) // Ensure smooth transition
            } else {
                 Text(" ") // Keep space for consistent height
                    .font(.caption)
            }
            Spacer()
            // Optional: Add a small "Saved" confirmation for settings if desired,
            // though settings view handles its own feedback.
        }
        .frame(height: 30)
        // .animation(.easeInOut, value: viewModel.errorMessage) // This might be redundant if transition is on Text
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            // For preview, you might want to create a mock TranslationViewModel
            // with some initial data to see different states.
            .environmentObject(TranslationViewModel()) // Basic preview
    }
}

// Ensure SettingsView.swift is in the same directory or correctly imported.
// If SettingsView.swift was created in Sources/KTranslate/ (not Sources/KTranslate/Views/),
// then no import change is needed. The previous step placed it in Sources/KTranslate/.
