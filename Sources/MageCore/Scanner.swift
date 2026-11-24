import Foundation

/// Measures one category at a time, off the main actor.
public enum Scanner {
    @concurrent
    public static func scan(_ id: CategoryID) async -> CategoryResult {
        switch id {
        case .trash:
            children(id, of: Paths.home(".Trash"), method: .delete) { _ in true }
        case .userCaches:
            children(id, of: Paths.home("Library/Caches"), method: .delete) {
                !$0.lastPathComponent.hasPrefix("com.apple.")
            }
        case .logs:
            children(id, of: Paths.home("Library/Logs"), method: .delete) { _ in true }
        case .xcode: xcode()
        case .devCaches: devCaches()
        case .iosBackups: iosBackups()
        case .mail: mail()
        case .messages: messages()
        case .downloads: downloads()
        case .largeFiles: largeFiles()
        case .snapshots: snapshots()
        case .docker: docker()
        case .system: system()
        }
    }

    // MARK: - Building blocks

    static func children(
        _ id: CategoryID, of dir: URL, method: CleanMethod, minSize: Int64 = 1,
        preselect: (URL) -> Bool
    ) -> CategoryResult {
        switch FS.list(dir) {
        case .missing: return CategoryResult(id: id, items: [])
        case .denied: return CategoryResult(id: id, items: [], accessDenied: true)
        case .ok(let urls):
            let items = urls.compactMap { url -> DiskItem? in
                let size = FS.size(of: url)
                guard size >= minSize else { return nil }
                return DiskItem(
                    url: url, name: url.lastPathComponent, size: size, modified: FS.modified(url),
                    method: method, preselected: preselect(url))
            }
            return CategoryResult(id: id, items: items.sorted { $0.size > $1.size })
        }
    }

    static func item(_ url: URL, _ name: String, _ method: CleanMethod, preselected: Bool = true, detail: String? = nil) -> DiskItem? {
        guard FS.exists(url) else { return nil }
        let size = FS.size(of: url)
        guard size > 0 else { return nil }
        return DiskItem(
            url: url, name: name, size: size, modified: FS.modified(url), method: method,
            preselected: preselected, detail: detail ?? FS.abbreviate(url))
    }

    static func childItems(_ dir: URL, _ method: CleanMethod, preselected: Bool, detail: String) -> [DiskItem] {
        guard case .ok(let urls) = FS.list(dir) else { return [] }
        return urls.compactMap { item($0, $0.lastPathComponent, method, preselected: preselected, detail: detail) }
    }

    // MARK: - Categories

    static func xcode() -> CategoryResult {
        let dev = Paths.home("Library/Developer")
        var items: [DiskItem] = []
        items += childItems(dev.appending(path: "Xcode/DerivedData"), .delete, preselected: true, detail: "DerivedData")
        for platform in ["iOS", "watchOS", "tvOS", "visionOS", "macOS"] {
            items += childItems(
                dev.appending(path: "Xcode/\(platform) DeviceSupport"), .delete, preselected: true,
                detail: "\(platform) device support")
        }
        items += [
            item(dev.appending(path: "CoreSimulator/Caches"), "Simulator caches", .delete),
            item(dev.appending(path: "Xcode/UserData/Previews"), "SwiftUI preview data", .delete),
            item(dev.appending(path: "CoreSimulator/Devices"), "Simulator devices", .none,
                 detail: "Use the ritual to remove simulators of runtimes you no longer have"),
        ].compactMap { $0 }
        items += childItems(dev.appending(path: "Xcode/Archives"), .trash, preselected: false, detail: "Archives")
        return CategoryResult(id: .xcode, items: items.sorted { $0.size > $1.size })
    }

