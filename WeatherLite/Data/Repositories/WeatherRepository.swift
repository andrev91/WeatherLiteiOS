import Foundation

protocol WeatherRepositoryProtocol {
    func fetchWeather(lat: Double, lon: Double) async throws -> WeatherDataPO
}

final class WeatherRepository: WeatherRepositoryProtocol {
    private let apiService: ApiServiceProtocol
    private let apiKey: String

    init(apiService: ApiServiceProtocol, apiKey: String) {
        self.apiService = apiService
        self.apiKey = apiKey
    }

    func fetchWeather(lat: Double, lon: Double) async throws -> WeatherDataPO {
        guard !lat.isNaN && !lon.isNaN else {
            throw ApiServiceError.custom(String(localized: "Invalid lat/lon provided"))
        }

        try Task.checkCancellation()
        let response = try await apiService.getWeather(
            lat: lat,
            lon: lon,
            apiKey: apiKey,
            units: "imperial"
        )
        try Task.checkCancellation()
        return Self.mapResponseToWeatherDataPO(response)
    }

    static func mapResponseToWeatherDataPO(_ response: OpenWeatherResponseDTO) -> WeatherDataPO {
        let fahrenheitMeasurement = Measurement(value: response.main.temp, unit: UnitTemperature.fahrenheit)
        let celsiusMeasurement = fahrenheitMeasurement.converted(to: .celsius)

        let maxFraction = response.main.temp.truncatingRemainder(dividingBy: 1) == 0 ? 1 : 2
        let formattedTempFahrenheit = fahrenheitMeasurement.formatted(
            .measurement(
                width: .abbreviated,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(1...maxFraction))
            )
            .locale(Locale(identifier: "en_US"))
        )
        let formattedTempCelsius = celsiusMeasurement.formatted(
            .measurement(
                width: .abbreviated,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(2))
            )
            .locale(Locale(identifier: "en_US"))
        )
        let observedTime = formatUnixTimestampToLocal(response.dt)
        let icon = response.weather.first?.icon.trimmingCharacters(in: .whitespacesAndNewlines)
        let weatherIconUrl: String?
        if let icon, !icon.isEmpty {
            weatherIconUrl = "https://openweathermap.org/img/wn/\(icon)@2x.png"
        } else {
            weatherIconUrl = nil
        }

        return WeatherDataPO(
            temperatureFahrenheit: formattedTempFahrenheit,
            temperatureCelsius: formattedTempCelsius,
            weatherDescription: response.weather.first?.description ?? String(localized: "No description"),
            weatherIcon: weatherIconUrl,
            observedAt: observedTime
        )
    }

    static func formatUnixTimestampToLocal(_ timestamp: Int64, timeZone: TimeZone = .current) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        var formatStyle = Date.FormatStyle(date: .omitted, time: .shortened)
        formatStyle.timeZone = timeZone
        return date.formatted(formatStyle)
    }
}
