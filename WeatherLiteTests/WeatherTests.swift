import CoreLocation
import Foundation
import Testing
@testable import WeatherLite

final class MockWeatherRepository: WeatherRepositoryProtocol {
    var requestedCoordinates: [(Double, Double)] = []
    var weatherToReturn: WeatherDataPO = WeatherDataPO(
        temperatureFahrenheit: "72.0°F",
        temperatureCelsius: "22.22°C",
        weatherDescription: "clear sky",
        weatherIcon: "https://openweathermap.org/img/wn/01d@2x.png",
        observedAt: "12:00 PM"
    )
    var errorToThrow: Error? = nil

    func fetchWeather(lat: Double, lon: Double) async throws -> WeatherDataPO {
        requestedCoordinates.append((lat, lon))
        if let errorToThrow {
            throw errorToThrow
        }
        return weatherToReturn
    }
}

final class MockLocationRepository: LocationRepositoryProtocol {
    var bookmarks: [Bookmark] = []
    var states: [USState] = []
    var citiesByState: [String: StateCities] = [:]
    var majorCitiesByState: [String: [String]] = [:]
    var getOrFetchLocationResult: Result<CachedLocation, any Error & Sendable> = .failure(ApiServiceError.custom("Not configured"))
    var getOrFetchLocationCallCount = 0
    var currentLocatedCity: LocatedCity? = nil
    var shouldThrowOnCurrentLocation = false
    var duplicateCheckResult = false

    private var bookmarkContinuations: [UUID: AsyncStream<[Bookmark]>.Continuation] = [:]

    var bookmarksStream: AsyncStream<[Bookmark]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [Bookmark].self)
        let id = UUID()
        bookmarkContinuations[id] = continuation
        continuation.yield(bookmarks)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.bookmarkContinuations.removeValue(forKey: id)
            }
        }
        return stream
    }

    func getBookmarks() -> [Bookmark] {
        bookmarks
    }

    func addBookmark(_ bookmark: Bookmark) async {
        bookmarks.append(bookmark)
        for continuation in bookmarkContinuations.values {
            continuation.yield(bookmarks)
        }
    }

    func removeBookmark(_ bookmark: Bookmark) async {
        bookmarks.removeAll { $0.stateName == bookmark.stateName && $0.cityName == bookmark.cityName }
        for continuation in bookmarkContinuations.values {
            continuation.yield(bookmarks)
        }
    }

    func isBookmarkDuplicate(state: String, city: String) async -> Bool {
        duplicateCheckResult || bookmarks.contains { $0.stateName == state && $0.cityName == city }
    }

    func getOrFetchLocation(name: String) async -> Result<CachedLocation, any Error & Sendable> {
        getOrFetchLocationCallCount += 1
        return getOrFetchLocationResult
    }

    func getStateFromString(_ s: String) -> USState? {
        states.first { $0.name == s }
    }

    func getStates() -> [USState] {
        states
    }

    func getCities() -> [String: StateCities] {
        citiesByState
    }

    func filterStates(query: String, availableStates: [USState]) -> [USState] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return availableStates
        }
        return availableStates.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    func searchCities(stateAbbreviation: String?, query: String, defaultCities: [String]) -> [String] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return defaultCities
        }
        guard let abbr = stateAbbreviation, let allCities = citiesByState[abbr]?.allCities else {
            return []
        }
        return allCities.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    func getMajorCitiesByState(_ state: String) -> [String] {
        majorCitiesByState[state] ?? []
    }

    func findNearestCity(lat: Double, lon: Double) async -> LocatedCity? {
        currentLocatedCity
    }

    func getCurrentLocatedCity() async throws -> LocatedCity? {
        if shouldThrowOnCurrentLocation {
            throw NSError(domain: "LocationError", code: -1, userInfo: [NSLocalizedDescriptionKey: "GPS error"])
        }
        return currentLocatedCity
    }
}

