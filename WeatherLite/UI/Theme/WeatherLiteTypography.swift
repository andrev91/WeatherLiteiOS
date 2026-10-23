import SwiftUI

enum WeatherLiteTypography {
    static let heroTemperature = Font.system(.largeTitle, design: .rounded, weight: .thin)

    static let displayLarge = Font.largeTitle.weight(.bold)
    static let displayMedium = Font.largeTitle
    static let displaySmall = Font.title

    static let headlineLarge = Font.title
    static let headlineMedium = Font.title2.weight(.semibold)
    static let headlineSmall = Font.title3.weight(.semibold)

    static let titleLarge = Font.title2.weight(.semibold)
    static let titleMedium = Font.headline
    static let titleSmall = Font.subheadline.weight(.semibold)

    static let bodyLarge = Font.body
    static let bodyMedium = Font.subheadline
    static let bodySmall = Font.footnote

    static let labelLarge = Font.callout.weight(.medium)
    static let labelMedium = Font.caption.weight(.medium)
    static let labelSmall = Font.caption2.weight(.medium)
}
