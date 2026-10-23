import Foundation

nonisolated struct LocationSelectionState: Equatable, Sendable {
    var isLoadingStates: Bool = false
    var availableStates: [USState] = []
    var selectedState: USState? = nil
    var stateSearchQuery: String = ""
    var filteredStates: [USState] = []
    var isLoadingCities: Bool = false
    var availableCities: [String] = []
    var majorCities: [String] = []
    var allCities: [String] = []
    var selectedCity: String? = nil
    var citySearchQuery: String = ""
    var filteredCities: [String] = []

    var displayedStates: [USState] {
        let trimmed = stateSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || (trimmed == selectedState?.name && filteredStates == availableStates) {
            return availableStates
        }
        return filteredStates
    }

    var displayedCities: [String] {
        let trimmed = citySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || (trimmed == selectedCity && filteredCities.isEmpty) {
            return availableCities
        }
        return filteredCities
    }

    var showCityDropdown: Bool {
        selectedState != nil && (!availableCities.isEmpty || !allCities.isEmpty || !majorCities.isEmpty)
    }

    var canBookmark: Bool {
        selectedState != nil && selectedCity != nil
    }
}
