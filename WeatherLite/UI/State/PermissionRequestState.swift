import Foundation

nonisolated enum PermissionRequestState: Equatable, Sendable {
    case none
    case explanation
    case settings
}
