import Foundation

nonisolated struct LocatedCity: Equatable, Sendable {
    let state: USState
    let city: String
    let latitude: Double?
    let longitude: Double?

    init(
        state: USState,
        city: String,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.state = state
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
    }
}
