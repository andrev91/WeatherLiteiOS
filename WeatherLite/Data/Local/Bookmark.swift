import Foundation

nonisolated struct Bookmark: Identifiable, Equatable, Hashable, Sendable {
    let bookmarkId: UUID
    let stateName: String
    let stateAbbreviation: String
    let cityName: String

    var id: UUID { bookmarkId }

    init(
        bookmarkId: UUID = UUID(),
        stateName: String,
        stateAbbreviation: String,
        cityName: String
    ) {
        self.bookmarkId = bookmarkId
        self.stateName = stateName
        self.stateAbbreviation = stateAbbreviation
        self.cityName = cityName
    }
}
