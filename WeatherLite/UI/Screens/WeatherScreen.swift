import CoreLocation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum WeatherScreenTags {
    static let locationDropdown = "LocationDropdown"
    static let cityDropdown = "CityDropdown"
    static let locationDropdownOutline = "LocationDropdownOutline"
    static let weatherDescription = "WeatherDescriptionText"
    static let weatherTemperature = "WeatherTemperatureText"
    static let errorText = "ErrorText"
    static let progress = "ProgressIndicator"
    static let locationDescription = "LocationDescriptionText"
    static let refreshButton = "RefreshButton"
    static let currentLocationButton = "CurrentLocationButton"
}

struct WeatherScreen: View {
    var viewModel: WeatherViewModel
    var locationProvider: LocationProviderProtocol
    let onSettingsClick: () -> Void

    @State private var snackbarMessage: String? = nil
    @State private var snackbarDismissTask: Task<Void, Never>? = nil

    private var showExplanationDialog: Binding<Bool> {
        Binding(
            get: { viewModel.uiState.permissionRequestState == .explanation },
            set: { isPresented in
                if !isPresented {
                    viewModel.denyLocationExplanation()
                }
            }
        )
    }

    private var showSettingsDialog: Binding<Bool> {
        Binding(
            get: { viewModel.uiState.permissionRequestState == .settings },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissLocationSettingsDialog()
                }
            }
        )
    }

    var body: some View {
        WeatherScaffold(
            uiState: viewModel.uiState,
            snackbarMessage: $snackbarMessage,
            onRemoveBookmark: { bookmark in
                Task { await viewModel.removeBookmark(bookmark) }
            },
            onLoadBookmark: { viewModel.loadBookmark($0) },
            onSettingsClick: onSettingsClick
        ) {
            WeatherScreenContent(
                uiState: viewModel.uiState,
                onDropdownSearch: { type, query in
                    viewModel.searchDropdownList(type, query: query)
                },
                onDropdownClear: { type in
                    viewModel.clearDropdownSelection(type)
                },
                onDropdownSelected: { type, value in
                    viewModel.setDropdownSelection(type, location: value)
                },
                onRefreshClicked: {
                    Task { await viewModel.searchLocation(keepExistingWeather: true) }
                },
                onAddBookmark: {
                    Task { await viewModel.addBookmark() }
                },
                onUseCurrentLocation: {
                    let status = locationProvider.authorizationStatus
                    let hasPermission = locationProvider.hasLocationPermission
                    Task {
                        await viewModel.onUseCurrentLocationClicked(
                            hasPermission: hasPermission,
                            shouldShowRationale: status == .notDetermined
                        )
                    }
                }
            )
        }
        .alert("Access your location", isPresented: showExplanationDialog) {
            Button("Not now", role: .cancel) {
                viewModel.denyLocationExplanation()
            }
            Button("Allow") {
                Task { await viewModel.acceptLocationExplanation() }
            }
        } message: {
            Text("WeatherLite needs your location to find the nearest city and its weather. No personal information is stored.")
        }
        .alert("Location Permission Required", isPresented: showSettingsDialog) {
            Button("Not now", role: .cancel) {
                viewModel.dismissLocationSettingsDialog()
            }
            Button("Open Settings") {
                viewModel.dismissLocationSettingsDialog()
                #if canImport(UIKit)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                #endif
            }
        } message: {
            Text("Location access is disabled in device settings. Please enable location permission in app settings to use your current location.")
        }
        .task {
            for await event in viewModel.bookmarkStateStream {
                showSnackbar(event.message)
            }
        }
        .task {
            for await _ in viewModel.permissionPromptStream {
                let granted = await locationProvider.requestWhenInUseAuthorization()
                let status = locationProvider.authorizationStatus
                await viewModel.onPermissionResult(
                    granted: granted,
                    shouldShowRationale: status == .notDetermined
                )
            }
        }
    }

    private func showSnackbar(_ message: String) {
        snackbarDismissTask?.cancel()
        withAnimation {
            snackbarMessage = message
        }
        snackbarDismissTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation {
                snackbarMessage = nil
            }
        }
    }
}

struct WeatherScreenContent: View {
    let uiState: WeatherUiState
    let onDropdownSearch: (LocationType, String) -> Void
    let onDropdownClear: (LocationType) -> Void
    let onDropdownSelected: (LocationType, String) -> Void
    let onRefreshClicked: () -> Void
    let onAddBookmark: () -> Void
    var onUseCurrentLocation: () -> Void = {}

    @Environment(\.weatherLiteColorScheme) private var colors

