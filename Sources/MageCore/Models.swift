import Foundation

/// Every place on a Mac where disk space tends to hide.
public enum CategoryID: String, CaseIterable, Sendable, Codable, Identifiable {
    case trash, userCaches, logs, xcode, devCaches, iosBackups, mail, messages
    case downloads, largeFiles, snapshots, docker, system

    public var id: String { rawValue }
}

/// What banishing an item actually does.
public enum CleanMethod: Sendable, Hashable {
    /// Rebuildable data (caches, logs, build products): removed for good.
    case delete
    /// The user's own files: moved to the Trash so they can be restored.
    case trash
    /// Shown for understanding only; the app never touches it.
    case none
}

/// How safe a category is to clean without looking.
public enum Verdict: Sendable {
    case safe, review, guided, info
}

public struct DiskItem: Identifiable, Sendable, Hashable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let size: Int64
    public let modified: Date?
    public let method: CleanMethod
    public let preselected: Bool
    public let detail: String?

    public init(
        url: URL, name: String, size: Int64, modified: Date? = nil,
        method: CleanMethod, preselected: Bool = false, detail: String? = nil
    ) {
        self.url = url
        self.name = name
        self.size = size
        self.modified = modified
        self.method = method
        self.preselected = preselected && method != .none
        self.detail = detail
    }
}

public struct CategoryResult: Identifiable, Sendable {
    public let id: CategoryID
    public let items: [DiskItem]
    /// Total space the category occupies. Can exceed the sum of `items`
    /// when only the largest entries are listed (Messages attachments).
    public let measured: Int64
    public let note: String?
    public let accessDenied: Bool

    public init(id: CategoryID, items: [DiskItem], measured: Int64? = nil, note: String? = nil, accessDenied: Bool = false) {
        self.id = id
        self.items = items
        self.measured = measured ?? items.reduce(0) { $0 + $1.size }
        self.note = note
        self.accessDenied = accessDenied
    }

    public var cleanable: Int64 {
        items.filter { $0.method != .none }.reduce(0) { $0 + $1.size }
    }
}

/// A one-click fix the app runs for a category, such as thinning snapshots.
public struct Ritual: Sendable {
    public enum Kind: Sendable {
        case shell(String)
        case admin(String)
        case openURL(String)
        case openApp(bundleID: String)
    }

    public let label: String
    public let kind: Kind
    /// Shown in a confirmation before the ritual runs. `nil` runs it directly.
    public let warning: String?

    public init(label: String, kind: Kind, warning: String? = nil) {
        self.label = label
        self.kind = kind
        self.warning = warning
    }
}

public struct VolumeInfo: Sendable {
    public let total: Int64
    /// Free right now.
    public let available: Int64
    /// Free once macOS releases purgeable space (snapshots, iCloud cache).
    public let availableForImportant: Int64

    public var purgeable: Int64 { max(0, availableForImportant - available) }
    /// Space that is really taken, purgeable excluded.
    public var used: Int64 { max(0, total - availableForImportant) }

    public init(total: Int64, available: Int64, availableForImportant: Int64) {
        self.total = total
        self.available = available
        self.availableForImportant = availableForImportant
    }

    public static func read(_ url: URL = URL(filePath: "/")) -> VolumeInfo? {
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
        ]
        guard let v = try? url.resourceValues(forKeys: keys), let total = v.volumeTotalCapacity else { return nil }
        let available = Int64(v.volumeAvailableCapacity ?? 0)
        return VolumeInfo(
            total: Int64(total),
            available: available,
            availableForImportant: v.volumeAvailableCapacityForImportantUsage ?? available
        )
    }
}

public extension Int64 {
    var bytesText: String { formatted(.byteCount(style: .file)) }
}
