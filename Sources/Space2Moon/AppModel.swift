import AppKit
import MageCore
import SwiftUI

@Observable
final class AppModel {
    var volume: VolumeInfo?
    var results: [CategoryID: CategoryResult] = [:]
    var scanning: Set<CategoryID> = []
    var selection: Set<URL> = []
    var focused: CategoryID?
    var insights: [Insight] = []
    var baseline: ScanSnapshot?
    var hasFullDiskAccess = true
    var confirming = false
    var banishing = false
    var lastReport: CleanReport?
    var ritualRunning: CategoryID?
    var ritualMessage: String?
    var showSplash = true

    func finishSplash() {
        guard showSplash else { return }
        withAnimation(.easeInOut(duration: 0.7)) { showSplash = false }
    }

    var isScanning: Bool { !scanning.isEmpty }

    /// Show the Full Disk Access banner only while something is actually locked.
    var needsSight: Bool {
        guard !hasFullDiskAccess else { return false }
        return results.isEmpty || results.values.contains(where: \.accessDenied)
    }

    /// Called when the app becomes active again, typically after a visit to
    /// System Settings: if access was granted, rescan what was locked.
    func recheckAccess() async {
        let granted = Access.hasFullDiskAccess()
        guard granted != hasFullDiskAccess else { return }
        withAnimation(.smooth) { hasFullDiskAccess = granted }
        let locked = results.filter(\.value.accessDenied).map(\.key)
        if granted, !locked.isEmpty { await scan(locked) }
    }

    /// macOS often applies Full Disk Access only to a fresh process.
    func relaunch() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }

    /// Items that are selected and can actually be removed.
    var chosen: [DiskItem] {
        results.values.flatMap(\.items).filter { $0.method != .none && selection.contains($0.url) }
    }

    var chosenBytes: Int64 { chosen.reduce(0) { $0 + $1.size } }

    func selectedBytes(in id: CategoryID) -> Int64 {
        (results[id]?.items ?? []).filter { $0.method != .none && selection.contains($0.url) }.reduce(0) { $0 + $1.size }
    }

    // MARK: - Scanning

    func scan(_ ids: [CategoryID] = CategoryID.allCases) async {
        guard scanning.isEmpty else { return }
        hasFullDiskAccess = Access.hasFullDiskAccess()
        volume = VolumeInfo.read()
        scanning = Set(ids)
        await withTaskGroup(of: CategoryResult.self) { group in
            for id in ids {
                group.addTask { await Scanner.scan(id) }
            }
            for await result in group {
                let old = Set(results[result.id]?.items.map(\.url) ?? [])
                selection.subtract(old)
                selection.formUnion(result.items.filter(\.preselected).map(\.url))
                withAnimation(.smooth(duration: 0.45)) {
                    results[result.id] = result
                    scanning.remove(result.id)
                }
            }
        }
        volume = VolumeInfo.read()
        let history = Chronicle.load()
        baseline = Chronicle.baseline(in: history)
        withAnimation(.smooth) {
            insights = Oracle.divine(results: results, volume: volume, baseline: baseline)
        }
        if ids.count == CategoryID.allCases.count {
            Chronicle.append(Oracle.snapshot(results: results, volume: volume))
        }
    }

    // MARK: - Gauge

    var segments: [GaugeSegment] {
        guard let volume, volume.total > 0 else { return [] }
        let total = Double(volume.total)
        let shown = CategoryID.allCases.filter { $0 != .system && $0 != .snapshots }
        var segments: [GaugeSegment] = []
        var counted: Int64 = 0
        for id in shown {
            let size = results[id]?.measured ?? 0
            guard size > 0 else { continue }
            counted += size
            segments.append(GaugeSegment(id: id.rawValue, fraction: Double(size) / total, color: Arcana.color(id)))
        }
        let other = max(0, volume.used - counted)
        segments.append(GaugeSegment(id: "other", fraction: Double(other) / total, color: Arcana.violet.opacity(0.32)))
        segments.append(GaugeSegment(id: "purgeable", fraction: Double(volume.purgeable) / total, color: Arcana.gold.opacity(0.55)))
        return segments
    }

    // MARK: - Selection

    func toggle(_ item: DiskItem) {
        guard item.method != .none else { return }
        if selection.contains(item.url) { selection.remove(item.url) } else { selection.insert(item.url) }
    }

    func selectAll(_ id: CategoryID, _ on: Bool) {
        let urls = (results[id]?.items ?? []).filter { $0.method != .none }.map(\.url)
        if on { selection.formUnion(urls) } else { selection.subtract(urls) }
    }

    func focus(_ id: CategoryID?) {
        withAnimation(.spring(duration: 0.42, bounce: 0.12)) { focused = id }
    }

    // MARK: - Banishing

    func banish() async {
        let items = chosen
        guard !items.isEmpty else { return }
        banishing = true
        let report = await Cleaner.banish(items)
        let touched = Set(items.compactMap { item in
            results.first { $0.value.items.contains(item) }?.key
        })
        selection.subtract(items.map(\.url))
        banishing = false
        withAnimation(.spring(duration: 0.5)) { lastReport = report }
        await scan(Array(touched.union([.trash])))
    }

    func emptyTrashAfterReport() async {
        lastReport = nil
        selectAll(.trash, true)
        confirming = true
    }

    // MARK: - Rituals

    func perform(_ ritual: Ritual, for id: CategoryID) async {
        switch ritual.kind {
        case .openURL(let string):
            if let url = URL(string: string) { NSWorkspace.shared.open(url) }
        case .openApp(let bundleID):
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
            }
        case .shell, .admin:
            ritualRunning = id
            let result = await RitualRunner.run(ritual.kind)
            ritualRunning = nil
            let tail = result.output.split(separator: "\n").suffix(2).joined(separator: " ")
            ritualMessage = result.ok
                ? "The ritual is complete. \(tail)"
                : "The ritual failed: \(tail.isEmpty ? "unknown error" : tail)"
            await scan([id])
        }
    }

    func openFullDiskAccess() {
        if let url = URL(string: Grimoire.fullDiskAccessSettings) { NSWorkspace.shared.open(url) }
    }

    func revealApp() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    func reveal(_ item: DiskItem) {
        guard item.url.isFileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
}
