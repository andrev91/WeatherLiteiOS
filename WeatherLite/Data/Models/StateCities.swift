import Foundation

nonisolated struct StateCities: Codable, Equatable, Sendable {
    let majorCities: [String]
    let allCities: [String]

    init(majorCities: [String] = [], allCities: [String] = []) {
        self.majorCities = majorCities
        self.allCities = allCities
    }

    enum CodingKeys: String, CodingKey {
        case majorCities = "major_cities"
        case allCities = "all_cities"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.majorCities = try container.decodeIfPresent([String].self, forKey: .majorCities) ?? []
        self.allCities = try container.decodeIfPresent([String].self, forKey: .allCities) ?? []
    }
}
