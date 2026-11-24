import Foundation

/// Decides whether a path may ever be removed. Everything the cleaner touches
/// must live inside the home folder and must not be one of the folders the
/// categories are made of.
public enum SafetyGuard {
    static let protectedRoots = [
        "", "Library", "Library/Caches", "Library/Logs", "Library/Developer", "Library/Developer/Xcode",
        "Library/Developer/Xcode/DerivedData", "Library/Developer/Xcode/Archives", "Library/Developer/CoreSimulator",
        "Library/Application Support", "Library/Application Support/MobileSync",
        "Library/Application Support/MobileSync/Backup", "Library/Containers", "Library/Group Containers",
        "Library/Messages", "Library/Messages/Attachments", "Library/Mail", "Library/Mobile Documents",
        "Documents", "Desktop", "Downloads", "Pictures", "Movies", "Music", "Public", "Applications",
        ".Trash", ".ssh", ".gnupg", ".config",
    ]
    /// Inside these, single files are never removed: the owning app manages them.
    static let sealedFragments = ["/Library/Mail/", ".photoslibrary", "/Library/Keychains", "/Library/Mobile Documents/"]

    public static func allows(_ url: URL, home: URL = Paths.home) -> Bool {
        guard url.isFileURL else { return false }
        let homePath = home.standardizedFileURL.path(percentEncoded: false).trimmingTrailingSlash
        // Resolve links in the parent only: removing a link must never be judged by its target.
        let parent = url.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath()
        let path = parent.appending(path: url.lastPathComponent).path(percentEncoded: false).trimmingTrailingSlash
        guard !url.lastPathComponent.isEmpty, url.lastPathComponent != "..", path.hasPrefix(homePath + "/") else {
            return false
        }
        let relative = String(path.dropFirst(homePath.count + 1))
        if protectedRoots.contains(relative) { return false }
        return !sealedFragments.contains { (path + "/").contains($0) }
    }
}

public struct CleanReport: Sendable {
    public var deleted: Int64 = 0
    public var trashed: Int64 = 0
    public var deletedCount = 0
    public var trashedCount = 0
    public var failures: [Failure] = []

    public struct Failure: Sendable, Identifiable {
        public let id = UUID()
        public let name: String
        public let reason: String
    }
}

public enum Cleaner {
    @concurrent
    public static func banish(_ items: [DiskItem]) async -> CleanReport {
        let fm = FileManager()
        var report = CleanReport()
        for item in items where item.method != .none {
            guard SafetyGuard.allows(item.url) else {
                report.failures.append(.init(name: item.name, reason: "Protected location"))
                continue
            }
            do {
                switch item.method {
                case .delete:
                    try fm.removeItem(at: item.url)
                    report.deleted += item.size
                    report.deletedCount += 1
                case .trash:
                    try fm.trashItem(at: item.url, resultingItemURL: nil)
                    report.trashed += item.size
                    report.trashedCount += 1
                case .none:
                    break
                }
            } catch {
                report.failures.append(.init(name: item.name, reason: (error as NSError).localizedDescription))
            }
        }
        return report
    }
}

public enum RitualRunner {
    /// Runs a shell or admin ritual. URL and app rituals are opened by the app.
    @concurrent
    public static func run(_ kind: Ritual.Kind) async -> (ok: Bool, output: String) {
        let result: (status: Int32, output: String)?
        switch kind {
        case .shell(let command):
            result = FS.run("/bin/zsh", ["-lc", command])
        case .admin(let command):
            let script = "do shell script \"\(command)\" with administrator privileges"
            result = FS.run("/usr/bin/osascript", ["-e", script])
        case .openURL, .openApp:
            return (false, "Opened by the app")
        }
        guard let result else { return (false, "Could not start the command") }
        return (result.status == 0, result.output.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

extension String {
    var trimmingTrailingSlash: String {
        count > 1 && hasSuffix("/") ? String(dropLast()) : self
    }
}
