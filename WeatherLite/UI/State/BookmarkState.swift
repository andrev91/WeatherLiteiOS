import Foundation

nonisolated enum BookmarkState: Equatable, Sendable {
    case onSuccess(String)
    case onError(String)
    case onDelete(String)

    var message: String {
        switch self {
        case .onSuccess(let message),
             .onError(let message),
             .onDelete(let message):
            return message
        }
    }
}
