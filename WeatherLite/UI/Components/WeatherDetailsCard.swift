import SwiftUI

struct WeatherDetailsCard: View {
    let data: WeatherDataPO
    var unit: TemperatureUnit = .celsius

    @Environment(\.weatherLiteColorScheme) private var colors
    @Environment(\.colorScheme) private var systemColorScheme
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 36
    @ScaledMetric(relativeTo: .largeTitle) private var iconFrameSize: CGFloat = 44

    private var sfSymbolName: String {
        if let iconUrl = data.weatherIcon {
            if iconUrl.contains("01d") { return "sun.max.fill" }
            if iconUrl.contains("01n") { return "moon.stars.fill" }
            if iconUrl.contains("02d") { return "cloud.sun.fill" }
            if iconUrl.contains("02n") { return "cloud.moon.fill" }
            if iconUrl.contains("03") { return "cloud.fill" }
            if iconUrl.contains("04") { return "smoke.fill" }
            if iconUrl.contains("09") { return "cloud.drizzle.fill" }
            if iconUrl.contains("10d") { return "cloud.sun.rain.fill" }
            if iconUrl.contains("10n") { return "cloud.moon.rain.fill" }
            if iconUrl.contains("11") { return "cloud.bolt.rain.fill" }
            if iconUrl.contains("13") { return "snowflake" }
            if iconUrl.contains("50") { return "cloud.fog.fill" }
        }

        let desc = data.weatherDescription.lowercased()
        if desc.contains("thunder") { return "cloud.bolt.rain.fill" }
        if desc.contains("drizzle") { return "cloud.drizzle.fill" }
        if desc.contains("rain") { return "cloud.rain.fill" }
        if desc.contains("snow") { return "snowflake" }
        if desc.contains("fog") || desc.contains("mist") || desc.contains("haze") { return "cloud.fog.fill" }
        if desc.contains("clear") { return "sun.max.fill" }
        if desc.contains("few clouds") { return "cloud.sun.fill" }
        if desc.contains("cloud") { return "cloud.fill" }
        return "cloud.sun.fill"
    }

    private var lightModePalette: (primary: Color, secondary: Color, tertiary: Color) {
        let cloudSlate = Color(hex: 0x607D8B)
        let sunOrange = Color(hex: 0xF59E0B)
        let rainBlue = Color(hex: 0x0288D1)
        let nightIndigo = Color(hex: 0x5C6BC0)

        switch sfSymbolName {
        case "sun.max.fill":
            return (sunOrange, sunOrange, sunOrange)
        case "moon.stars.fill":
            return (nightIndigo, sunOrange, nightIndigo)
        case "snowflake":
            return (rainBlue, rainBlue, rainBlue)
        case "cloud.sun.fill":
            return (cloudSlate, sunOrange, rainBlue)
        case "cloud.moon.fill":
            return (cloudSlate, nightIndigo, rainBlue)
        case "cloud.drizzle.fill", "cloud.rain.fill":
            return (cloudSlate, rainBlue, rainBlue)
        case "cloud.sun.rain.fill", "cloud.bolt.rain.fill":
            return (cloudSlate, sunOrange, rainBlue)
        case "cloud.moon.rain.fill":
            return (cloudSlate, nightIndigo, rainBlue)
        case "cloud.fog.fill":
            return (cloudSlate, cloudSlate.opacity(0.6), cloudSlate)
        default:
            return (cloudSlate, sunOrange, rainBlue)
        }
    }

    var body: some View {
        let tempValue = (unit == .celsius) ? data.temperatureCelsius : data.temperatureFahrenheit

        VStack(spacing: 10) {
            Text(data.weatherDescription)
                .font(WeatherLiteTypography.titleLarge)
                .foregroundStyle(colors.onSurface)
                .accessibilityIdentifier(WeatherScreenTags.weatherDescription)

            Group {
                if systemColorScheme == .dark {
                    Image(systemName: sfSymbolName)
                        .symbolRenderingMode(.multicolor)
                } else {
                    let palette = lightModePalette
                    Image(systemName: sfSymbolName)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(palette.primary, palette.secondary, palette.tertiary)
                }
            }
            .font(.system(size: iconSize))
            .frame(width: iconFrameSize, height: iconFrameSize)
            .accessibilityLabel("Weather Icon")

            Text("Temperature: \(tempValue)")
                .font(WeatherLiteTypography.bodyLarge)
                .foregroundStyle(colors.onSurface)
                .accessibilityIdentifier(WeatherScreenTags.weatherTemperature)

            Text("Observed at: \(data.observedAt)")
                .font(WeatherLiteTypography.bodySmall)
                .foregroundStyle(colors.onSurfaceVariant)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colors.surfaceVariant)
                .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(colors.outline.opacity(0.2), lineWidth: 0.5)
        )
    }
}
