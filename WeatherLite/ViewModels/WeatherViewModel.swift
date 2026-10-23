import CoreLocation
import Foundation
import Observation

@Observable
final class WeatherViewModel {
    private(set) var uiState: WeatherUiState = WeatherUiState()
    var latestBookmarkEvent: BookmarkState? = nil

    private let weatherRepository: WeatherRepositoryProtocol
    private let locationRepository: LocationRepositoryProtocol
    private let settingsRepository: SettingsRepositoryProtocol

    @ObservationIgnored
    private var bookmarkContinuations: [UUID: AsyncStream<BookmarkState>.Continuation] = [:]
    @ObservationIgnored
    private var permissionPromptContinuations: [UUID: AsyncStream<Void>.Continuation] = [:]

    @ObservationIgnored
    private var searchTask: Task<Void, Never>?
    @ObservationIgnored
    private var weatherTask: Task<Void, Never>?
    @ObservationIgnored
    private var currentLocationTask: Task<Void, Never>?
    @ObservationIgnored
    private var observationTasks: [Task<Void, Never>] = []

    var bookmarkStateStream: AsyncStream<BookmarkState> {
        let (stream, continuation) = AsyncStream.makeStream(of: BookmarkState.self)
        let id = UUID()
        bookmarkContinuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.bookmarkContinuations.removeValue(forKey: id)
            }
        }
        return stream
    }

    var permissionPromptStream: AsyncStream<Void> {
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        let id = UUID()
        permissionPromptContinuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.permissionPromptContinuations.removeValue(forKey: id)
            }
        }
        return stream
    }

    init(
        weatherRepository: WeatherRepositoryProtocol,
        locationRepository: LocationRepositoryProtocol,
        settingsRepository: SettingsRepositoryProtocol
    ) {
        self.weatherRepository = weatherRepository
        self.locationRepository = locationRepository
        self.settingsRepository = settingsRepository

        self.uiState.bookmarks = locationRepository.getBookmarks()
        self.uiState.weatherState.temperatureUnit = settingsRepository.currentTemperatureUnit
        self.uiState.locationPermissionRequested = settingsRepository.currentLocationPermissionRequested

        fetchStateList()
        observeRepositoryStreams()
    }

    isolated deinit {
        searchTask?.cancel()
        weatherTask?.cancel()
        currentLocationTask?.cancel()
        for task in observationTasks {
            task.cancel()
        }
    }

    private func observeRepositoryStreams() {
        let bookmarksStream = locationRepository.bookmarksStream
        let unitStream = settingsRepository.temperatureUnitStream
        let permissionStream = settingsRepository.locationPermissionRequestedStream

        let bookmarksTask = Task { [weak self] in
            guard let self else { return }
            for await bookmarks in bookmarksStream {
                guard !Task.isCancelled else { break }
                self.uiState.bookmarks = bookmarks
            }
        }

        let unitTask = Task { [weak self] in
            guard let self else { return }
            for await unit in unitStream {
                guard !Task.isCancelled else { break }
                self.uiState.weatherState.temperatureUnit = unit
            }
        }

        let permissionTask = Task { [weak self] in
            guard let self else { return }
            for await requested in permissionStream {
                guard !Task.isCancelled else { break }
                self.uiState.locationPermissionRequested = requested
            }
        }

        observationTasks = [bookmarksTask, unitTask, permissionTask]
    }

    func clearBookmarkEvent() {
        latestBookmarkEvent = nil
    }

    private func emitBookmarkEvent(_ event: BookmarkState) {
        latestBookmarkEvent = event
        for continuation in bookmarkContinuations.values {
            continuation.yield(event)
        }
    }

    private func emitPermissionPrompt() {
        for continuation in permissionPromptContinuations.values {
            continuation.yield(())
        }
    }

    func addBookmark() async {
        guard let state = uiState.locationState.selectedState,
              let city = uiState.locationState.selectedCity else {
            return
        }

        if await locationRepository.isBookmarkDuplicate(state: state.name, city: city) {
            emitBookmarkEvent(.onError(String(localized: "Cannot save duplicate Bookmark!")))
            return
        }

        let bookmark = Bookmark(
            stateName: state.name,
            stateAbbreviation: state.abbreviation,
            cityName: city
        )
        await locationRepository.addBookmark(bookmark)
        uiState.bookmarks = locationRepository.getBookmarks()
        emitBookmarkEvent(.onSuccess(String(localized: "Bookmark successfully added!")))
    }

    func removeBookmark(_ bookmark: Bookmark) async {
        await locationRepository.removeBookmark(bookmark)
        uiState.bookmarks = locationRepository.getBookmarks()
        emitBookmarkEvent(.onDelete(String(localized: "Bookmark removed.")))
    }

    func loadBookmark(_ bookmark: Bookmark) {
        setDropdownSelection(.state, location: bookmark.stateName)
        setDropdownSelection(.city, location: bookmark.cityName)
    }

    func clearDropdownSelection(_ locationType: LocationType) {
        searchTask?.cancel()
        weatherTask?.cancel()

        switch locationType {
        case .state:
            uiState.locationState.selectedState = nil
            uiState.locationState.isLoadingStates = false
            uiState.locationState.filteredStates = []
            uiState.locationState.isLoadingCities = false
            uiState.locationState.selectedCity = nil
            uiState.locationState.availableCities = []
            uiState.locationState.majorCities = []
            uiState.locationState.allCities = []
            uiState.locationState.stateSearchQuery = ""
            uiState.locationState.citySearchQuery = ""

        case .city:
            uiState.locationState.isLoadingCities = false
            uiState.locationState.selectedCity = nil
            uiState.locationState.filteredCities = []
            uiState.locationState.citySearchQuery = ""
        }

        uiState.weatherState.isLoadingWeather = false
        uiState.weatherState.weatherContent = nil
        uiState.error = nil
    }

    func setDropdownSelection(_ locationType: LocationType, location: String) {
        searchTask?.cancel()
        weatherTask?.cancel()

        switch locationType {
        case .state:
            guard let state = locationRepository.getStateFromString(location),
                  state != uiState.locationState.selectedState else {
                return
            }

            uiState.locationState.selectedState = state
            uiState.locationState.isLoadingStates = false
            uiState.locationState.isLoadingCities = true
            uiState.locationState.selectedCity = nil
            uiState.locationState.availableCities = []
            uiState.locationState.majorCities = []
            uiState.locationState.allCities = []
            uiState.locationState.filteredStates = uiState.locationState.availableStates
            uiState.locationState.filteredCities = []
            uiState.locationState.stateSearchQuery = state.name
            uiState.locationState.citySearchQuery = ""
            uiState.weatherState.isLoadingWeather = false
            uiState.weatherState.weatherContent = nil
            uiState.error = nil

            let major = locationRepository.getMajorCitiesByState(state.abbreviation)
            let all = locationRepository.getAllCitiesByState(state.abbreviation)
            uiState.locationState.majorCities = major
            uiState.locationState.allCities = all
            uiState.locationState.availableCities = all.isEmpty ? major : all
            uiState.locationState.isLoadingCities = false

        case .city:
            guard location != uiState.locationState.selectedCity else {
                return
            }
            uiState.locationState.selectedCity = location
            uiState.locationState.filteredCities = []
            uiState.locationState.citySearchQuery = location
            uiState.weatherState.isLoadingWeather = false
            uiState.weatherState.weatherContent = nil
            uiState.error = nil
        }
    }

    func searchDropdownList(_ locationType: LocationType, query: String) {
        switch locationType {
        case .state:
            searchStateList(query)
        case .city:
            searchCityList(query)
        }
    }

    private func searchStateList(_ query: String) {
        uiState.error = nil
        let filtered = locationRepository.filterStates(
            query: query,
            availableStates: uiState.locationState.availableStates
        )
        uiState.locationState.stateSearchQuery = query
        uiState.locationState.filteredStates = filtered
    }

    private func searchCityList(_ query: String) {
        guard uiState.locationState.citySearchQuery != query else {
            return
        }

        uiState.locationState.citySearchQuery = query
        uiState.error = nil

        let abbreviation = uiState.locationState.selectedState?.abbreviation
        let defaultCities = uiState.locationState.availableCities
        let filtered = locationRepository.searchCities(
            stateAbbreviation: abbreviation,
            query: query,
            defaultCities: defaultCities
        )
        uiState.locationState.filteredCities = filtered
    }

    private func fetchWeather(
        lat: Double,
        lon: Double,
        keepExistingWeather: Bool = false
    ) async {
        if !keepExistingWeather {
            uiState.weatherState.weatherContent = nil
        }
        uiState.weatherState.isLoadingWeather = true
        uiState.error = nil

        weatherTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let weather = try await self.weatherRepository.fetchWeather(lat: lat, lon: lon)
                guard !Task.isCancelled else { return }
                self.uiState.weatherState.weatherContent = weather
                self.uiState.weatherState.isLoadingWeather = false
                self.uiState.error = nil
            } catch is CancellationError {
                guard !Task.isCancelled else { return }
                self.uiState.weatherState.isLoadingWeather = false
                self.uiState.error = String(localized: "Weather fetch canceled.")
            } catch let apiError as ApiServiceError {
                guard !Task.isCancelled else { return }
                self.uiState.weatherState.isLoadingWeather = false
                self.uiState.error = apiError.errorDescription ?? String(localized: "Unknown error")
            } catch {
                guard !Task.isCancelled else { return }
                self.uiState.weatherState.isLoadingWeather = false
                self.uiState.error = error.localizedDescription
            }
        }
        weatherTask = task
        await task.value
    }

    func searchLocation(keepExistingWeather: Bool = false) async {
        let locationState = uiState.locationState
        guard locationState.canBookmark else {
            uiState.error = String(localized: "Please select a state and city.")
            return
        }
        guard !uiState.weatherState.isLoadingWeather else {
            return
        }

        if !keepExistingWeather {
            uiState.weatherState.weatherContent = nil
        }
        uiState.weatherState.isLoadingWeather = true
        uiState.error = nil

        guard let stateName = locationState.selectedState?.name else {
            return
        }
        let city = locationState.selectedCity ?? ""

        searchTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            let result = await self.locationRepository.getOrFetchLocation(name: "\(city), \(stateName)")
            guard !Task.isCancelled else { return }
            switch result {
            case .success(let location):
                await self.fetchWeather(
                    lat: location.latitude,
                    lon: location.longitude,
                    keepExistingWeather: keepExistingWeather
                )
            case .failure(let error):
                self.uiState.weatherState.isLoadingWeather = false
                self.uiState.error = error.localizedDescription
            }
        }
        searchTask = task
        await task.value
    }

    private func fetchStateList() {
        guard !uiState.locationState.isLoadingStates else {
            return
        }

        uiState.locationState.isLoadingStates = true
        uiState.locationState.selectedState = nil
        uiState.locationState.selectedCity = nil
        uiState.locationState.availableStates = []
        uiState.locationState.availableCities = []
        uiState.locationState.majorCities = []
        uiState.locationState.allCities = []
        uiState.error = nil

        let stateData = locationRepository.getStates()
        uiState.locationState.availableStates = stateData
        uiState.locationState.filteredStates = stateData
        uiState.locationState.isLoadingStates = false
    }

    func onUseCurrentLocationClicked(authorizationStatus: CLAuthorizationStatus) async {
        let hasPermission = (authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways)
        let isNotDetermined = (authorizationStatus == .notDetermined)
        await onUseCurrentLocationClicked(
            hasPermission: hasPermission,
            shouldShowRationale: isNotDetermined
        )
    }

    func onUseCurrentLocationClicked(
        hasPermission: Bool,
        shouldShowRationale: Bool = false
    ) async {
        guard !uiState.isResolvingCurrentLocation else {
            return
        }
        uiState.error = nil

        if hasPermission {
            await requestWeatherForCurrentLocation()
            return
        }

        if uiState.locationPermissionRequested && !shouldShowRationale {
            uiState.permissionRequestState = .settings
        } else {
            uiState.permissionRequestState = .explanation
        }
    }

    func acceptLocationExplanation() async {
        uiState.permissionRequestState = .none
        await settingsRepository.setLocationPermissionRequested(true)
        uiState.locationPermissionRequested = true
        emitPermissionPrompt()
    }

    func denyLocationExplanation() {
        uiState.permissionRequestState = .none
    }

    func dismissLocationSettingsDialog() {
        uiState.permissionRequestState = .none
    }

    func onPermissionResult(authorizationStatus: CLAuthorizationStatus) async {
        let granted = (authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways)
        let isNotDetermined = (authorizationStatus == .notDetermined)
        await onPermissionResult(granted: granted, shouldShowRationale: isNotDetermined)
    }

    func onPermissionResult(
        granted: Bool,
        shouldShowRationale: Bool = false
    ) async {
        await settingsRepository.setLocationPermissionRequested(true)
        uiState.locationPermissionRequested = true

        if granted {
            await requestWeatherForCurrentLocation()
        } else {
            uiState.error = String(localized: "Location permission is required to determine your current location.")
            uiState.permissionRequestState = !shouldShowRationale ? .settings : .none
        }
    }

    func requestWeatherForCurrentLocation() async {
        guard !uiState.isResolvingCurrentLocation else {
            return
        }
        uiState.error = nil
        uiState.isResolvingCurrentLocation = true

        currentLocationTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            defer {
                self.uiState.isResolvingCurrentLocation = false
            }
            do {
                guard let locatedCity = try await self.locationRepository.getCurrentLocatedCity() else {
                    self.updateCurrentLocationFailure()
                    return
                }
                guard !Task.isCancelled else { return }
                await self.applyLocatedCityAndFetchWeather(locatedCity)
            } catch {
                guard !Task.isCancelled else { return }
                self.updateCurrentLocationFailure()
            }
        }
        currentLocationTask = task
        await task.value
    }

    private func applyLocatedCityAndFetchWeather(_ locatedCity: LocatedCity) async {
        let currentLocationState = uiState.locationState
        let isSameLocation =
            currentLocationState.selectedState == locatedCity.state &&
            currentLocationState.selectedCity == locatedCity.city

        if !isSameLocation {
            let major = locationRepository.getMajorCitiesByState(locatedCity.state.abbreviation)
            let all = locationRepository.getAllCitiesByState(locatedCity.state.abbreviation)
            uiState.locationState.selectedState = locatedCity.state
            uiState.locationState.isLoadingStates = false
            uiState.locationState.isLoadingCities = false
            uiState.locationState.majorCities = major
            uiState.locationState.allCities = all
            uiState.locationState.availableCities = all.isEmpty ? major : all
            uiState.locationState.filteredCities = []
            uiState.locationState.selectedCity = locatedCity.city
            uiState.locationState.stateSearchQuery = locatedCity.state.name
            uiState.locationState.citySearchQuery = locatedCity.city
            uiState.weatherState.weatherContent = nil
        }

        uiState.error = nil
        uiState.isResolvingCurrentLocation = false

        let keepExisting = isSameLocation && uiState.weatherState.weatherContent != nil
        if let lat = locatedCity.latitude, let lon = locatedCity.longitude {
            await fetchWeather(lat: lat, lon: lon, keepExistingWeather: keepExisting)
        } else {
            await searchLocation(keepExistingWeather: keepExisting)
        }
    }

    private func updateCurrentLocationFailure() {
        uiState.isResolvingCurrentLocation = false
        uiState.error = String(localized: "Unable to find a location for your current area.")
    }
}