final class MockSettingsRepository: SettingsRepositoryProtocol {
    var currentTemperatureUnit: TemperatureUnit = .celsius
    var currentThemeMode: ThemeMode = .system
    var currentLocationPermissionRequested: Bool = false
    var setTemperatureUnitCalls: [TemperatureUnit] = []
    var setThemeModeCalls: [ThemeMode] = []
    var setLocationPermissionRequestedCalls: [Bool] = []

    private var unitContinuations: [UUID: AsyncStream<TemperatureUnit>.Continuation] = [:]
    private var themeContinuations: [UUID: AsyncStream<ThemeMode>.Continuation] = [:]
    private var permissionContinuations: [UUID: AsyncStream<Bool>.Continuation] = [:]

    var temperatureUnitStream: AsyncStream<TemperatureUnit> {
        let (stream, continuation) = AsyncStream.makeStream(of: TemperatureUnit.self)
        let id = UUID()
        unitContinuations[id] = continuation
        continuation.yield(currentTemperatureUnit)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.unitContinuations.removeValue(forKey: id)
            }
        }
        return stream
    }

    func setTemperatureUnit(_ unit: TemperatureUnit) async {
        currentTemperatureUnit = unit
        setTemperatureUnitCalls.append(unit)
        for continuation in unitContinuations.values {
            continuation.yield(unit)
        }
        for _ in 0..<5 {
            await Task.yield()
        }
    }

    var themeModeStream: AsyncStream<ThemeMode> {
        let (stream, continuation) = AsyncStream.makeStream(of: ThemeMode.self)
        let id = UUID()
        themeContinuations[id] = continuation
        continuation.yield(currentThemeMode)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.themeContinuations.removeValue(forKey: id)
            }
        }
        return stream
    }

    func setThemeMode(_ mode: ThemeMode) async {
        currentThemeMode = mode
        setThemeModeCalls.append(mode)
        for continuation in themeContinuations.values {
            continuation.yield(mode)
        }
        for _ in 0..<5 {
            await Task.yield()
        }
    }

    var locationPermissionRequestedStream: AsyncStream<Bool> {
        let (stream, continuation) = AsyncStream.makeStream(of: Bool.self)
        let id = UUID()
        permissionContinuations[id] = continuation
        continuation.yield(currentLocationPermissionRequested)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.permissionContinuations.removeValue(forKey: id)
            }
        }
        return stream
    }

    func setLocationPermissionRequested(_ requested: Bool) async {
        currentLocationPermissionRequested = requested
        setLocationPermissionRequestedCalls.append(requested)
        for continuation in permissionContinuations.values {
            continuation.yield(requested)
        }
        for _ in 0..<5 {
            await Task.yield()
        }
    }
}

@Suite("WeatherViewModel Tests")
struct WeatherTests {
    private let mockWeatherRepository: MockWeatherRepository
    private let mockLocationRepository: MockLocationRepository
    private let mockSettingsRepository: MockSettingsRepository
    private let viewModel: WeatherViewModel

    init() {
        mockWeatherRepository = MockWeatherRepository()
        mockLocationRepository = MockLocationRepository()
        mockSettingsRepository = MockSettingsRepository()
        viewModel = WeatherViewModel(
            weatherRepository: mockWeatherRepository,
            locationRepository: mockLocationRepository,
            settingsRepository: mockSettingsRepository
        )
    }

    @Test("Initial state of ViewModel and fetching locations")
    func initStateOfViewModelAndFetchingLocations() {
        let initialState = viewModel.uiState
        #expect(!initialState.weatherState.isLoadingWeather)
        #expect(!initialState.locationState.isLoadingCities)
        #expect(!initialState.locationState.isLoadingStates)
        #expect(initialState.weatherState.weatherContent == nil)
        #expect(initialState.locationState.selectedState == nil)
        #expect(initialState.locationState.selectedCity == nil)
        #expect(initialState.error == nil)
        #expect(initialState.permissionRequestState == .none)
    }

