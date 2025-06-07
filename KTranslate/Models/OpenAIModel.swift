// Sources/KTranslate/Models/OpenAIModel.swift
import Foundation

// Structure for the overall list of models from OpenAI
struct OpenAIModelsResponse: Decodable {
    let data: [OpenAIModel]
}

// Structure for a single model object from OpenAI
struct OpenAIModel: Decodable, Identifiable, Hashable {
    let id: String
    // let object: String // "model"
    // let created: Int?
    // let ownedBy: String?
    // We only strictly need 'id' for the picker for now.
    // Add other properties if they become necessary.
}
