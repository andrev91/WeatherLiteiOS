import Foundation
import Testing
@testable import WeatherLite

@Suite("SettingsViewModel Tests")
struct SettingsViewModelTests {
    private let mockSettingsRepository: MockSettingsRepository
    private let viewModel: SettingsViewModel

    init() {
        mockSettingsRepository = MockSettingsRepository()
        viewModel = SettingsViewModel(settingsRepository: mockSettingsRepository)
    }

    @Test("Temperature unit initially reflects repository value and updates")
    func temperatureUnitInitiallyReflectsRepositoryValueAndUpdates() async {
        #expect(viewModel.temperatureUnit == .celsius)

        await mockSettingsRepository.setTemperatureUnit(.fahrenheit)

        #expect(viewModel.temperatureUnit == .fahrenheit)
    }

    @Test("Setting temperature unit calls repository")
    func setTemperatureUnitCallsRepository() async {
        await viewModel.setTemperatureUnit(.fahrenheit)

        #expect(mockSettingsRepository.setTemperatureUnitCalls == [.fahrenheit])
        #expect(viewModel.temperatureUnit == .fahrenheit)
    }

    @Test("Theme mode initially reflects repository value and updates")
    func themeModeInitiallyReflectsRepositoryValueAndUpdates() async {
        #expect(viewModel.themeMode == .system)

        await mockSettingsRepository.setThemeMode(.dark)

        #expect(viewModel.themeMode == .dark)
    }

    @Test("Setting theme mode calls repository")
    func setThemeModeCallsRepository() async {
        await viewModel.setThemeMode(.light)

        #expect(mockSettingsRepository.setThemeModeCalls == [.light])
        #expect(viewModel.themeMode == .light)
    }
}
