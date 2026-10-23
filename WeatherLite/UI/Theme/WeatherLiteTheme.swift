import SwiftUI

private struct WeatherLiteColorSchemeKey: EnvironmentKey {
    static let defaultValue: WeatherLiteColorScheme = .light
}

private struct WeatherLitePreferredColorSchemeKey: EnvironmentKey {
    static let defaultValue: ColorScheme? = nil
}

extension EnvironmentValues {
    var weatherLiteColorScheme: WeatherLiteColorScheme {
        get { self[WeatherLiteColorSchemeKey.self] }
        set { self[WeatherLiteColorSchemeKey.self] = newValue }
    }

    var weatherLitePreferredColorScheme: ColorScheme? {
        get { self[WeatherLitePreferredColorSchemeKey.self] }
        set { self[WeatherLitePreferredColorSchemeKey.self] = newValue }
    }
}

struct WeatherLiteTheme<Content: View>: View {
    @Environment(\.colorScheme) private var systemColorScheme
    private let darkThemeOverride: Bool?
    private let content: () -> Content

    init(
        themeMode: ThemeMode,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.darkThemeOverride = themeMode.darkThemeOverride
        self.content = content
    }

    init(
        darkTheme: Bool? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.darkThemeOverride = darkTheme
        self.content = content
    }

    private var isDark: Bool {
        darkThemeOverride ?? (systemColorScheme == .dark)
    }

    private var scheme: WeatherLiteColorScheme {
        isDark ? .dark : .light
    }

    private var preferredScheme: ColorScheme? {
        darkThemeOverride.map { $0 ? .dark : .light }
    }

    var body: some View {
        content()
            .environment(\.weatherLiteColorScheme, scheme)
            .environment(\.weatherLitePreferredColorScheme, preferredScheme)
            .tint(scheme.primary)
            .preferredColorScheme(preferredScheme)
    }
}