    private var citySections: [DropDownSection<String>]? {
        let major = uiState.locationState.majorCities
        let all = uiState.locationState.allCities
        guard !major.isEmpty || !all.isEmpty else { return nil }

        var sections: [DropDownSection<String>] = []
        if !major.isEmpty {
            sections.append(DropDownSection(id: "major_cities", title: "Major Cities", options: major))
        }
        if !all.isEmpty {
            sections.append(DropDownSection(id: "all_cities", title: "All Cities", options: all))
        }
        return sections
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("OpenWeather Data")
                    .font(WeatherLiteTypography.headlineMedium)
                    .foregroundStyle(colors.onBackground)

                SearchableDropDown(
                    label: "US State",
                    testTag: WeatherScreenTags.locationDescription,
                    options: uiState.locationState.displayedStates,
                    searchQuery: uiState.locationState.stateSearchQuery,
                    onSearchQueryChanged: { onDropdownSearch(.state, $0) },
                    onOptionSelected: { onDropdownSelected(.state, $0) },
                    onClear: { onDropdownClear(.state) },
                    isSelected: uiState.locationState.selectedState != nil,
                    selectedValue: uiState.locationState.selectedState?.name,
                    optionToString: { $0.name }
                )
                .containerRelativeFrame(.horizontal) { width, _ in
                    max(width * 0.8, 220)
                }

                if uiState.locationState.showCityDropdown {
                    SearchableDropDown(
                        label: "City",
                        testTag: WeatherScreenTags.cityDropdown,
                        options: uiState.locationState.displayedCities,
                        searchQuery: uiState.locationState.citySearchQuery,
                        onSearchQueryChanged: { onDropdownSearch(.city, $0) },
                        onOptionSelected: { onDropdownSelected(.city, $0) },
                        onClear: { onDropdownClear(.city) },
                        isSelected: uiState.locationState.selectedCity != nil,
                        selectedValue: uiState.locationState.selectedCity,
                        sections: citySections,
                        optionToString: { $0 }
                    )
                    .containerRelativeFrame(.horizontal) { width, _ in
                        max(width * 0.8, 220)
                    }
                }

                let isLoading = uiState.isLoading
                if isLoading && uiState.weatherState.weatherContent == nil {
                    WeatherLoadingOrb(message: String(localized: "Loading…"))
                        .padding(8)
                        .accessibilityIdentifier(WeatherScreenTags.progress)
                } else if uiState.weatherState.weatherContent == nil && uiState.error == nil {
                    Text("Weather/Location Data")
                        .font(WeatherLiteTypography.bodyLarge)
                        .foregroundStyle(colors.onBackground)
                        .padding(8)
                } else if let error = uiState.error {
                    Text(error)
                        .font(WeatherLiteTypography.bodyLarge)
                        .foregroundStyle(colors.error)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier(WeatherScreenTags.errorText)
                }

                if let weatherContent = uiState.weatherState.weatherContent {
                    ZStack {
                        WeatherDetailsCard(
                            data: weatherContent,
                            unit: uiState.weatherState.temperatureUnit
                        )
                        .opacity(isLoading ? 0.5 : 1.0)

                        if isLoading {
                            ProgressView()
                                .tint(colors.primary)
                                .accessibilityIdentifier(WeatherScreenTags.progress)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                }

                HStack(spacing: 12) {
                    Button(action: onRefreshClicked) {
                        Text(
                            uiState.weatherState.weatherContent != nil
                                ? "Refresh"
                                : "Fetch Weather"
                        )
                        .font(WeatherLiteTypography.titleMedium)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 12))
                    .controlSize(.large)
                    .tint(colors.primary)
                    .foregroundStyle(colors.onPrimary)
                    .accessibilityIdentifier(WeatherScreenTags.refreshButton)

                    if uiState.locationState.canBookmark {
                        Button(action: onAddBookmark) {
                            Text("Bookmark")
                                .font(WeatherLiteTypography.titleMedium)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 12))
                        .controlSize(.large)
                        .tint(colors.primary)
                        .foregroundStyle(colors.onPrimary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .containerRelativeFrame(.horizontal) { width, _ in
                    max(width * 0.8, 220)
                }

                Button(action: onUseCurrentLocation) {
                    Label("Use Current Location", systemImage: "location.fill")
                        .font(WeatherLiteTypography.titleMedium)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .controlSize(.large)
                .tint(colors.primary)
                .foregroundStyle(uiState.canUseCurrentLocation ? colors.onPrimary : colors.onSurfaceVariant)
                .disabled(!uiState.canUseCurrentLocation)
                .containerRelativeFrame(.horizontal) { width, _ in
                    max(width * 0.8, 220)
                }
                .accessibilityIdentifier(WeatherScreenTags.currentLocationButton)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.center)
    }
}
