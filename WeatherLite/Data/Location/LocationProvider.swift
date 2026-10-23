import CoreLocation
import Foundation

nonisolated struct LocationCoordinates: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
}

protocol LocationProviderProtocol {
    var authorizationStatus: CLAuthorizationStatus { get }
    var hasLocationPermission: Bool { get }
    func requestWhenInUseAuthorization() async -> Bool
    func getLastKnownCoordinates() async throws -> LocationCoordinates?
}
