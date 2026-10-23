import Foundation

nonisolated struct GeocodingResponse: Codable, Equatable, Sendable {
    let name: String
    let localNames: [String: String]?
    let lat: Double
    let lon: Double
    let country: String
    let state: String?

    init(
        name: String,
        localNames: [String: String]? = nil,
        lat: Double,
        lon: Double,
        country: String,
        state: String? = nil
    ) {
        self.name = name
        self.localNames = localNames
        self.lat = lat
        self.lon = lon
        self.country = country
        self.state = state
    }

    enum CodingKeys: String, CodingKey {
        case name
        case localNames = "local_names"
        case lat
        case lon
        case country
        case state
    }
}
