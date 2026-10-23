import Foundation

protocol LocationRemoteDataSourceProtocol {
    func fetchLocationCoordinates(searchQuery: String) async -> Result<(Double, Double), any Error & Sendable>
    func reverseGeocode(lat: Double, lon: Double) async throws -> [GeocodingResponse]
}

final class LocationRemoteDataSource: LocationRemoteDataSourceProtocol {
    private let apiService: ApiServiceProtocol
    private let apiKey: String

    init(apiService: ApiServiceProtocol, apiKey: String) {
        self.apiService = apiService
        self.apiKey = apiKey
    }

    func fetchLocationCoordinates(searchQuery: String) async -> Result<(Double, Double), any Error & Sendable> {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return .failure(ApiServiceError.custom("No input data provided"))
        }

        do {
            try Task.checkCancellation()
            var locations = try await apiService.getLocation(
                query: trimmedQuery,
                limit: 5,
                apiKey: apiKey
            )
            try Task.checkCancellation()

            if locations.isEmpty,
               trimmedQuery.contains(","),
               !trimmedQuery.uppercased().hasSuffix(", US"),
               !trimmedQuery.uppercased().hasSuffix(",US") {
                locations = try await apiService.getLocation(
                    query: "\(trimmedQuery), US",
                    limit: 5,
                    apiKey: apiKey
                )
                try Task.checkCancellation()
            }

            guard let first = locations.first else {
                return .failure(ApiServiceError.custom("No location found for query: \(searchQuery)"))
            }
            guard !first.lat.isNaN && !first.lon.isNaN else {
                return .failure(ApiServiceError.custom("Invalid coordinates from SearchWorker"))
            }
            return .success((first.lat, first.lon))
        } catch is CancellationError {
            return .failure(CancellationError())
        } catch let apiError as ApiServiceError {
            return .failure(apiError)
        } catch {
            return .failure(ApiServiceError.custom("Unexpected error: \(error.localizedDescription)"))
        }
    }

    func reverseGeocode(lat: Double, lon: Double) async throws -> [GeocodingResponse] {
        try await apiService.reverseGeocode(lat: lat, lon: lon, limit: 1, apiKey: apiKey)
    }
}
