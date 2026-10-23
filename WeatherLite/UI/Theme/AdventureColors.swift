import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct WeatherLiteColorScheme: Sendable {
    let primary: Color
    let onPrimary: Color
    let primaryContainer: Color
    let onPrimaryContainer: Color
    let secondary: Color
    let onSecondary: Color
    let secondaryContainer: Color
    let onSecondaryContainer: Color
    let tertiary: Color
    let onTertiary: Color
    let tertiaryContainer: Color
    let onTertiaryContainer: Color
    let background: Color
    let onBackground: Color
    let surface: Color
    let onSurface: Color
    let surfaceVariant: Color
    let onSurfaceVariant: Color
    let error: Color
    let onError: Color
    let outline: Color

    static let light = WeatherLiteColorScheme(
        primary: Color(hex: 0x0061A4),
        onPrimary: .white,
        primaryContainer: Color(hex: 0xD1E4FF),
        onPrimaryContainer: Color(hex: 0x001D36),
        secondary: Color(hex: 0x535F70),
        onSecondary: .white,
        secondaryContainer: Color(uiColor: .secondarySystemFill),
        onSecondaryContainer: Color(uiColor: .label),
        tertiary: Color(uiColor: .systemOrange),
        onTertiary: .white,
        tertiaryContainer: Color(uiColor: .tertiarySystemFill),
        onTertiaryContainer: Color(uiColor: .label),
        background: Color(uiColor: .systemGroupedBackground),
        onBackground: Color(uiColor: .label),
        surface: Color(uiColor: .secondarySystemGroupedBackground),
        onSurface: Color(uiColor: .label),
        surfaceVariant: Color(uiColor: .secondarySystemGroupedBackground),
        onSurfaceVariant: Color(uiColor: .secondaryLabel),
        error: Color(uiColor: .systemRed),
        onError: .white,
        outline: Color(uiColor: .separator)
    )

    static let dark = WeatherLiteColorScheme(
        primary: Color(hex: 0xA8C7FA),
        onPrimary: Color(hex: 0x062E6F),
        primaryContainer: Color(hex: 0x00497D),
        onPrimaryContainer: Color(hex: 0xD1E4FF),
        secondary: Color(hex: 0xBBC7DB),
        onSecondary: Color(hex: 0x253140),
        secondaryContainer: Color(uiColor: .secondarySystemFill),
        onSecondaryContainer: Color(uiColor: .label),
        tertiary: Color(uiColor: .systemOrange),
        onTertiary: .black,
        tertiaryContainer: Color(uiColor: .tertiarySystemFill),
        onTertiaryContainer: Color(uiColor: .label),
        background: Color(uiColor: .systemGroupedBackground),
        onBackground: Color(uiColor: .label),
        surface: Color(uiColor: .secondarySystemGroupedBackground),
        onSurface: Color(uiColor: .label),
        surfaceVariant: Color(hex: 0x282A2F),
        onSurfaceVariant: Color(uiColor: .secondaryLabel),
        error: Color(uiColor: .systemRed),
        onError: .white,
        outline: Color(uiColor: .separator)
    )
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
