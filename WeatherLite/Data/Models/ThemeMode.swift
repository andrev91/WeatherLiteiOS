import Foundation

nonisolated enum ThemeMode: String, CaseIterable, Codable, Equatable, Sendable, CustomStringConvertible {
    case system = "SYSTEM"
    case light = "LIGHT"
    case dark = "DARK"

    var displayName: String {
        switch self {
        case .system:
            return "Use Device"
        case .light:
            return "Light Mode"
        case .dark:
            return "Dark Mode"
        }
    }

    var description: String {
        displayName
    }

    var darkThemeOverride: Bool? {
        switch self {
        case .system:
            return nil
        case .light:
            return false
        case .dark:
            return true
        }
    }
}
