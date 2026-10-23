import Foundation

nonisolated struct USState: Codable, Equatable, Hashable, Sendable {
    let name: String
    let abbreviation: String

    enum CodingKeys: String, CodingKey {
        case name
        case abbreviation = "code"
    }
}