    @Test("Search location success fetches weather")
    func searchLocationSuccessFetchesWeather() async {
        let mockLocation = CachedLocation(name: "New York City, New York", latitude: 40.7128, longitude: -74.0060)
        let mockState = USState(name: "New York", abbreviation: "NY")

        mockLocationRepository.states = [mockState]
        mockLocationRepository.majorCitiesByState = ["NY": ["New York City"]]
        mockLocationRepository.getOrFetchLocationResult = .success(mockLocation)

        viewModel.setDropdownSelection(.state, location: "New York")
        viewModel.setDropdownSelection(.city, location: "New York City")
        await viewModel.searchLocation()

        #expect(mockWeatherRepository.requestedCoordinates.count == 1)
        #expect(mockWeatherRepository.requestedCoordinates.first?.0 == 40.7128)
        #expect(mockWeatherRepository.requestedCoordinates.first?.1 == -74.0060)
    }

    @Test("Search city list filters cities correctly")
    func searchCityListFiltersCitiesCorrectly() {
        let cityList = ["San Francisco", "San Jose", "Los Angeles"]
        let stateCities = StateCities(majorCities: [], allCities: cityList)
        let mockState = USState(name: "California", abbreviation: "CA")

        mockLocationRepository.states = [mockState]
        mockLocationRepository.citiesByState = ["CA": stateCities]
        mockLocationRepository.majorCitiesByState = ["CA": []]

        viewModel.setDropdownSelection(.state, location: "California")
        viewModel.searchDropdownList(.city, query: "San")

        let filtered = viewModel.uiState.locationState.filteredCities
        #expect(filtered.contains("San Francisco"))
        #expect(filtered.contains("San Jose"))
        #expect(!filtered.contains("Los Angeles"))
    }

    @Test("Request weather for current location resolves coordinates to nearest city and fetches weather")
    func requestWeatherForCurrentLocationResolvesCoordinatesToNearestCityAndFetchesWeather() async {
        let mockLocation = CachedLocation(name: "New York City, New York", latitude: 40.7128, longitude: -74.0060)
        let nyState = USState(name: "New York", abbreviation: "NY")
        let locatedCity = LocatedCity(state: nyState, city: "New York City")

        mockLocationRepository.currentLocatedCity = locatedCity
        mockLocationRepository.states = [nyState]
        mockLocationRepository.majorCitiesByState = ["NY": ["New York City"]]
        mockLocationRepository.getOrFetchLocationResult = .success(mockLocation)

        await viewModel.requestWeatherForCurrentLocation()

        let state = viewModel.uiState.locationState
        #expect(state.selectedState?.name == "New York")
        #expect(state.selectedCity == "New York City")
        #expect(mockWeatherRepository.requestedCoordinates.first?.0 == 40.7128)
    }

    @Test("Request weather for current location with resolved coordinates directly fetches weather without geocoding")
    func requestWeatherForCurrentLocationWithResolvedCoordinatesDirectlyFetchesWeatherWithoutGeocoding() async {
        let nyState = USState(name: "New York", abbreviation: "NY")
        let locatedCity = LocatedCity(
            state: nyState,
            city: "New York City",
            latitude: 40.7128,
            longitude: -74.0060
        )

        mockLocationRepository.currentLocatedCity = locatedCity
        mockLocationRepository.majorCitiesByState = ["NY": ["New York City"]]

        await viewModel.requestWeatherForCurrentLocation()

        let state = viewModel.uiState.locationState
        #expect(state.selectedState?.name == "New York")
        #expect(state.selectedCity == "New York City")
        #expect(!state.isLoadingCities)

        #expect(mockLocationRepository.getOrFetchLocationCallCount == 0)
        #expect(mockWeatherRepository.requestedCoordinates.first?.0 == 40.7128)
        #expect(mockWeatherRepository.requestedCoordinates.first?.1 == -74.0060)
    }

    @Test("Request weather for current location surfaces error when no fix available")
    func requestWeatherForCurrentLocationSurfacesErrorWhenNoFixAvailable() async {
        mockLocationRepository.currentLocatedCity = nil

        await viewModel.requestWeatherForCurrentLocation()

        let state = viewModel.uiState
        #expect(!state.isResolvingCurrentLocation)
        #expect(state.error != nil)
    }

