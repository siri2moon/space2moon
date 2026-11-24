import Foundation

/// One saved scan, so the next one can say what grew.
public struct ScanSnapshot: Codable, Sendable {
    public let date: Date
    public let used: Int64
    public let available: Int64
    public let totals: [String: Int64]

    public init(date: Date, used: Int64, available: Int64, totals: [String: Int64]) {
        self.date = date
        self.used = used
        self.available = available
        self.totals = totals
    }
}

/// Scan history in Application Support.
public enum Chronicle {
    static var fileURL: URL {
        URL.applicationSupportDirectory.appending(path: "Space2Moon/history.json")
    }

    public static func load() -> [ScanSnapshot] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([ScanSnapshot].self, from: data)) ?? []
    }

    public static func append(_ snapshot: ScanSnapshot, keep: Int = 120) {
        var all = load()
        all.append(snapshot)
        all = Array(all.suffix(keep))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(all) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }

    /// The newest snapshot at least `minAge` old, so a rescan right after
    /// cleaning still compares against a meaningful baseline.
    public static func baseline(in history: [ScanSnapshot], now: Date = .now, minAge: TimeInterval = 12 * 3600) -> ScanSnapshot? {
        history.last { now.timeIntervalSince($0.date) >= minAge }
    }
}

public struct Insight: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let size: Int64
    public let growth: Int64?
    public let category: CategoryID?
}

/// Turns a scan into the answer to "why is my disk full?".
public enum Oracle {
    public static func divine(
        results: [CategoryID: CategoryResult], volume: VolumeInfo?, baseline: ScanSnapshot?, limit: Int = 7
    ) -> [Insight] {
        var insights: [Insight] = []
        for (id, result) in results where id != .system && id != .snapshots && result.measured > 0 {
            let info = Grimoire.info(id)
            let growth = baseline?.totals[id.rawValue].map { result.measured - $0 }
            insights.append(Insight(
                id: id.rawValue, title: info.title, detail: firstSentence(info.lore),
                size: result.measured, growth: growth, category: id))
        }
        for item in results[.system]?.items ?? [] {
            insights.append(Insight(
                id: "system:\(item.name)", title: item.name, detail: item.detail ?? "Managed by macOS",
                size: item.size, growth: nil, category: .system))
        }
        if let volume, volume.purgeable > 1_000_000_000 {
            insights.append(Insight(
                id: "purgeable", title: "Purgeable space",
                detail: "Snapshots and iCloud caches macOS frees only when space runs out",
                size: volume.purgeable, growth: nil, category: .snapshots))
        }
        return Array(insights.sorted { $0.size > $1.size }.prefix(limit))
    }

    public static func snapshot(results: [CategoryID: CategoryResult], volume: VolumeInfo?, date: Date = .now) -> ScanSnapshot {
        ScanSnapshot(
            date: date, used: volume?.used ?? 0, available: volume?.available ?? 0,
            totals: Dictionary(uniqueKeysWithValues: results.map { ($0.key.rawValue, $0.value.measured) }))
    }

    static func firstSentence(_ text: String) -> String {
        guard let end = text.firstIndex(of: ".") else { return text }
        return String(text[...end])
    }
}
