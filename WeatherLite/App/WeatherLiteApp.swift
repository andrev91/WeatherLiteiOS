import SwiftUI

@main
struct WeatherLiteApp: App {
    @State private var container = AppDependencyContainer()
    @State private var navigationPath: [AppRoute] = []

    var body: some Scene {
        WindowGroup {
            WeatherLiteTheme(themeMode: container.settingsViewModel.themeMode) {
                NavigationStack(path: $navigationPath) {
                    WeatherScreen(
                        viewModel: container.weatherViewModel,
                        locationProvider: container.locationProvider,
                        onSettingsClick: {
                            navigationPath.append(.settings)
                        }
                    )
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .weather:
                            WeatherScreen(
                                viewModel: container.weatherViewModel,
                                locationProvider: container.locationProvider,
                                onSettingsClick: {
                                    navigationPath.append(.settings)
                                }
                            )
                        case .settings:
                            SettingsScreen(viewModel: container.settingsViewModel)
                        }
                    }
                }
            }
        }
    }
}
