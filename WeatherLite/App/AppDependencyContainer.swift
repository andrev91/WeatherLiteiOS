import Foundation
import Observation

@Observable
final class AppDependencyContainer {
    let apiKey: String
    let apiService: ApiServiceProtocol
    let localDatabaseStore: LocalDatabaseStoreProtocol
    let locationRemoteDataSource: LocationRemoteDataSourceProtocol
    let locationProvider: LocationProviderProtocol
    let settingsRepository: SettingsRepositoryProtocol
    let locationRepository: LocationRepositoryProtocol
    let weatherRepository: WeatherRepositoryProtocol
    let weatherViewModel: WeatherViewModel
    let settingsViewModel: SettingsViewModel

    init(inMemoryDatabase: Bool = false) {
        ApiServiceHost.setActive(.openWeatherMap)
        let resolvedKey = (try? ApiServiceHost.provideApiKey()) ?? ""
        self.apiKey = resolvedKey

        let apiService = URLSessionApiService()
        self.apiService = apiService

        let localStore = SwiftDataDatabaseStore(inMemory: inMemoryDatabase)
        self.localDatabaseStore = localStore

        let remoteDataSource = LocationRemoteDataSource(apiService: apiService, apiKey: resolvedKey)
        self.locationRemoteDataSource = remoteDataSource

        let locationProvider = CoreLocationProvider()
        self.locationProvider = locationProvider

        let settingsRepo = SettingsRepository()
        self.settingsRepository = settingsRepo

        let locationRepo = LocationRepository(
            localStore: localStore,
            locationRemoteDataSource: remoteDataSource,
            locationProvider: locationProvider
        )
        self.locationRepository = locationRepo

        let weatherRepo = WeatherRepository(apiService: apiService, apiKey: resolvedKey)
        self.weatherRepository = weatherRepo

        self.weatherViewModel = WeatherViewModel(
            weatherRepository: weatherRepo,
            locationRepository: locationRepo,
            settingsRepository: settingsRepo
        )
        self.settingsViewModel = SettingsViewModel(settingsRepository: settingsRepo)
    }
}
