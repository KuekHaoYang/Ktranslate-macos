// KTranslate/ContentView.swift
import SwiftUI
import AVFoundation // For AVSpeechSynthesizer

struct ContentView: View {
    @StateObject private var viewModel = TranslationViewModel()
    @State private var showingSettings = false

    private var sourceLanguages: [Language] = supportedLanguages
    private var targetLanguages: [Language] = supportedLanguages.filter { $0.code != "auto" }

    var body: some View {
        VStack(spacing: 0) {
            languageSelectionHeader()
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 8)

            HSplitView {
                sourceTextView()
                    .frame(minWidth: 300, idealWidth: 400, maxWidth: .infinity, minHeight: 200, idealHeight: 300, maxHeight: .infinity)
                translatedTextView()
                    .frame(minWidth: 300, idealWidth: 400, maxWidth: .infinity, minHeight: 200, idealHeight: 300, maxHeight: .infinity)
            }
            .padding(.horizontal)
            .padding(.bottom)

            statusBar()
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .frame(minWidth: 700, minHeight: 450)
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showingSettings) {
            SettingsView(isPresented: $showingSettings, onSettingsSaved: {
                viewModel.settingsDidChange()
            })
        }
        // Apply a default tint to the whole view, which often propagates to buttons.
        // Individual buttons can override this if needed.
        .tint(Color.accentColor)
    }

    @ViewBuilder
    private func languageSelectionHeader() -> some View {
        HStack {
            // Group for pickers and swap button to help with centering
            HStack(spacing: 12) { // Added spacing for better visual separation
                Picker("Source Language", selection: $viewModel.sourceLanguage) {
                    ForEach(sourceLanguages) { lang in
                        Text(lang.name).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 120, idealWidth: 150, maxWidth: 200) // More controlled flexible width

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.swapLanguages()
                    }
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.title3)
                }
                .buttonStyle(.borderless) // Using borderless for icon buttons
                .contentShape(Rectangle())
                // .foregroundColor(Color.accentColor) // Tint applied at root should cover this if it's a primary action

                Picker("Target Language", selection: $viewModel.targetLanguage) {
                    ForEach(targetLanguages) { lang in
                        Text(lang.name).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 120, idealWidth: 150, maxWidth: 200) // More controlled flexible width
            }
            .frame(maxWidth: .infinity) // Allow this group to take available space to center

            Spacer() // Pushes settings button to the right

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            // .foregroundColor(Color.accentColor) // Tint applied at root
            .padding(.leading)
        }
    }

    @ViewBuilder
    private func sourceTextView() -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Source (\(viewModel.sourceLanguage.name))")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.leading, 5)

            ZStack(alignment: .topTrailing) {
                TextEditor(text: $viewModel.sourceText)
                    .font(.system(.body, design: .rounded))
                    .frame(maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1.5)
                    )
                    .disabled(viewModel.isLoading)

                if !viewModel.sourceText.isEmpty {
                    Button {
                        viewModel.clearSourceText()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            // .foregroundColor(Color.gray.opacity(0.8)) // Default tint will apply
                    }
                    .buttonStyle(.plain)
                    .padding(10)
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
        .padding(EdgeInsets(top: 8, leading: 8, bottom: 12, trailing: 8))
        .background(Color.primary.opacity(0.04))
        .cornerRadius(12, antialiased: true)
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
                            // .foregroundColor(Color.accentColor) // Tint applied at root

                        Button { viewModel.speakTranslatedText() } label: { Image(systemName: "speaker.wave.2.fill").font(.title3) }
                            .buttonStyle(.plain)
                            .help("Read Aloud")
                            // .foregroundColor(Color.accentColor) // Tint applied at root
                    }
                    .padding(.trailing, 5)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                }
            }

            ZStack {
                ScrollView {
                    Text(viewModel.translatedText)
                        .font(.system(.body, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                        .opacity(viewModel.isLoading || viewModel.translatedText.isEmpty && viewModel.sourceText.isEmpty ? 0 : 1)
                        .animation(.easeInOut(duration: 0.4), value: viewModel.translatedText)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
                }
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1.5)
                )
                .opacity(viewModel.isLoading ? 0.5 : 1.0)

                if viewModel.isLoading {
                    VStack(spacing: 8) {
                        ProgressView().scaleEffect(1.2)
                        Text("Translating...")
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                } else if viewModel.translatedText.isEmpty && !viewModel.sourceText.isEmpty && viewModel.errorMessage == nil {
                    Text("Translation will appear here.")
                        .font(.system(.callout, design: .rounded))
                        .foregroundColor(Color.gray.opacity(0.7))
                        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                } else if viewModel.translatedText.isEmpty && viewModel.sourceText.isEmpty && viewModel.errorMessage == nil {
                     Text("Enter text to translate.")
                        .font(.system(.callout, design: .rounded))
                        .foregroundColor(Color.gray.opacity(0.7))
                        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                }
            }
        }
        .padding(EdgeInsets(top: 8, leading: 8, bottom: 12, trailing: 8))
        .background(Color.primary.opacity(0.04))
        .cornerRadius(12, antialiased: true)
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
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            } else {
                 Text(" ")
                    .font(.caption)
            }
            Spacer()
        }
        .frame(height: 30)
    }
}

// Preview remains the same
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(TranslationViewModel())
    }
}
