import Foundation
import OSLog
import SwiftData

@Model
nonisolated final class BookmarkRecord {
    @Attribute(.unique) var bookmarkId: UUID
    var stateName: String
    var stateAbbreviation: String
    var cityName: String

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

    var toDomain: Bookmark {
        Bookmark(
            bookmarkId: bookmarkId,
            stateName: stateName,
            stateAbbreviation: stateAbbreviation,
            cityName: cityName
        )
    }
}

@Model
nonisolated final class CachedLocationRecord {
    @Attribute(.unique) var name: String
    var latitude: Double
    var longitude: Double

    init(name: String, latitude: Double, longitude: Double) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }

    var toDomain: CachedLocation {
        CachedLocation(name: name, latitude: latitude, longitude: longitude)
    }
}

protocol LocalDatabaseStoreProtocol {
    func getCachedLocation(byName name: String) -> CachedLocation?
    @discardableResult
    func insertCachedLocation(name: String, latitude: Double, longitude: Double) -> CachedLocation
    func getAllBookmarks() -> [Bookmark]
    var bookmarksStream: AsyncStream<[Bookmark]> { get }
    func isBookmarkDuplicate(stateName: String, cityName: String) -> Bool
    func addBookmark(_ bookmark: Bookmark)
    func removeBookmark(_ bookmark: Bookmark)
}

final class SwiftDataDatabaseStore: LocalDatabaseStoreProtocol {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.tehuberz.WeatherLite",
        category: "SwiftDataDatabaseStore"
    )

    let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private var continuations: [UUID: AsyncStream<[Bookmark]>.Continuation] = [:]

    init(inMemory: Bool = false) {
        let schema = Schema([CachedLocationRecord.self, BookmarkRecord.self])
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(UUID().uuidString, schema: schema, isStoredInMemoryOnly: true)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }
        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [configuration])
            self.modelContext = ModelContext(modelContainer)
        } catch {
            fatalError("Failed to initialize SwiftData ModelContainer: \(error)")
        }
    }

    func getCachedLocation(byName name: String) -> CachedLocation? {
        let descriptor = FetchDescriptor<CachedLocationRecord>(
            predicate: #Predicate { $0.name == name }
        )
        do {
            return try modelContext.fetch(descriptor).first?.toDomain
        } catch {
            Self.logger.error("Failed to fetch cached location for \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    @discardableResult
    func insertCachedLocation(name: String, latitude: Double, longitude: Double) -> CachedLocation {
        let descriptor = FetchDescriptor<CachedLocationRecord>(
            predicate: #Predicate { $0.name == name }
        )
        if let existing = (try? modelContext.fetch(descriptor))?.first {
            existing.latitude = latitude
            existing.longitude = longitude
            saveContext()
            return existing.toDomain
        }
        let record = CachedLocationRecord(name: name, latitude: latitude, longitude: longitude)
        modelContext.insert(record)
        saveContext()
        return record.toDomain
    }

    func getAllBookmarks() -> [Bookmark] {
        let descriptor = FetchDescriptor<BookmarkRecord>(
            sortBy: [
                SortDescriptor(\BookmarkRecord.stateName, order: .forward),
                SortDescriptor(\BookmarkRecord.cityName, order: .forward)
            ]
        )
        do {
            return try modelContext.fetch(descriptor).map(\.toDomain)
        } catch {
            Self.logger.error("Failed to fetch bookmarks: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    var bookmarksStream: AsyncStream<[Bookmark]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [Bookmark].self)
        let id = UUID()
        continuations[id] = continuation
        continuation.yield(getAllBookmarks())
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.continuations.removeValue(forKey: id)
            }
        }
        return stream
    }

    func isBookmarkDuplicate(stateName: String, cityName: String) -> Bool {
        let descriptor = FetchDescriptor<BookmarkRecord>(
            predicate: #Predicate { $0.stateName == stateName && $0.cityName == cityName }
        )
        do {
            return try modelContext.fetchCount(descriptor) > 0
        } catch {
            Self.logger.error("Failed to check duplicate bookmark: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func addBookmark(_ bookmark: Bookmark) {
        guard !isBookmarkDuplicate(stateName: bookmark.stateName, cityName: bookmark.cityName) else {
            return
        }
        let record = BookmarkRecord(
            bookmarkId: bookmark.bookmarkId,
            stateName: bookmark.stateName,
            stateAbbreviation: bookmark.stateAbbreviation,
            cityName: bookmark.cityName
        )
        modelContext.insert(record)
        saveContext()
        notifyBookmarkSubscribers()
    }

    func removeBookmark(_ bookmark: Bookmark) {
        let targetState = bookmark.stateName
        let targetCity = bookmark.cityName
        do {
            try modelContext.delete(
                model: BookmarkRecord.self,
                where: #Predicate { $0.stateName == targetState && $0.cityName == targetCity }
            )
            saveContext()
        } catch {
            Self.logger.error("Failed to delete bookmark: \(error.localizedDescription, privacy: .public)")
        }
        notifyBookmarkSubscribers()
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Failed to save SwiftData context: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func notifyBookmarkSubscribers() {
        let current = getAllBookmarks()
        for continuation in continuations.values {
            continuation.yield(current)
        }
    }
}
