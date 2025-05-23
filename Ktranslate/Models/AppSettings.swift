import Foundation

struct AppSettings: Codable {
    var apiHost: String = "api.openai.com"
    var apiKey: String = ""
    var selectedModel: String = "gpt-3.5-turbo"
    var selectedService: AIService = .openAI
    var theme: AppTheme = .system
}
