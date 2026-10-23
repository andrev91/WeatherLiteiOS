import Foundation

protocol SettingsRepositoryProtocol {
    var currentTemperatureUnit: TemperatureUnit { get }
    var temperatureUnitStream: AsyncStream<TemperatureUnit> { get }
    func setTemperatureUnit(_ unit: TemperatureUnit) async

    var currentThemeMode: ThemeMode { get }
    var themeModeStream: AsyncStream<ThemeMode> { get }
    func setThemeMode(_ mode: ThemeMode) async

    var currentLocationPermissionRequested: Bool { get }
    var locationPermissionRequestedStream: AsyncStream<Bool> { get }
    func setLocationPermissionRequested(_ requested: Bool) async
}

final class SettingsRepository: SettingsRepositoryProtocol {
    static let unitKey = "temperature_unit"
    static let themeModeKey = "theme_mode"
    static let locationPermissionRequestedKey = "location_permission_requested"
    static let locationExplanationAcceptedKey = "location_explanation_accepted"

    private let userDefaults: UserDefaults
    private var unitContinuations: [UUID: AsyncStream<TemperatureUnit>.Continuation] = [:]
    private var themeContinuations: [UUID: AsyncStream<ThemeMode>.Continuation] = [:]
    private var permissionContinuations: [UUID: AsyncStream<Bool>.Continuation] = [:]

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var currentTemperatureUnit: TemperatureUnit {
        guard let rawValue = userDefaults.string(forKey: Self.unitKey),
              let unit = TemperatureUnit(rawValue: rawValue) else {
            return .celsius
        }
        return unit
    }

    var temperatureUnitStream: AsyncStream<TemperatureUnit> {
        let (stream, continuation) = AsyncStream.makeStream(of: TemperatureUnit.self)
        let id = UUID()
        unitContinuations[id] = continuation
        continuation.yield(currentTemperatureUnit)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.unitContinuations.removeValue(forKey: id)
            }
        }
        return stream
    }

    func setTemperatureUnit(_ unit: TemperatureUnit) async {
        userDefaults.set(unit.rawValue, forKey: Self.unitKey)
        for continuation in unitContinuations.values {
            continuation.yield(unit)
        }
        for _ in 0..<5 {
            await Task.yield()
        }
    }

    var currentThemeMode: ThemeMode {
        guard let rawValue = userDefaults.string(forKey: Self.themeModeKey),
              let mode = ThemeMode(rawValue: rawValue) else {
            return .system
        }
        return mode
    }

    var themeModeStream: AsyncStream<ThemeMode> {
        let (stream, continuation) = AsyncStream.makeStream(of: ThemeMode.self)
        let id = UUID()
        themeContinuations[id] = continuation
        continuation.yield(currentThemeMode)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.themeContinuations.removeValue(forKey: id)
            }
        }
        return stream
    }

    func setThemeMode(_ mode: ThemeMode) async {
        userDefaults.set(mode.rawValue, forKey: Self.themeModeKey)
        for continuation in themeContinuations.values {
            continuation.yield(mode)
        }
        for _ in 0..<5 {
            await Task.yield()
        }
    }

    var currentLocationPermissionRequested: Bool {
        if userDefaults.object(forKey: Self.locationPermissionRequestedKey) != nil {
            return userDefaults.bool(forKey: Self.locationPermissionRequestedKey)
        }
        if userDefaults.object(forKey: Self.locationExplanationAcceptedKey) != nil {
            return userDefaults.bool(forKey: Self.locationExplanationAcceptedKey)
        }
        return false
    }

    var locationPermissionRequestedStream: AsyncStream<Bool> {
        let (stream, continuation) = AsyncStream.makeStream(of: Bool.self)
        let id = UUID()
        permissionContinuations[id] = continuation
        continuation.yield(currentLocationPermissionRequested)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.permissionContinuations.removeValue(forKey: id)
            }
        }
        return stream
    }

    func setLocationPermissionRequested(_ requested: Bool) async {
        userDefaults.set(requested, forKey: Self.locationPermissionRequestedKey)
        userDefaults.set(requested, forKey: Self.locationExplanationAcceptedKey)
        for continuation in permissionContinuations.values {
            continuation.yield(requested)
        }
        for _ in 0..<5 {
            await Task.yield()
        }
    }
}
