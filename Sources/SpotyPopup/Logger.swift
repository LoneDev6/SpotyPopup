import Foundation
import os.log

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.spotypopup"

    static let api = Logger(subsystem: subsystem, category: "API")
    static let auth = Logger(subsystem: subsystem, category: "Auth")
    static let playback = Logger(subsystem: subsystem, category: "Playback")

    static func error(_ message: String, category: Logger = api) {
        category.error("\(message, privacy: .public)")
    }

    static func info(_ message: String, category: Logger = api) {
        category.info("\(message, privacy: .public)")
    }

    static func debug(_ message: String, category: Logger = api) {
        category.debug("\(message, privacy: .public)")
    }
}
