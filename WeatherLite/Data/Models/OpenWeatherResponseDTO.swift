import Foundation

nonisolated struct OpenWeatherResponseDTO: Codable, Equatable, Sendable {
    let coord: CoordinateDTO
    let weather: [WeatherDetailsDTO]
    let base: String
    let main: WeatherObjectDTO
    let visibility: Int
    let wind: WindDTO
    let rain: RainDurationDTO?
    let clouds: CloudsDTO
    let dt: Int64
    let sys: WeatherLocationDTO
    let timezone: Int
    let id: Int
    let name: String
    let cod: Int

    init(
        coord: CoordinateDTO,
        weather: [WeatherDetailsDTO],
        base: String,
        main: WeatherObjectDTO,
        visibility: Int,
        wind: WindDTO,
        rain: RainDurationDTO? = nil,
        clouds: CloudsDTO,
        dt: Int64,
        sys: WeatherLocationDTO,
        timezone: Int,
        id: Int,
        name: String,
        cod: Int
    ) {
        self.coord = coord
        self.weather = weather
        self.base = base
        self.main = main
        self.visibility = visibility
        self.wind = wind
        self.rain = rain
        self.clouds = clouds
        self.dt = dt
        self.sys = sys
        self.timezone = timezone
        self.id = id
        self.name = name
        self.cod = cod
    }
}

nonisolated struct CoordinateDTO: Codable, Equatable, Sendable {
    let lon: Double
    let lat: Double
}

nonisolated struct WeatherDetailsDTO: Codable, Equatable, Sendable {
    let id: Int
    let main: String
    let description: String
    let icon: String
}

nonisolated struct WeatherObjectDTO: Codable, Equatable, Sendable {
    let temp: Double
    let feelsLike: Double
    let tempMin: Double
    let tempMax: Double
    let pressure: Int
    let humidity: Int
    let seaLevel: Int?
    let grndLevel: Int?

    init(
        temp: Double,
        feelsLike: Double,
        tempMin: Double,
        tempMax: Double,
        pressure: Int,
        humidity: Int,
        seaLevel: Int? = nil,
        grndLevel: Int? = nil
    ) {
        self.temp = temp
        self.feelsLike = feelsLike
        self.tempMin = tempMin
        self.tempMax = tempMax
        self.pressure = pressure
        self.humidity = humidity
        self.seaLevel = seaLevel
        self.grndLevel = grndLevel
    }

    enum CodingKeys: String, CodingKey {
        case temp
        case feelsLike = "feels_like"
        case tempMin = "temp_min"
        case tempMax = "temp_max"
        case pressure
        case humidity
        case seaLevel = "sea_level"
        case grndLevel = "grnd_level"
    }
}

nonisolated struct WindDTO: Codable, Equatable, Sendable {
    let speed: Double
    let deg: Int
    let gust: Double?

    init(speed: Double, deg: Int, gust: Double? = nil) {
        self.speed = speed
        self.deg = deg
        self.gust = gust
    }
}

nonisolated struct RainDurationDTO: Codable, Equatable, Sendable {
    let oneHour: Double?

    init(oneHour: Double? = nil) {
        self.oneHour = oneHour
    }

    enum CodingKeys: String, CodingKey {
        case oneHour = "1h"
    }
}

nonisolated struct CloudsDTO: Codable, Equatable, Sendable {
    let all: Int
}

nonisolated struct WeatherLocationDTO: Codable, Equatable, Sendable {
    let type: Int?
    let id: Int?
    let country: String?
    let sunrise: Int64
    let sunset: Int64

    init(
        type: Int? = nil,
        id: Int? = nil,
        country: String? = nil,
        sunrise: Int64,
        sunset: Int64
    ) {
        self.type = type
        self.id = id
        self.country = country
        self.sunrise = sunrise
        self.sunset = sunset
    }
}
