import Foundation
import OSLog

protocol ApiServiceProtocol {
    func getWeather(
        lat: Double,
        lon: Double,
        apiKey: String,
        units: String
    ) async throws -> OpenWeatherResponseDTO

    func getLocation(
        query: String,
        limit: Int,
        apiKey: String
    ) async throws -> [GeocodingResponse]

    func reverseGeocode(
        lat: Double,
        lon: Double,
        limit: Int,
        apiKey: String
    ) async throws -> [GeocodingResponse]
}

extension ApiServiceProtocol {
    func getWeather(
        lat: Double,
        lon: Double,
        apiKey: String,
        units: String = "imperial"
    ) async throws -> OpenWeatherResponseDTO {
        try await getWeather(lat: lat, lon: lon, apiKey: apiKey, units: units)
    }

    func getLocation(
        query: String,
        limit: Int = 5,
        apiKey: String
    ) async throws -> [GeocodingResponse] {
        try await getLocation(query: query, limit: limit, apiKey: apiKey)
    }

    func reverseGeocode(
        lat: Double,
        lon: Double,
        limit: Int = 1,
        apiKey: String
    ) async throws -> [GeocodingResponse] {
        try await reverseGeocode(lat: lat, lon: lon, limit: limit, apiKey: apiKey)
    }
}

final class URLSessionApiService: ApiServiceProtocol {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.tehuberz.WeatherLite",
        category: "URLSessionApiService"
    )

    private let session: URLSession
    private let baseURLProvider: () -> String
    private let decoder: JSONDecoder

    init(
        session: URLSession = .shared,
        baseURLProvider: @escaping () -> String = { ApiServiceHost.getActive().baseUrl }
    ) {
        self.session = session
        self.baseURLProvider = baseURLProvider
        self.decoder = JSONDecoder()
    }

    func getWeather(
        lat: Double,
        lon: Double,
        apiKey: String,
        units: String = "imperial"
    ) async throws -> OpenWeatherResponseDTO {
        let queryItems = [
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lon", value: String(lon)),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: units)
        ]
        return try await performRequest(path: "data/2.5/weather", queryItems: queryItems)
    }

    func getLocation(
        query: String,
        limit: Int = 5,
        apiKey: String
    ) async throws -> [GeocodingResponse] {
        let queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "appid", value: apiKey)
        ]
        return try await performRequest(path: "geo/1.0/direct", queryItems: queryItems)
    }

    func reverseGeocode(
        lat: Double,
        lon: Double,
        limit: Int = 1,
        apiKey: String
    ) async throws -> [GeocodingResponse] {
        let queryItems = [
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lon", value: String(lon)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "appid", value: apiKey)
        ]
        return try await performRequest(path: "geo/1.0/reverse", queryItems: queryItems)
    }

    private func performRequest<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem]
    ) async throws -> T {
        let baseString = baseURLProvider()
        guard var components = URLComponents(string: baseString) else {
            throw ApiServiceError.invalidURL(baseString)
        }
        let cleanBasePath = components.path.hasSuffix("/") ? components.path : components.path + "/"
        let cleanSubPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        components.path = cleanBasePath + cleanSubPath
        components.queryItems = queryItems

        guard let url = components.url else {
            throw ApiServiceError.invalidURL(baseString + path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        Self.logger.debug("--> GET \(url.path, privacy: .public)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiServiceError.emptyResponse
        }

        Self.logger.debug("<-- \(httpResponse.statusCode) (\(data.count) bytes)")

        guard (200...299).contains(httpResponse.statusCode) else {
            let statusMessage = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw ApiServiceError.httpError(code: httpResponse.statusCode, message: statusMessage)
        }

        guard !data.isEmpty else {
            throw ApiServiceError.emptyResponse
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            Self.logger.error("Decoding error: \(error.localizedDescription, privacy: .public)")
            throw ApiServiceError.decodingFailed(error.localizedDescription)
        }
    }
}
