import SwiftUI

struct SettingsScreen: View {
    var viewModel: SettingsViewModel

    var body: some View {
        SettingsScreenContent(
            temperatureUnit: viewModel.temperatureUnit,
            onTemperatureUnitChanged: { unit in
                Task { await viewModel.setTemperatureUnit(unit) }
            },
            themeMode: viewModel.themeMode,
            onThemeModeChanged: { mode in
                Task { await viewModel.setThemeMode(mode) }
            }
        )
    }
}

struct SettingsScreenContent: View {
    let temperatureUnit: TemperatureUnit
    let onTemperatureUnitChanged: (TemperatureUnit) -> Void
    var themeMode: ThemeMode = .system
    var onThemeModeChanged: (ThemeMode) -> Void = { _ in }

    @Environment(\.weatherLiteColorScheme) private var colors

    private var selectedUnitBinding: Binding<TemperatureUnit> {
        Binding(
            get: { temperatureUnit },
            set: { newUnit in
                if newUnit != temperatureUnit {
                    onTemperatureUnitChanged(newUnit)
                }
            }
        )
    }

    private var selectedThemeBinding: Binding<ThemeMode> {
        Binding(
            get: { themeMode },
            set: { newMode in
                if newMode != themeMode {
                    onThemeModeChanged(newMode)
                }
            }
        )
    }

    var body: some View {
        Form {
            Section("Temperature Unit") {
                Picker("Temperature Unit", selection: selectedUnitBinding) {
                    ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                        Text(unit.displayName)
                            .tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Theme") {
                Picker("Theme", selection: selectedThemeBinding) {
                    ForEach(ThemeMode.allCases, id: \.self) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .scrollContentBackground(.hidden)
        .background(colors.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