    @Test("Request weather for current location handles repository exception gracefully")
    func requestWeatherForCurrentLocationHandlesRepositoryExceptionGracefully() async {
        mockLocationRepository.shouldThrowOnCurrentLocation = true

        await viewModel.requestWeatherForCurrentLocation()

        let state = viewModel.uiState
        #expect(!state.isResolvingCurrentLocation)
        #expect(state.error != nil)
    }

    @Test("Use current location when permission already granted resolves weather")
    func onUseCurrentLocationClickedWhenPermissionAlreadyGrantedResolvesWeather() async {
        let locatedCity = LocatedCity(
            state: USState(name: "New York", abbreviation: "NY"),
            city: "New York City",
            latitude: 40.7128,
            longitude: -74.0060
        )
        mockLocationRepository.currentLocatedCity = locatedCity
        mockLocationRepository.majorCitiesByState = ["NY": ["New York City"]]

        await viewModel.onUseCurrentLocationClicked(authorizationStatus: .authorizedWhenInUse)

        let state = viewModel.uiState
        #expect(state.locationState.selectedState?.name == "New York")
        #expect(state.locationState.selectedCity == "New York City")
        #expect(!state.isResolvingCurrentLocation)
        #expect(state.permissionRequestState == .none)
    }

    @Test("Use current location when permission not determined shows explanation dialog")
    func onUseCurrentLocationClickedWhenPermissionNotDeterminedShowsDialog() async {
        await viewModel.onUseCurrentLocationClicked(authorizationStatus: .notDetermined)
        #expect(viewModel.uiState.permissionRequestState == .explanation)
    }

    @Test("Use current location when permission permanently denied shows settings dialog")
    func onUseCurrentLocationClickedWhenPermissionPermanentlyDeniedShowsSettingsDialog() async {
        mockSettingsRepository.currentLocationPermissionRequested = true
        let localViewModel = WeatherViewModel(
            weatherRepository: mockWeatherRepository,
            locationRepository: mockLocationRepository,
            settingsRepository: mockSettingsRepository
        )

        await localViewModel.onUseCurrentLocationClicked(authorizationStatus: .denied)
        #expect(localViewModel.uiState.permissionRequestState == .settings)
    }

    @Test("Use current location when permission not determined after prior request still shows explanation dialog")
    func onUseCurrentLocationClickedWhenPermissionDeniedWithRationaleShowsExplanationDialog() async {
        mockSettingsRepository.currentLocationPermissionRequested = true
        let localViewModel = WeatherViewModel(
            weatherRepository: mockWeatherRepository,
            locationRepository: mockLocationRepository,
            settingsRepository: mockSettingsRepository
        )

        await localViewModel.onUseCurrentLocationClicked(hasPermission: false, shouldShowRationale: true)
        #expect(localViewModel.uiState.permissionRequestState == .explanation)
    }

    @Test("Accept location explanation saves preference and emits permission prompt")
    func acceptLocationExplanationSavesPreferenceAndEmitsPermissionPrompt() async {
        let stream = viewModel.permissionPromptStream
        var iterator = stream.makeAsyncIterator()

        await viewModel.acceptLocationExplanation()
        let promptEvent: Void? = await iterator.next()

        #expect(promptEvent != nil)
        #expect(mockSettingsRepository.setLocationPermissionRequestedCalls == [true])
        #expect(viewModel.uiState.permissionRequestState == .none)
    }

    @Test("Dismiss location explanation hides dialog without saving or prompting")
    func dismissLocationExplanationHidesDialogWithoutSavingOrPrompting() async {
        await viewModel.onUseCurrentLocationClicked(authorizationStatus: .notDetermined)
        #expect(viewModel.uiState.permissionRequestState == .explanation)

        viewModel.denyLocationExplanation()
        #expect(viewModel.uiState.permissionRequestState == .none)
        #expect(mockSettingsRepository.setLocationPermissionRequestedCalls.isEmpty)
    }