    static func devCaches() -> CategoryResult {
        let candidates: [(String, String, CleanMethod, Bool)] = [
            (".npm/_cacache", "npm cache", .delete, true),
            ("Library/pnpm/store", "pnpm store", .delete, true),
            (".pnpm-store", "pnpm store", .delete, true),
            (".yarn/berry/cache", "Yarn cache", .delete, true),
            (".bun/install/cache", "Bun cache", .delete, true),
            (".gradle/caches", "Gradle caches", .delete, true),
            (".cargo/registry/cache", "Cargo downloads", .delete, true),
            (".cocoapods/repos", "CocoaPods spec repos", .delete, true),
            (".cache/pip", "pip cache", .delete, true),
            (".cache/uv", "uv cache", .delete, true),
            (".m2/repository", "Maven repository", .delete, false),
            (".cache/huggingface", "Hugging Face models", .trash, false),
            (".ollama/models", "Ollama models", .trash, false),
        ]
        let items = candidates.compactMap { path, name, method, pre in
            item(Paths.home(path), name, method, preselected: pre)
        }
        return CategoryResult(id: .devCaches, items: items.sorted { $0.size > $1.size })
    }

    static func iosBackups() -> CategoryResult {
        let dir = Paths.home("Library/Application Support/MobileSync/Backup")
        switch FS.list(dir) {
        case .missing: return CategoryResult(id: .iosBackups, items: [])
        case .denied: return CategoryResult(id: .iosBackups, items: [], accessDenied: true)
        case .ok(let urls):
            let items = urls.compactMap { url -> DiskItem? in
                let info = NSDictionary(contentsOf: url.appending(path: "Info.plist"))
                let device = info?["Device Name"] as? String ?? "Unknown device"
                let date = info?["Last Backup Date"] as? Date ?? FS.modified(url)
                let product = info?["Product Type"] as? String
                let size = FS.size(of: url)
                guard size > 0 else { return nil }
                return DiskItem(
                    url: url, name: device, size: size, modified: date, method: .trash,
                    detail: [product, String(url.lastPathComponent.prefix(12))].compactMap { $0 }.joined(separator: " · "))
            }
            return CategoryResult(id: .iosBackups, items: items.sorted { $0.size > $1.size })
        }
    }

    static func mail() -> CategoryResult {
        let store = Paths.home("Library/Mail")
        if case .denied = FS.list(store) {
            return CategoryResult(id: .mail, items: [], accessDenied: true)
        }
        let items = [
            item(Paths.home("Library/Containers/com.apple.mail/Data/Library/Mail Downloads"),
                 "Opened attachments (Mail Downloads)", .delete),
            item(Paths.home("Library/Mail Downloads"), "Old Mail Downloads", .delete),
            item(store, "Mail store: messages and attachments", .none,
                 detail: "Delete large messages in Mail, then Mailbox › Erase Deleted Items"),
        ].compactMap { $0 }
        return CategoryResult(id: .mail, items: items.sorted { $0.size > $1.size })
    }

    static func messages() -> CategoryResult {
        let dir = Paths.home("Library/Messages/Attachments")
        switch FS.list(dir) {
        case .missing: return CategoryResult(id: .messages, items: [])
        case .denied: return CategoryResult(id: .messages, items: [], accessDenied: true)
        case .ok:
            var total: Int64 = 0
            var count = 0
            var large: [(URL, Int64)] = []
            FS.forEachFile(in: dir) { url, size in
                total += size
                count += 1
                if size >= 5_000_000 { large.append((url, size)) }
            }
            large.sort { $0.1 > $1.1 }
            let shown = large.prefix(500)
            let items = shown.map { url, size in
                DiskItem(
                    url: url, name: url.lastPathComponent, size: size, modified: FS.modified(url),
                    method: .trash, detail: url.pathExtension.uppercased())
            }
            let note = "\(count.formatted()) attachments · showing the \(shown.count) largest (over 5 MB)"
            return CategoryResult(id: .messages, items: items, measured: total, note: note)
        }
    }

    static func downloads() -> CategoryResult {
        let installers: Set<String> = ["dmg", "pkg", "mpkg", "iso", "xip", "zip"]
        let twoWeeksAgo = Date.now.addingTimeInterval(-14 * 24 * 3600)
        return children(.downloads, of: Paths.home("Downloads"), method: .trash, minSize: 1_000_000) { url in
            installers.contains(url.pathExtension.lowercased()) && (FS.modified(url) ?? .now) < twoWeeksAgo
        }
    }

