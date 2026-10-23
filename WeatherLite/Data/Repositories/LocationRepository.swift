import Foundation

protocol LocationRepositoryProtocol {
    var bookmarksStream: AsyncStream<[Bookmark]> { get }
    func getBookmarks() -> [Bookmark]
    func addBookmark(_ bookmark: Bookmark) async
    func removeBookmark(_ bookmark: Bookmark) async
    func isBookmarkDuplicate(state: String, city: String) async -> Bool
    func getOrFetchLocation(name: String) async -> Result<CachedLocation, any Error & Sendable>
    func getStateFromString(_ s: String) -> USState?
    func getStates() -> [USState]
    func getCities() -> [String: StateCities]
    func filterStates(query: String, availableStates: [USState]) -> [USState]
    func searchCities(stateAbbreviation: String?, query: String, defaultCities: [String]) -> [String]
    func getMajorCitiesByState(_ state: String) -> [String]
    func getAllCitiesByState(_ state: String) -> [String]
    func findNearestCity(lat: Double, lon: Double) async -> LocatedCity?
    func getCurrentLocatedCity() async throws -> LocatedCity?
}

extension LocationRepositoryProtocol {
    func filterStates(query: String) -> [USState] {
        filterStates(query: query, availableStates: getStates())
    }

    func searchCities(stateAbbreviation: String?, query: String) -> [String] {
        searchCities(stateAbbreviation: stateAbbreviation, query: query, defaultCities: [])
    }

    func getAllCitiesByState(_ state: String) -> [String] {
        getCities()[state]?.allCities ?? []
    }
}

final class LocationRepository: LocationRepositoryProtocol {
    private let bundle: Bundle
    private let localStore: LocalDatabaseStoreProtocol
    private let locationRemoteDataSource: LocationRemoteDataSourceProtocol
    private let locationProvider: LocationProviderProtocol

    private lazy var citiesData: [String: StateCities] = {
        guard let url = bundle.url(forResource: "us_state_cities", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: StateCities].self, from: data) else {
            return [:]
        }
        return decoded
    }()

    private lazy var statesData: [USState] = {
        guard let url = bundle.url(forResource: "us_state", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([USState].self, from: data) else {
            return []
        }
        return decoded
    }()

    init(
        bundle: Bundle = .main,
        localStore: LocalDatabaseStoreProtocol,
        locationRemoteDataSource: LocationRemoteDataSourceProtocol,
        locationProvider: LocationProviderProtocol
    ) {
        self.bundle = bundle
        self.localStore = localStore
        self.locationRemoteDataSource = locationRemoteDataSource
        self.locationProvider = locationProvider
    }

    var bookmarksStream: AsyncStream<[Bookmark]> {
        localStore.bookmarksStream
    }

    func getBookmarks() -> [Bookmark] {
        localStore.getAllBookmarks()
    }

    func addBookmark(_ bookmark: Bookmark) async {
        localStore.addBookmark(bookmark)
    }

    func removeBookmark(_ bookmark: Bookmark) async {
        localStore.removeBookmark(bookmark)
    }

    func isBookmarkDuplicate(state: String, city: String) async -> Bool {
        localStore.isBookmarkDuplicate(stateName: state, cityName: city)
    }

    func getOrFetchLocation(name: String) async -> Result<CachedLocation, any Error & Sendable> {
        if let cachedLocation = localStore.getCachedLocation(byName: name) {
            return .success(cachedLocation)
        }

        let remoteResult = await locationRemoteDataSource.fetchLocationCoordinates(searchQuery: name)
        switch remoteResult {
        case .success(let coordinates):
            let saved = localStore.insertCachedLocation(
                name: name,
                latitude: coordinates.0,
                longitude: coordinates.1
            )
            return .success(saved)
        case .failure(let error):
            return .failure(error)
        }
    }

    func getStateFromString(_ s: String) -> USState? {
        statesData.first { $0.name == s }
    }

    func getStates() -> [USState] {
        statesData
    }

    func getCities() -> [String: StateCities] {
        citiesData
    }

    func filterStates(query: String, availableStates: [USState]) -> [USState] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return availableStates
        }
        return availableStates.filter { state in
            state.name.localizedCaseInsensitiveContains(query)
        }
    }

    func searchCities(
        stateAbbreviation: String?,
        query: String,
        defaultCities: [String] = []
    ) -> [String] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return defaultCities
        }
        guard let abbreviation = stateAbbreviation,
              let allCities = getCities()[abbreviation]?.allCities else {
            return []
        }
        return allCities.filter { city in
            city.localizedCaseInsensitiveContains(query)
        }
    }

    func getMajorCitiesByState(_ state: String) -> [String] {
        citiesData[state]?.majorCities ?? []
    }

    func getAllCitiesByState(_ state: String) -> [String] {
        citiesData[state]?.allCities ?? []
    }

    func findNearestCity(lat: Double, lon: Double) async -> LocatedCity? {
        let results: [GeocodingResponse]
        do {
            results = try await locationRemoteDataSource.reverseGeocode(lat: lat, lon: lon)
        } catch {
            return nil
        }

        guard let best = results.first else {
            return nil
        }

        guard best.country.caseInsensitiveCompare("us") == .orderedSame,
              let stateQuery = best.state,
              let matchedState = statesData.first(where: {
                  $0.name.caseInsensitiveCompare(stateQuery) == .orderedSame ||
                      $0.abbreviation.caseInsensitiveCompare(stateQuery) == .orderedSame
              }) else {
            return nil
        }

        let cityName = citiesData[matchedState.abbreviation]?
            .allCities
            .first(where: { $0.caseInsensitiveCompare(best.name) == .orderedSame })
            ?? best.name

        return LocatedCity(
            state: matchedState,
            city: cityName,
            latitude: lat,
            longitude: lon
        )
    }

    func getCurrentLocatedCity() async throws -> LocatedCity? {
        let coordinates: LocationCoordinates?
        do {
            coordinates = try await locationProvider.getLastKnownCoordinates()
        } catch {
            return nil
        }
        guard let coordinates else {
            return nil
        }
        return await findNearestCity(lat: coordinates.latitude, lon: coordinates.longitude)
    }
}