    @Test("Dismiss location settings dialog hides settings dialog")
    func dismissLocationSettingsDialogHidesSettingsDialog() async {
        await viewModel.onPermissionResult(authorizationStatus: .denied)
        #expect(viewModel.uiState.permissionRequestState == .settings)

        viewModel.dismissLocationSettingsDialog()
        #expect(viewModel.uiState.permissionRequestState == .none)
    }

    @Test("Permission result when granted resolves weather")
    func onPermissionResultWhenGrantedResolvesWeather() async {
        let locatedCity = LocatedCity(
            state: USState(name: "New York", abbreviation: "NY"),
            city: "New York City",
            latitude: 40.7128,
            longitude: -74.0060
        )
        mockLocationRepository.currentLocatedCity = locatedCity
        mockLocationRepository.majorCitiesByState = ["NY": ["New York City"]]

        await viewModel.onPermissionResult(authorizationStatus: .authorizedWhenInUse)

        let state = viewModel.uiState
        #expect(state.locationState.selectedState?.name == "New York")
        #expect(state.locationState.selectedCity == "New York City")
        #expect(!state.isResolvingCurrentLocation)
    }

    @Test("Permission result when denied with rationale surfaces error without showing settings dialog")
    func onPermissionResultWhenDeniedWithRationaleSurfacesErrorWithoutShowingSettingsDialog() async {
        await viewModel.onPermissionResult(granted: false, shouldShowRationale: true)

        let state = viewModel.uiState
        #expect(!state.isResolvingCurrentLocation)
        #expect(state.error == "Location permission is required to determine your current location.")
        #expect(state.permissionRequestState == .none)
        #expect(mockSettingsRepository.setLocationPermissionRequestedCalls == [true])
    }

    @Test("Permission result when permanently denied surfaces error and shows settings dialog")
    func onPermissionResultWhenPermanentlyDeniedSurfacesErrorAndShowsSettingsDialog() async {
        await viewModel.onPermissionResult(authorizationStatus: .denied)

        let state = viewModel.uiState
        #expect(!state.isResolvingCurrentLocation)
        #expect(state.error == "Location permission is required to determine your current location.")
        #expect(state.permissionRequestState == .settings)
        #expect(mockSettingsRepository.setLocationPermissionRequestedCalls == [true])
    }

    @Test("Request weather for current location when at different location updates location and resets weather content")
    func requestWeatherForCurrentLocationWhenAtDifferentLocationUpdatesLocationAndResetsWeatherContent() async {
        let nyState = USState(name: "New York", abbreviation: "NY")
        let caState = USState(name: "California", abbreviation: "CA")

        mockLocationRepository.states = [caState, nyState]
        mockLocationRepository.majorCitiesByState = [
            "CA": ["Los Angeles"],
            "NY": ["New York City"]
        ]

        viewModel.setDropdownSelection(.state, location: "California")
        viewModel.setDropdownSelection(.city, location: "Los Angeles")

        let locatedCity = LocatedCity(
            state: nyState,
            city: "New York City",
            latitude: 40.7128,
            longitude: -74.0060
        )
        mockLocationRepository.currentLocatedCity = locatedCity

        await viewModel.requestWeatherForCurrentLocation()

        let state = viewModel.uiState
        #expect(state.locationState.selectedState?.name == "New York")
        #expect(state.locationState.selectedCity == "New York City")
    }

    @Test("Request weather for current location when at same location retains weather content in place")
    func requestWeatherForCurrentLocationWhenAtSameLocationRetainsWeatherContentInPlace() async {
        let nyState = USState(name: "New York", abbreviation: "NY")
        let locatedCity = LocatedCity(
            state: nyState,
            city: "New York City",
            latitude: 40.7128,
            longitude: -74.0060
        )

        mockLocationRepository.currentLocatedCity = locatedCity
        mockLocationRepository.majorCitiesByState = ["NY": ["New York City"]]

        await viewModel.requestWeatherForCurrentLocation()
        await viewModel.requestWeatherForCurrentLocation()

        let state = viewModel.uiState
        #expect(state.locationState.selectedState?.name == "New York")
        #expect(state.locationState.selectedCity == "New York City")
        #expect(state.weatherState.weatherContent != nil)
    }
}
