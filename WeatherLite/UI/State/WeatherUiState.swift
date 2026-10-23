import Foundation

nonisolated struct WeatherUiState: Equatable, Sendable {
    var locationState: LocationSelectionState = LocationSelectionState()
    var weatherState: WeatherDataState = WeatherDataState()
    var error: String? = nil
    var bookmarks: [Bookmark] = []
    var isResolvingCurrentLocation: Bool = false
    var permissionRequestState: PermissionRequestState = .none
    var locationPermissionRequested: Bool = false

    var isLoading: Bool {
        (locationState.isLoadingStates ||
            locationState.isLoadingCities ||
            weatherState.isLoadingWeather ||
            isResolvingCurrentLocation) && error == nil
    }

    var canUseCurrentLocation: Bool {
        !isResolvingCurrentLocation && !weatherState.isLoadingWeather
    }
}
