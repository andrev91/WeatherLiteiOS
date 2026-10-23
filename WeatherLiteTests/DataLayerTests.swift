import CoreLocation
import Foundation
import os
import Testing
@testable import WeatherLite

final class StubLocationProvider: LocationProviderProtocol {
    var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    var hasLocationPermission: Bool = true
    var coordinatesToReturn: LocationCoordinates? = LocationCoordinates(latitude: 33.749, longitude: -84.388)

    func requestWhenInUseAuthorization() async -> Bool {
        hasLocationPermission
    }

    func getLastKnownCoordinates() async throws -> LocationCoordinates? {
        coordinatesToReturn
    }
}

nonisolated final class MockURLProtocol: URLProtocol {
    private static let handlers = OSAllocatedUnfairLock(
        initialState: [String: @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)]()
    )

    static func registerHandler(
        forHost host: String,
        handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
    ) {
        handlers.withLock { $0[host] = handler }
    }

    static func unregisterHandler(forHost host: String) {
        handlers.withLock { _ = $0.removeValue(forKey: host) }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let host = request.url?.host ?? ""
        let handler = Self.handlers.withLock { $0[host] }
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@Suite("Data Layer Tests")
struct DataLayerTests {
    @Test("Static JSON assets decode correctly")
    func staticAssetsDecodeCorrectly() {
        let store = SwiftDataDatabaseStore(inMemory: true)
        let apiService = URLSessionApiService()
        let remote = LocationRemoteDataSource(apiService: apiService, apiKey: "test_key")
        let repo = LocationRepository(
            bundle: .main,
            localStore: store,
            locationRemoteDataSource: remote,
            locationProvider: StubLocationProvider()
        )

        let states = repo.getStates()
        #expect(states.count == 51)
        #expect(states.first?.name == "Alabama")
        #expect(states.first?.abbreviation == "AL")

        let nyCities = repo.getMajorCitiesByState("NY")
        #expect(nyCities.contains("New York"))

        let filteredCities = repo.searchCities(stateAbbreviation: "CA", query: "San", defaultCities: [])
        #expect(filteredCities.contains("San Francisco"))
    }

    @Test("ApiServiceHost resolves OpenWeather API key")
    func apiServiceHostResolvesOpenWeatherApiKey() throws {
        ApiServiceHost.setActive(.openWeatherMap)
        let key = try ApiServiceHost.provideApiKey()
        #expect(!key.isEmpty)
        #expect(!key.hasPrefix("$("))
    }

    @Test("WeatherRepository maps OpenWeatherResponseDTO to WeatherDataPO")
    func weatherRepositoryMapsOpenWeatherResponseToPO() {
        let dto = OpenWeatherResponseDTO(
            coord: CoordinateDTO(lon: -74.006, lat: 40.7128),
            weather: [WeatherDetailsDTO(id: 800, main: "Clear", description: "clear sky", icon: "01d")],
            base: "stations",
            main: WeatherObjectDTO(
                temp: 77.0,
                feelsLike: 76.0,
                tempMin: 70.0,
                tempMax: 80.0,
                pressure: 1012,
                humidity: 50
            ),
            visibility: 10000,
            wind: WindDTO(speed: 5.0, deg: 180),
            clouds: CloudsDTO(all: 0),
            dt: 1_700_000_000,
            sys: WeatherLocationDTO(country: "US", sunrise: 1_699_960_000, sunset: 1_700_000_000),
            timezone: -18000,
            id: 5128581,
            name: "New York",
            cod: 200
        )

        let po = WeatherRepository.mapResponseToWeatherDataPO(dto)
        #expect(po.temperatureFahrenheit == "77.0°F")
        #expect(po.temperatureCelsius == "25.00°C")
        #expect(po.weatherDescription == "clear sky")
        #expect(po.weatherIcon == "https://openweathermap.org/img/wn/01d@2x.png")
        #expect(!po.observedAt.isEmpty)
    }

    @Test("URLSessionApiService decodes response with MockURLProtocol")
    func urlSessionApiServiceWithMockURLProtocol() async throws {
        let mockHost = "mock-\(UUID().uuidString.lowercased()).openweathermap.org"
        defer { MockURLProtocol.unregisterHandler(forHost: mockHost) }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let service = URLSessionApiService(session: session) { "https://\(mockHost)/" }

        let sampleJSON = Data("""
        [
          {
            "name": "Atlanta",
            "lat": 33.7489924,
            "lon": -84.3902644,
            "country": "US",
            "state": "Georgia"
          }
        ]
        """.utf8)

        MockURLProtocol.registerHandler(forHost: mockHost) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, sampleJSON)
        }

        let results = try await service.getLocation(query: "Atlanta, Georgia", limit: 5, apiKey: "test_key")
        #expect(results.count == 1)
        #expect(results.first?.name == "Atlanta")
        #expect(results.first?.state == "Georgia")
    }

    @Test("LocationRepository uses SwiftData cache before calling network")
    func locationRepositoryCacheFirstBehavior() async throws {
        let mockHost = "mock-\(UUID().uuidString.lowercased()).openweathermap.org"
        defer { MockURLProtocol.unregisterHandler(forHost: mockHost) }

        let store = SwiftDataDatabaseStore(inMemory: true)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let service = URLSessionApiService(session: session) { "https://\(mockHost)/" }
        let remote = LocationRemoteDataSource(apiService: service, apiKey: "test_key")
        let repo = LocationRepository(
            bundle: .main,
            localStore: store,
            locationRemoteDataSource: remote,
            locationProvider: StubLocationProvider()
        )

        let networkHits = OSAllocatedUnfairLock(initialState: 0)
        MockURLProtocol.registerHandler(forHost: mockHost) { request in
            networkHits.withLock { $0 += 1 }
            let json = Data("""
            [{"name":"Atlanta","lat":33.749,"lon":-84.388,"country":"US","state":"Georgia"}]
            """.utf8)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        let first = await repo.getOrFetchLocation(name: "Atlanta, Georgia")
        #expect(networkHits.withLock { $0 } == 1)
        #expect(try first.get().latitude == 33.749)

        let second = await repo.getOrFetchLocation(name: "Atlanta, Georgia")
        #expect(networkHits.withLock { $0 } == 1)
        #expect(try second.get().longitude == -84.388)
    }

    @Test("SettingsRepository persists theme mode and emits updates")
    func settingsRepositoryThemeModePersistenceAndStream() async {
        let suiteName = "WeatherLiteTests_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let repo = SettingsRepository(userDefaults: defaults)
        #expect(repo.currentThemeMode == .system)

        await repo.setThemeMode(.dark)
        #expect(repo.currentThemeMode == .dark)
        #expect(defaults.string(forKey: SettingsRepository.themeModeKey) == "DARK")

        await repo.setThemeMode(.light)
        #expect(repo.currentThemeMode == .light)
        #expect(defaults.string(forKey: SettingsRepository.themeModeKey) == "LIGHT")
    }
}
