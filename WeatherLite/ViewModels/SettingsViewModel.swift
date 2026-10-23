import Foundation
import Observation

@Observable
final class SettingsViewModel {
    private(set) var temperatureUnit: TemperatureUnit
    private(set) var themeMode: ThemeMode

    private let settingsRepository: SettingsRepositoryProtocol
    @ObservationIgnored
    private var observationTask: Task<Void, Never>?
    @ObservationIgnored
    private var themeObservationTask: Task<Void, Never>?

    init(settingsRepository: SettingsRepositoryProtocol) {
        self.settingsRepository = settingsRepository
        self.temperatureUnit = settingsRepository.currentTemperatureUnit
        self.themeMode = settingsRepository.currentThemeMode

        let unitStream = settingsRepository.temperatureUnitStream
        let themeStream = settingsRepository.themeModeStream

        self.observationTask = Task { [weak self] in
            guard let self else { return }
            for await unit in unitStream {
                guard !Task.isCancelled else { break }
                self.temperatureUnit = unit
            }
        }

        self.themeObservationTask = Task { [weak self] in
            guard let self else { return }
            for await mode in themeStream {
                guard !Task.isCancelled else { break }
                self.themeMode = mode
            }
        }
    }

    isolated deinit {
        observationTask?.cancel()
        themeObservationTask?.cancel()
    }

    func setTemperatureUnit(_ unit: TemperatureUnit) async {
        temperatureUnit = unit
        await settingsRepository.setTemperatureUnit(unit)
    }

    func setThemeMode(_ mode: ThemeMode) async {
        themeMode = mode
        await settingsRepository.setThemeMode(mode)
    }
}
