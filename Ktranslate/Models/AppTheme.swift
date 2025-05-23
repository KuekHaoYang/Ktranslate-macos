import Foundation

public enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case light
    case dark
    case system

    public var id: String { self.rawValue }
}
