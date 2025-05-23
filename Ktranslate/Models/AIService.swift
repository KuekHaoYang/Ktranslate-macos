import Foundation

enum AIService: String, CaseIterable, Identifiable, Codable {
    case openAI
    case gemini

    var id: String { self.rawValue }
}
