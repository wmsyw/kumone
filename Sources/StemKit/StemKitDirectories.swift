import Foundation

/// Shared root for persistent models and Metal resources; resolved without creating it.
enum StemKitDirectories {
    static let applicationSupport = URL.applicationSupportDirectory
        .appendingPathComponent("Kumone", isDirectory: true)
}
