import CoreLocation
import Foundation

final class CoreLocationProvider: NSObject, LocationProviderProtocol, CLLocationManagerDelegate {
    private let locationManager: CLLocationManager
    private var locationContinuation: CheckedContinuation<LocationCoordinates?, Never>?
    private var locationRequestId: UUID?
    private var authContinuations: [CheckedContinuation<Bool, Never>] = []

    override init() {
        self.locationManager = CLLocationManager()
        super.init()
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        self.locationManager.delegate = self
    }

    var authorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    var hasLocationPermission: Bool {
        let status = locationManager.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    func requestWhenInUseAuthorization() async -> Bool {
        if hasLocationPermission {
            return true
        }
        let status = locationManager.authorizationStatus
        if status == .denied || status == .restricted {
            return false
        }

        return await withCheckedContinuation { continuation in
            let shouldRequest = authContinuations.isEmpty
            authContinuations.append(continuation)
            if shouldRequest {
                locationManager.requestWhenInUseAuthorization()
            }
        }
    }

    func getLastKnownCoordinates() async throws -> LocationCoordinates? {
        guard hasLocationPermission else {
            return nil
        }

        if let lastLocation = locationManager.location,
           lastLocation.horizontalAccuracy >= 0 {
            return LocationCoordinates(
                latitude: lastLocation.coordinate.latitude,
                longitude: lastLocation.coordinate.longitude
            )
        }

        let requestId = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if let existing = self.locationContinuation {
                    existing.resume(returning: nil)
                }
                self.locationContinuation = continuation
                self.locationRequestId = requestId
                self.locationManager.requestLocation()

                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(10))
                    guard let self,
                          self.locationRequestId == requestId,
                          let pending = self.locationContinuation else { return }
                    self.locationContinuation = nil
                    self.locationRequestId = nil
                    self.locationManager.stopUpdatingLocation()
                    pending.resume(returning: nil)
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard let self,
                      self.locationRequestId == requestId,
                      let pending = self.locationContinuation else { return }
                self.locationContinuation = nil
                self.locationRequestId = nil
                self.locationManager.stopUpdatingLocation()
                pending.resume(returning: nil)
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        let coord = locations.last.map {
            LocationCoordinates(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
        }
        Task { @MainActor [weak self] in
            guard let self, let continuation = self.locationContinuation else { return }
            self.locationContinuation = nil
            self.locationRequestId = nil
            continuation.resume(returning: coord)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            guard let self, let continuation = self.locationContinuation else { return }
            self.locationContinuation = nil
            self.locationRequestId = nil
            continuation.resume(returning: nil)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard status != .notDetermined else { return }
        let granted = (status == .authorizedWhenInUse || status == .authorizedAlways)
        Task { @MainActor [weak self] in
            guard let self, !self.authContinuations.isEmpty else { return }
            let pending = self.authContinuations
            self.authContinuations.removeAll()
            for continuation in pending {
                continuation.resume(returning: granted)
            }
        }
    }
}
