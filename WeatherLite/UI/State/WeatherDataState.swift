import Foundation

nonisolated struct WeatherDataState: Equatable, Sendable {
    var isLoadingWeather: Bool = false
    var weatherContent: WeatherDataPO? = nil
    var temperatureUnit: TemperatureUnit = .celsius
}
