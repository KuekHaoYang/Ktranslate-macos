// Sources/KTranslate/Models/GeminiModel.swift
import Foundation

// Structure for the overall list of models from Gemini
struct GeminiModelsResponse: Decodable {
    let models: [GeminiModel]
}

// Structure for a single model object from Gemini
struct GeminiModel: Decodable, Identifiable, Hashable {
    let name: String // e.g., "models/gemini-1.5-pro-latest"
    // let version: String?
    // let displayName: String?
    // We primarily need 'name' for the API calls and 'id' for the Picker.
    // Add other properties if they become necessary.

    // Computed property to extract the user-friendly ID from the full name
    var id: String {
        // Often the name is "models/model-name", we want "model-name"
        if let modelName = name.split(separator: "/").last {
            return String(modelName)
        }
        return name
    }

    // Conformance to Hashable and Equatable based on 'name'
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    static func == (lhs: GeminiModel, rhs: GeminiModel) -> Bool {
        lhs.name == rhs.name
    }
}
