import Darwin
import Foundation

enum SpotifydInstallState: Equatable {
    case notInstalled
    case appManaged(path: String)
    case homebrew(path: String)
    case system(path: String)
}

enum SpotifydManager {
    private struct GitHubRelease: Decodable {
        let assets: [GitHubAsset]
    }

    private struct GitHubAsset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    static var managedExecutableURL: URL {
        applicationSupportURL.appendingPathComponent("bin/spotifyd")
    }

    private static let launchAgentIdentifier = "com.spotypopup.spotifyd"

    private static var launchAgentURL: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(launchAgentIdentifier).plist")
    }

    static var managedExecutablePath: String? {
        let path = managedExecutableURL.path
        return FileManager.default.isExecutableFile(atPath: path) ? path : nil
    }

    static func installState() -> SpotifydInstallState {
        if let path = managedExecutablePath {
            return .appManaged(path: path)
        }

        guard let path = commandOutput(["-lc", "command -v spotifyd"]) else {
            return .notInstalled
        }

        if path.contains("/homebrew/") || path.contains("/Cellar/") {
            return .homebrew(path: path)
        }

        return .system(path: path)
    }

    static func install() async throws -> SpotifydInstallState {
        let existing = installState()
        if existing != .notInstalled {
            try enableAutorun(for: existing)
            return existing
        }

        let asset = try await latestDarwinAsset()
        let archiveURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(asset.name)
        let extractURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("spotifyd-\(UUID().uuidString)")

        defer {
            try? FileManager.default.removeItem(at: archiveURL)
            try? FileManager.default.removeItem(at: extractURL)
        }

        let (downloadURL, _) = try await URLSession.shared.download(from: asset.browserDownloadURL)
        try FileManager.default.moveItem(at: downloadURL, to: archiveURL)
        try FileManager.default.createDirectory(at: extractURL, withIntermediateDirectories: true)
        try extractArchive(archiveURL, to: extractURL)

        let extractedBinary = try findExecutable(named: "spotifyd", under: extractURL)
        try FileManager.default.createDirectory(
            at: managedExecutableURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: managedExecutableURL.path) {
            try FileManager.default.removeItem(at: managedExecutableURL)
        }
        try FileManager.default.copyItem(at: extractedBinary, to: managedExecutableURL)
        try runProcess("/bin/chmod", arguments: ["755", managedExecutableURL.path])

        let state = SpotifydInstallState.appManaged(path: managedExecutableURL.path)
        try enableAutorun(for: state)
        return state
    }

    static func uninstall() async throws -> SpotifydInstallState {
        switch installState() {
        case .appManaged:
            try disableManagedLaunchAgent()
            try FileManager.default.removeItem(at: managedExecutableURL)
            return installState()
        case .homebrew:
            let brewPath = try ensureHomebrewInstalled()
            try? runProcess(brewPath, arguments: ["services", "stop", "spotifyd"])
            try runProcess(brewPath, arguments: ["uninstall", "spotifyd"])
            return installState()
        case .system(let path):
            throw NSError(
                domain: "SpotyPopup",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "spotifyd installed outside SpotyPopup: \(path)"]
            )
        case .notInstalled:
            return .notInstalled
        }
    }

    private static func enableAutorun(for state: SpotifydInstallState) throws {
        switch state {
        case .homebrew:
            let brewPath = try ensureHomebrewInstalled()
            try runProcess(brewPath, arguments: ["services", "start", "spotifyd"])
        case .appManaged(let path), .system(let path):
            try installLaunchAgent(executablePath: path)
        case .notInstalled:
            break
        }
    }

    private static func ensureHomebrewInstalled() throws -> String {
        if let path = brewExecutablePath() {
            return path
        }

        try installHomebrew()

        if let path = brewExecutablePath() {
            return path
        }

        throw NSError(
            domain: "SpotyPopup",
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: "Homebrew install completed, but brew was not found"]
        )
    }

    private static func brewExecutablePath() -> String? {
        if let path = commandOutput(["-lc", "command -v brew"]) {
            return path
        }

        for path in ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"] {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }

    private static func installHomebrew() throws {
        try runProcess("/bin/zsh", arguments: [
            "-lc",
            "NONINTERACTIVE=1 /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        ])
    }

    private static func installLaunchAgent(executablePath: String) throws {
        let launchAgentsURL = launchAgentURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: launchAgentsURL, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label": launchAgentIdentifier,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": true,
            "StandardOutPath": "/tmp/spotypopup.spotifyd.out.log",
            "StandardErrorPath": "/tmp/spotypopup.spotifyd.err.log",
            "WorkingDirectory": applicationSupportURL.path
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: launchAgentURL, options: .atomic)

        let domain = launchctlDomain
        try? runProcess("/bin/launchctl", arguments: ["bootout", domain, launchAgentURL.path])
        try runProcess("/bin/launchctl", arguments: ["bootstrap", domain, launchAgentURL.path])
        try? runProcess("/bin/launchctl", arguments: ["enable", "\(domain)/\(launchAgentIdentifier)"])
        try? runProcess("/bin/launchctl", arguments: ["kickstart", "-k", "\(domain)/\(launchAgentIdentifier)"])
    }

    private static func disableManagedLaunchAgent() throws {
        let domain = launchctlDomain
        try? runProcess("/bin/launchctl", arguments: ["bootout", domain, launchAgentURL.path])

        if FileManager.default.fileExists(atPath: launchAgentURL.path) {
            try FileManager.default.removeItem(at: launchAgentURL)
        }
    }

    private static var launchctlDomain: String {
        "gui/\(getuid())"
    }

    private static var applicationSupportURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL.appendingPathComponent("SpotyPopup", isDirectory: true)
    }

    private static func latestDarwinAsset() async throws -> GitHubAsset {
        let releaseURL = URL(string: "https://api.github.com/repos/Spotifyd/spotifyd/releases/latest")!
        let (data, _) = try await URLSession.shared.data(from: releaseURL)
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let machine = commandOutput(["-lc", "uname -m"]) ?? ""
        let architecture = machine == "arm64" ? "aarch64" : "x86_64"

        if let exact = release.assets.first(where: { asset in
            let name = asset.name.lowercased()
            return isSupportedArchiveAsset(name)
                && name.contains(architecture)
                && name.contains("apple-darwin")
        }) {
            return exact
        }

        if let fallback = release.assets.first(where: { asset in
            let name = asset.name.lowercased()
            return isSupportedArchiveAsset(name)
                && (name.contains("apple-darwin") || name.contains("darwin") || name.contains("macos"))
        }) {
            return fallback
        }

        throw NSError(
            domain: "SpotyPopup",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "No macOS spotifyd release asset found"]
        )
    }

    private static func findExecutable(named name: String, under directory: URL) throws -> URL {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw NSError(
                domain: "SpotyPopup",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Could not read extracted archive"]
            )
        }

        for case let url as URL in enumerator where url.lastPathComponent == name {
            return url
        }

        throw NSError(
            domain: "SpotyPopup",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "spotifyd binary not found in archive"]
        )
    }

    private static func commandOutput(_ arguments: [String]) -> String? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let value = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    private static func runProcess(_ path: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "SpotyPopup",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "\(path) failed"]
            )
        }
    }

    private static func extractArchive(_ archiveURL: URL, to extractURL: URL) throws {
        let name = archiveURL.lastPathComponent.lowercased()
        if name.hasSuffix(".zip") {
            try runProcess("/usr/bin/unzip", arguments: ["-q", archiveURL.path, "-d", extractURL.path])
        } else {
            try runProcess("/usr/bin/tar", arguments: ["-xzf", archiveURL.path, "-C", extractURL.path])
        }
    }

    private static func isSupportedArchiveAsset(_ name: String) -> Bool {
        name.hasSuffix(".tar.gz") || name.hasSuffix(".tgz") || name.hasSuffix(".zip")
    }
}
