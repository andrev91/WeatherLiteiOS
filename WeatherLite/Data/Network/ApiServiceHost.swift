import Foundation
import OSLog

enum ApiServiceError: LocalizedError, Equatable, Sendable {
    case missingApiKey(String)
    case invalidURL(String)
    case httpError(code: Int, message: String)
    case emptyResponse
    case decodingFailed(String)
    case networkUnavailable
    case custom(String)

    nonisolated var errorDescription: String? {
        switch self {
        case .missingApiKey(let msg):
            return msg
        case .invalidURL(let url):
            return String(localized: "Invalid URL: \(url)")
        case .httpError(let code, let message):
            return String(localized: "API Error: \(code) - \(message)")
        case .emptyResponse:
            return String(localized: "Received empty success response.")
        case .decodingFailed:
            return String(localized: "Failed to parse weather data.")
        case .networkUnavailable:
            return String(localized: "Network connection is unavailable.")
        case .custom(let message):
            return message
        }
    }
}

enum ApiServiceHost: CaseIterable, Equatable, Sendable {
    case accuWeather
    case openWeatherMap

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.tehuberz.WeatherLite",
        category: "ApiServiceHost"
    )

    nonisolated var baseUrl: String {
        switch self {
        case .accuWeather:
            return "https://dataservice.accuweather.com/"
        case .openWeatherMap:
            return "https://api.openweathermap.org/"
        }
    }

    nonisolated var apiKeyConfigName: String {
        switch self {
        case .accuWeather:
            return "ACCUWEATHER_API_KEY"
        case .openWeatherMap:
            return "OPEN_WEATHER_API_KEY"
        }
    }

    private static var activeHost: ApiServiceHost = .openWeatherMap

    static func setActive(_ host: ApiServiceHost) {
        activeHost = host
    }

    static func getActive() -> ApiServiceHost {
        activeHost
    }

    static func provideApiKey(
        bundle: Bundle = .main,
        infoDictionaryOverride: [String: Any]? = nil
    ) throws -> String {
        let host = getActive()
        let keyName = host.apiKeyConfigName
        let infoDict = infoDictionaryOverride ?? bundle.infoDictionary ?? [:]

        var resolvedKey: String? = (infoDict[keyName] as? String
            ?? infoDict["INFOPLIST_KEY_\(keyName)"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let candidate = resolvedKey, candidate.isEmpty || candidate.hasPrefix("$(") {
            resolvedKey = nil
        }

        if resolvedKey == nil && infoDictionaryOverride == nil {
            if let envValue = ProcessInfo.processInfo.environment[keyName]?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !envValue.isEmpty,
               !envValue.hasPrefix("$(") {
                resolvedKey = envValue
            }
        }

        if resolvedKey == nil && infoDictionaryOverride == nil {
            resolvedKey = resolveKeyFromSecretsConfig(keyName: keyName, bundle: bundle)
        }

        guard let apiKey = resolvedKey, !apiKey.isEmpty else {
            throw ApiServiceError.missingApiKey(
                String(localized: "API Key is not set in Info.plist or Secrets.xcconfig. Please add \(keyName).")
            )
        }

        let suffix = String(apiKey.suffix(4))
        logger.debug("Using API Key ending in ...\(suffix, privacy: .private)")

        return apiKey
    }

    private static func resolveKeyFromSecretsConfig(keyName: String, bundle: Bundle) -> String? {
        var candidateURLs: [URL] = []
        if let bundledURL = bundle.url(forResource: "Secrets", withExtension: "xcconfig") {
            candidateURLs.append(bundledURL)
        }
        let sourceRootSecrets = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Secrets.xcconfig")
        candidateURLs.append(sourceRootSecrets)

        for url in candidateURLs {
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for rawLine in contents.components(separatedBy: .newlines) {
                let line = rawLine.components(separatedBy: "//").first?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !line.isEmpty,
                      let equalsIndex = line.firstIndex(of: "=") else { continue }
                let k = line[..<equalsIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                let v = line[line.index(after: equalsIndex)...]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if k == keyName, !v.isEmpty, !v.hasPrefix("$(") {
                    return v
                }
            }
        }
        return nil
    }
}