    /// Files over 500 MB found through Spotlight, outside the places other
    /// categories already cover and outside packages (a Photos library's
    /// originals must never be trashed one by one).
    static func largeFiles() -> CategoryResult {
        let home = Paths.home.path(percentEncoded: false)
        guard let result = FS.run("/usr/bin/mdfind", ["-onlyin", home, "kMDItemFSSize > 524288000"]) else {
            return CategoryResult(id: .largeFiles, items: [])
        }
        let skipped = ["/Library/", "/.Trash/", ".photoslibrary/", ".app/", ".musiclibrary/", ".tvlibrary/", "/.orbstack/", "/.colima/"]
        let items = result.output.split(separator: "\n").compactMap { line -> DiskItem? in
            let path = String(line)
            guard path.hasPrefix(home), !skipped.contains(where: path.contains) else { return nil }
            let url = URL(filePath: path)
            guard let values = try? url.resourceValues(forKeys: FS.sizeKeys), values.isDirectory != true else { return nil }
            let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            guard size > 0 else { return nil }
            return DiskItem(
                url: url, name: url.lastPathComponent, size: size, modified: FS.modified(url),
                method: .trash, detail: FS.abbreviate(url.deletingLastPathComponent()))
        }
        return CategoryResult(id: .largeFiles, items: items.sorted { $0.size > $1.size })
    }

    static func snapshots() -> CategoryResult {
        guard let result = FS.run("/usr/bin/tmutil", ["listlocalsnapshots", "/"]) else {
            return CategoryResult(id: .snapshots, items: [])
        }
        let names = result.output.split(separator: "\n").map(String.init).filter { $0.contains("com.apple.") }
        let items = names.compactMap { name -> DiskItem? in
            guard let url = URL(string: "snapshot://local/\(name)") else { return nil }
            return DiskItem(url: url, name: name, size: 0, method: .none, detail: "Local snapshot")
        }
        let purgeable = VolumeInfo.read()?.purgeable ?? 0
        let note = names.isEmpty
            ? "No local snapshots"
            : "\(names.count) local snapshots · part of \(purgeable.bytesText) purgeable"
        return CategoryResult(id: .snapshots, items: items, measured: 0, note: note)
    }

    static func docker() -> CategoryResult {
        let items = [
            item(Paths.home("Library/Containers/com.docker.docker/Data/vms/0/data"), "Docker Desktop disk image", .none,
                 detail: "Shrinks only through Docker: run the ritual or Docker › Troubleshoot › Clean / Purge data"),
            item(Paths.home(".orbstack"), "OrbStack data", .none),
            item(Paths.home("Library/Group Containers/HUAQ24HBR6.dev.orbstack"), "OrbStack data", .none),
            item(Paths.home(".colima"), "Colima VMs", .none),
            item(Paths.home("Library/Containers/com.utmapp.UTM/Data/Documents"), "UTM virtual machines", .none),
            item(Paths.home("Parallels"), "Parallels virtual machines", .none),
            item(Paths.home("Virtual Machines.localized"), "VMware virtual machines", .none),
        ].compactMap { $0 }
        return CategoryResult(id: .docker, items: items.sorted { $0.size > $1.size })
    }

    static func system() -> CategoryResult {
        let items = [
            item(URL(filePath: "/System/Volumes/VM"), "Swap & sleep image", .none,
                 detail: "Grows when memory runs short. Restarting the Mac resets it"),
            item(Paths.home("Pictures/Photos Library.photoslibrary"), "Photos library", .none,
                 detail: "Turn on Photos › Settings › iCloud › Optimize Mac Storage"),
            item(Paths.home("Library/Mobile Documents"), "iCloud Drive (downloaded copies)", .none,
                 detail: "Right-click files in Finder › Remove Download to keep them only in iCloud"),
            item(Paths.home("Music/Music"), "Music & podcasts media", .none),
            item(Paths.home("Library/Application Support"), "Application Support (app data)", .none,
                 detail: "Includes iPhone backups and app data; look inside for apps you have deleted"),
            item(Paths.home("Library/Group Containers"), "Group Containers (shared app data)", .none),
        ].compactMap { $0 }
        return CategoryResult(id: .system, items: items.sorted { $0.size > $1.size })
    }
}
