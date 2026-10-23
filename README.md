# WeatherLite (iOS)

**WeatherLite** is a lightweight, native iOS and iPadOS weather application built with **Swift 6** and **SwiftUI**. It lets users look up real-time weather conditions across US states and cities using the [OpenWeatherMap API](https://openweathermap.org/api), automatically resolve their nearest city via device GPS, save favorite locations as bookmarks, and customize display preferences.

## Features

- **State & City Search**: Browse or search across 50 US states and Washington, D.C. using searchable dropdown sheets with cities organized into **Major Cities** and **All Cities** sections.
- **Current Location Weather**: Detect the user's current coordinates via **CoreLocation** and reverse-geocode them to the nearest US state and city, complete with a contextual permission rationale flow and settings redirect.
- **Cache-First Coordinate Resolution**: Caches geocoded city coordinates locally with **SwiftData** so repeat lookups for previously searched cities skip redundant network geocoding calls.
- **Bookmarked Locations**: Save and manage favorite state/city pairs in a persistent bottom sheet with duplicate detection and swipe-to-delete support.
- **Customizable Preferences**: Switch between **Celsius (°C)** and **Fahrenheit (°F)** and toggle between **System**, **Light**, and **Dark** theme modes with reactive updates across the app.
- **Adaptive Theming & Custom UI**: Built with a custom Material-inspired color scheme (`AdventureColors` / `WeatherLiteTheme`), adaptive SF Symbols weather iconography, and a smooth 60 FPS `Canvas`-based animated loading orb (`WeatherLoadingOrb`).
- **Localization Ready**: Uses Xcode String Catalogs (`Localizable.xcstrings`) for user-facing strings and error messages.

## Tech Stack & Tools

| Category | Technology / Tool | Usage |
| :--- | :--- | :--- |
| **Language** | Swift 6.0 | Strict concurrency (`MainActor` default isolation, `Sendable`, `AsyncStream`) |
| **UI Framework** | SwiftUI | Declarative views, `NavigationStack`, custom environment theming, `Canvas` animations |
| **State Management** | `Observation` (`@Observable`) | Reactive state updates across ViewModels and SwiftUI views |
| **Local Database** | SwiftData | Persistent storage for `BookmarkRecord` and `CachedLocationRecord` (`@Model`) |
| **Preferences Storage** | `UserDefaults` | Persistence for temperature unit, theme mode, and location permission flags |
| **Networking** | `URLSession` & `Codable` | Async/await REST client (`URLSessionApiService`) for OpenWeatherMap endpoints |
| **Weather & Geocoding API** | OpenWeatherMap API | Current Weather (`data/2.5/weather`), Direct Geocoding (`geo/1.0/direct`), Reverse Geocoding (`geo/1.0/reverse`) |
| **Location Services** | CoreLocation | `CLLocationManager` wrapped with async/await continuations (`CoreLocationProvider`) |
| **Logging** | `OSLog` (`Logger`) | Structured network and database diagnostics |
| **Localization** | String Catalogs (`.xcstrings`) | Localized UI copy and error descriptions |
| **Unit Testing** | Swift Testing (`Testing`) | `@Suite`, `@Test`, and `#expect` assertions with in-memory SwiftData and `MockURLProtocol` |
| **UI Testing** | XCTest / XCUITest | End-to-end UI automation tests (`WeatherScreenUITests`) |

## Architecture & Project Structure

WeatherLite follows an **MVVM + Repository** architecture with unidirectional data flow and protocol-driven dependency injection managed by `AppDependencyContainer`:

```text
WeatherLite/
├── Info.plist                      # App configuration & API key interpolation variables
├── Secrets.xcconfig                # Local git-ignored API key configuration
├── WeatherLite/
│   ├── App/
│   │   ├── WeatherLiteApp.swift    # @main App entry point & NavigationStack root
│   │   ├── AppDependencyContainer.swift # Dependency injection container
│   │   └── AppRoute.swift          # Navigation routes (.weather, .settings)
│   ├── Data/
│   │   ├── Local/                  # SwiftData models & SwiftDataDatabaseStore
│   │   ├── Location/               # CoreLocationProvider & LocationProviderProtocol
│   │   ├── Models/                 # Domain models & Codable API DTOs
│   │   ├── Network/                # URLSessionApiService, ApiServiceHost, LocationRemoteDataSource
│   │   └── Repositories/           # WeatherRepository, LocationRepository, SettingsRepository
│   ├── Resources/
│   │   ├── Localizable.xcstrings   # String catalog for localization
│   │   ├── us_state.json           # Bundled list of US states & abbreviations
│   │   └── us_state_cities.json    # Bundled major and full city lists per state
│   ├── UI/
│   │   ├── Components/             # SearchableDropDown, WeatherDetailsCard, WeatherLoadingOrb, WeatherScaffold
│   │   ├── Screens/                # WeatherScreen & SettingsScreen
│   │   ├── State/                  # UI state models (WeatherUiState, WeatherDataPO, etc.)
│   │   └── Theme/                  # WeatherLiteTheme, AdventureColors, WeatherLiteTypography
│   └── ViewModels/
│       ├── WeatherViewModel.swift  # Main screen business logic & async state streams
│       └── SettingsViewModel.swift # Settings state management
├── WeatherLiteTests/               # Unit & integration tests (Swift Testing)
│   ├── DataLayerTests.swift
│   ├── SettingsViewModelTests.swift
│   └── WeatherTests.swift
└── WeatherLiteUITests/             # Automated UI tests (XCUITest)
    └── WeatherScreenUITests.swift
```

## Getting Started

### Prerequisites

- **macOS** with **Xcode 26.6+**
- **iOS 26.5+** Simulator or physical device
- An **OpenWeatherMap API Key** ([Sign up for a free key](https://home.openweathermap.org/users/sign_up))

### Installation & Configuration

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd WeatherLite
   ```

2. **Configure your API keys in `Secrets.xcconfig`**:
   `Secrets.xcconfig` is git-ignored to keep credentials out of source control. Create or update `Secrets.xcconfig` in the project root directory with your OpenWeatherMap API key:
   ```xcconfig
   // Secrets.xcconfig
   OPEN_WEATHER_API_KEY = your_openweather_api_key_here
   ACCUWEATHER_API_KEY =

   INFOPLIST_KEY_OPEN_WEATHER_API_KEY = $(OPEN_WEATHER_API_KEY)
   INFOPLIST_KEY_ACCUWEATHER_API_KEY = $(ACCUWEATHER_API_KEY)
   INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = WeatherLite needs your location to find the nearest city and its weather. No personal information is stored.
   ```
   > **Note**: `ApiServiceHost` resolves the active API key from `Info.plist` build settings (`$(OPEN_WEATHER_API_KEY)`), environment variables, or directly from `Secrets.xcconfig` during local development.

3. **Build and Run**:
   - Open `WeatherLite.xcodeproj` in Xcode.
   - Select the **WeatherLite** scheme and choose an iPhone or iPad simulator (or connected device).
   - Press **Cmd + R** to build and run.

## Running Tests

WeatherLite includes both unit tests (built with Apple's **Swift Testing** framework) and UI tests (built with **XCUITest**):

- **Run via Xcode**: Press **Cmd + U** to execute the full test suite (`WeatherLiteTests` and `WeatherLiteUITests`).
- **Run via Command Line**:
  ```bash
  xcodebuild test \
    -project WeatherLite.xcodeproj \
    -scheme WeatherLite \
    -destination 'platform=iOS Simulator,name=iPhone 16'
  ```

### Test Coverage Highlights

- **`DataLayerTests`**: Verifies bundled JSON asset decoding (`us_state.json`, `us_state_cities.json`), API key resolution, DTO-to-PO weather mapping, `URLSessionApiService` decoding via `MockURLProtocol`, SwiftData cache-first location lookup, and `UserDefaults` settings persistence.
- **`WeatherTests`**: Tests `WeatherViewModel` state transitions, state/city search filtering, bookmark creation/deletion and duplicate prevention, location permission flows, and current-location weather resolution.
- **`SettingsViewModelTests`**: Tests reactive temperature unit and theme mode updates.
- **`WeatherScreenUITests`**: End-to-end UI tests covering dropdown selection, city search, weather fetching, and refresh flows.

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.  
Copyright © 2026 Andre Vicente.
