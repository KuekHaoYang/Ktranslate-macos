// KTranslate/ContentView.swift
import SwiftUI
import AVFoundation

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
                .padding(.bottom, 10) // Increased bottom padding for header

            HSplitView {
                sourceTextView()
                    .frame(minWidth: 300, idealWidth: 400, maxWidth: .infinity, minHeight: 200, idealHeight: 300, maxHeight: .infinity)
                translatedTextView()
                    .frame(minWidth: 300, idealWidth: 400, maxWidth: .infinity, minHeight: 200, idealHeight: 300, maxHeight: .infinity)
            }
            .padding(.horizontal)
            .padding(.bottom)
            // Add padding for separation if HSplitView itself doesn't provide enough
            // For HSplitView, the divider is usually the separator. More padding can be added to its content.

            statusBar()
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .frame(minWidth: 750, minHeight: 500) // Slightly increased default size
        .background(.ultraThinMaterial)
        .tint(Color.accentColor)
    }

    @ViewBuilder
    private func languageSelectionHeader() -> some View {
        HStack(spacing: 15) { // Consistent spacing for header items
            Picker("Source Language", selection: $viewModel.sourceLanguage) {
                ForEach(sourceLanguages) { lang in
                    Text(lang.name).tag(lang)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity) // Allow picker to take space

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.swapLanguages()
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.title2) // Made button slightly larger
            }
            .buttonStyle(.borderless)
            .contentShape(Rectangle())
            .help("Swap Languages") // Added help tooltip

            Picker("Target Language", selection: $viewModel.targetLanguage) {
                ForEach(targetLanguages) { lang in
                    Text(lang.name).tag(lang)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity) // Allow picker to take space

            // Settings button pushed to the right by pickers taking .maxWidth: .infinity
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3) // Kept settings button size
            }
            .buttonStyle(.borderless)
            .padding(.leading, 5) // Reduced padding if pickers manage space
        }
    }

    @ViewBuilder
    private func sourceTextView() -> some View {
        // Applied a more distinct background to the whole source text area container
        VStack(alignment: .leading, spacing: 8) { // Increased spacing
            Text("Source (\(viewModel.sourceLanguage.name))")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8) // Added horizontal padding to header

            ZStack(alignment: .topTrailing) {
                TextEditor(text: $viewModel.sourceText)
                    .font(.system(.body, design: .rounded))
                    .frame(maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous)) // Slightly reduced corner radius
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1) // Thinner border
                    )
                    .padding(1) // Padding to ensure border is fully visible if text editor has its own background
                    .disabled(viewModel.isLoading)

                if !viewModel.sourceText.isEmpty {
                    Button { viewModel.clearSourceText() } label: {
                        Image(systemName: "xmark.circle.fill").font(.title3)
                    }
                    .buttonStyle(.plain)
                    .padding(8) // Adjusted padding
                    .transition(.opacity.combined(with: .scale))
                    .animation(.easeInOut(duration: 0.2), value: viewModel.sourceText.isEmpty)
                }
            }

            Text("\(viewModel.characterCount) characters")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 8) // Added horizontal padding
        }
        .padding(12) // Overall padding for the container
        .background( // More distinct background for the source area
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.05)) // Slightly more opaque or different color
        )
        .padding(3) // Padding around the entire source box, creates separation
    }

    @ViewBuilder
    private func translatedTextView() -> some View {
        VStack(alignment: .leading, spacing: 8) { // Increased spacing
            HStack {
                Text("Translation (\(viewModel.targetLanguage.name))")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8) // Added horizontal padding
                Spacer()
                if !viewModel.translatedText.isEmpty && !viewModel.isLoading {
                    HStack(spacing: 15) {
                        Button { viewModel.copyTranslatedTextToClipboard() } label: { Image(systemName: "doc.on.doc.fill").font(.title3) }
                            .buttonStyle(.plain).help("Copy to Clipboard")
                        Button { viewModel.speakTranslatedText() } label: { Image(systemName: "speaker.wave.2.fill").font(.title3) }
                            .buttonStyle(.plain).help("Read Aloud")
                    }
                    .padding(.trailing, 8) // Added horizontal padding
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                }
            }

            ZStack {
                ScrollView {
                    Text(viewModel.translatedText)
                        .font(.system(.body, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                        .opacity(viewModel.isLoading || (viewModel.translatedText.isEmpty && viewModel.sourceText.isEmpty) ? 0 : 1)
                        .animation(.easeInOut(duration: 0.4), value: viewModel.translatedText)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
                }
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(1)
                .opacity(viewModel.isLoading ? 0.5 : 1.0)

                if viewModel.isLoading { /* ... (loading indicator unchanged) ... */
                    VStack(spacing: 8) {
                        ProgressView().scaleEffect(1.2)
                        Text("Translating...")
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                } else if viewModel.translatedText.isEmpty && !viewModel.sourceText.isEmpty && viewModel.errorMessage == nil {
                    Text("Translation will appear here.").font(.system(.callout, design: .rounded)).foregroundColor(Color.gray.opacity(0.7)).transition(.opacity.animation(.easeInOut(duration: 0.3)))
                } else if viewModel.translatedText.isEmpty && viewModel.sourceText.isEmpty && viewModel.errorMessage == nil {
                     Text("Enter text to translate.").font(.system(.callout, design: .rounded)).foregroundColor(Color.gray.opacity(0.7)).transition(.opacity.animation(.easeInOut(duration: 0.3)))
                }
            }
        }
        .padding(12) // Overall padding for the container
        .background( // More distinct background for the translated area
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.05)) // Consistent with source area, or could be slightly different
        )
        .padding(3) // Padding around the entire translated box, creates separation
    }

    @ViewBuilder
    private func statusBar() -> some View { /* ... (status bar unchanged) ... */
        HStack {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).font(.system(.caption, design: .rounded).weight(.medium)).foregroundColor(.red).lineLimit(2).truncationMode(.tail).transition(.opacity.animation(.easeInOut(duration: 0.3)))
            } else {
                 Text(" ").font(.caption)
            }
            Spacer()
        }
        .frame(height: 30)
    }
}

// Preview remains the same
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(TranslationViewModel())
    }
}
