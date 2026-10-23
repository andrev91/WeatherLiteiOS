import Foundation

nonisolated enum TemperatureUnit: String, CaseIterable, Codable, Equatable, Sendable, CustomStringConvertible {
    case celsius = "CELSIUS"
    case fahrenheit = "FAHRENHEIT"

    var displayName: String {
        switch self {
        case .celsius:
            return "Celsius"
        case .fahrenheit:
            return "Fahrenheit"
        }
    }

    var description: String {
        displayName
    }
}
