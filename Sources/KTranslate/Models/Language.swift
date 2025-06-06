// Sources/KTranslate/Models/Language.swift
import Foundation

struct Language: Identifiable, Hashable, Equatable {
    let id = UUID() // To make it identifiable in lists
    let code: String // e.g., "en", "es", "fr"
    let name: String // e.g., "English", "Spanish", "French"

    static func == (lhs: Language, rhs: Language) -> Bool {
        lhs.code == rhs.code
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(code)
    }
}

// Example list of languages - this can be expanded or moved to a ViewModel/Constants file later
let supportedLanguages: [Language] = [
    Language(code: "en", name: "English"),
    Language(code: "es", name: "Spanish"),
    Language(code: "fr", name: "French"),
    Language(code: "de", name: "German"),
    Language(code: "ja", name: "Japanese"),
    Language(code: "ko", name: "Korean"),
    Language(code: "zh-CN", name: "Chinese (Simplified)"),
    Language(code: "it", name: "Italian"),
    Language(code: "pt", name: "Portuguese"),
    Language(code: "ru", name: "Russian"),
    Language(code: "ar", name: "Arabic"),
    // Add more languages as needed
    Language(code: "auto", name: "Auto Detect") // Special case for source language
]
