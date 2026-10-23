import Foundation

nonisolated struct WeatherDataPO: Equatable, Sendable {
    let temperatureFahrenheit: String
    let temperatureCelsius: String
    let weatherDescription: String
    let weatherIcon: String?
    let observedAt: String

    init(
        temperatureFahrenheit: String,
        temperatureCelsius: String,
        weatherDescription: String,
        weatherIcon: String? = nil,
        observedAt: String
    ) {
        self.temperatureFahrenheit = temperatureFahrenheit
        self.temperatureCelsius = temperatureCelsius
        self.weatherDescription = weatherDescription
        self.weatherIcon = weatherIcon
        self.observedAt = observedAt
    }
}
