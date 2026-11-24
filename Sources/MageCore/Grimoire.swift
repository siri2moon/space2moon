import Foundation

public struct CategoryInfo: Sendable {
    public let id: CategoryID
    public let title: String
    public let sigil: String
    /// Why this place grows, in plain words.
    public let lore: String
    public let verdict: Verdict
    public let ritual: Ritual?
}

/// The catalog of categories: titles, symbols and the explanation of each.
public enum Grimoire {
    public static let storageSettings = "x-apple.systempreferences:com.apple.settings.Storage"
    public static let fullDiskAccessSettings = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"

    public static func info(_ id: CategoryID) -> CategoryInfo {
        switch id {
        case .trash:
            CategoryInfo(
                id: id, title: "The Trash", sigil: "trash",
                lore: "Files you delete keep their space until the Trash is emptied. Everything moved there by this app lands here too.",
                verdict: .safe, ritual: nil)
        case .userCaches:
            CategoryInfo(
                id: id, title: "App Caches", sigil: "archivebox",
                lore: "Browsers, Spotify, Slack, Homebrew, Electron apps and package managers keep caches that grow without limit. Apps rebuild what they need. Apple's own caches start unselected.",
                verdict: .safe, ritual: nil)
        case .logs:
            CategoryInfo(
                id: id, title: "Logs & Crash Reports", sigil: "scroll",
                lore: "Diagnostic logs and crash reports pile up quietly. Nothing reads them unless you are debugging.",
                verdict: .safe, ritual: nil)
        case .xcode:
            CategoryInfo(
                id: id, title: "Xcode Debris", sigil: "hammer",
                lore: "DerivedData, device support files and simulator caches easily reach tens of GB, and Xcode rebuilds them on demand. Archives hold builds you shipped, so they start unselected.",
                verdict: .safe,
                ritual: Ritual(label: "Remove unavailable simulators", kind: .shell("xcrun simctl delete unavailable")))
        case .devCaches:
            CategoryInfo(
                id: id, title: "Developer Caches", sigil: "shippingbox",
                lore: "npm, pnpm, Yarn, Bun, Gradle, Cargo, CocoaPods and pip keep every package version they ever downloaded. Model folders (Hugging Face, Ollama) start unselected.",
                verdict: .safe, ritual: nil)
        case .iosBackups:
            CategoryInfo(
                id: id, title: "iPhone & iPad Backups", sigil: "iphone",
                lore: "Every local Finder backup is a full copy of a device. Backups of phones you no longer own are common and huge.",
                verdict: .review, ritual: nil)
        case .mail:
            CategoryInfo(
                id: id, title: "Mail", sigil: "envelope",
                lore: "Mail keeps a local copy of every message and attachment, and caches opened attachments a second time in Mail Downloads. The mail store itself is cleaned from Mail: delete large messages, then Mailbox › Erase Deleted Items.",
                verdict: .guided,
                ritual: Ritual(label: "Open Mail", kind: .openApp(bundleID: "com.apple.mail")))
        case .messages:
            CategoryInfo(
                id: id, title: "Messages Attachments", sigil: "message",
                lore: "Every photo, video and sticker sent or received in iMessage stays on this Mac forever, unless Messages › Settings › Keep messages is set to 1 Year. Trashed attachments show as missing in old chats.",
                verdict: .review,
                ritual: Ritual(label: "Review in Storage settings", kind: .openURL(storageSettings)))
        case .downloads:
            CategoryInfo(
                id: id, title: "Downloads", sigil: "arrow.down.circle",
                lore: "Installers and archives you opened once and forgot. Disk images and packages older than two weeks start selected.",
                verdict: .review, ritual: nil)
        case .largeFiles:
            CategoryInfo(
                id: id, title: "Giant Files", sigil: "cube.transparent",
                lore: "Single files over 500 MB anywhere in your home folder: screen recordings, videos, disk images, virtual machines, model weights.",
                verdict: .review, ritual: nil)
        case .snapshots:
            CategoryInfo(
                id: id, title: "Time Machine Snapshots", sigil: "clock.arrow.circlepath",
                lore: "macOS keeps hourly local snapshots that count as purgeable. They make the disk look full and are only released under pressure, which is why Finder and apps disagree about free space.",
                verdict: .guided,
                ritual: Ritual(
                    label: "Thin all snapshots",
                    kind: .admin("/usr/bin/tmutil thinlocalsnapshots / 999999999999 4"),
                    warning: "Local snapshots are removed. Backups on your Time Machine disk are not affected."))
        case .docker:
            CategoryInfo(
                id: id, title: "Docker & Virtual Machines", sigil: "server.rack",
                lore: "Docker's disk image only grows: old images, stopped containers and build cache stay inside it. VM disks from UTM, Parallels or Colima are often tens of GB each.",
                verdict: .guided,
                ritual: Ritual(
                    label: "docker system prune -a",
                    kind: .shell("docker system prune -af"),
                    warning: "Removes stopped containers, unused networks, all unused images and the build cache. Volumes are kept."))
        case .system:
            CategoryInfo(
                id: id, title: "System Data", sigil: "cpu",
                lore: "Space macOS manages itself: swap and the sleep image, the Photos library, iCloud Drive's local copies and app data. Shown so you can see where it goes. It is never touched.",
                verdict: .info,
                ritual: Ritual(label: "Open Storage settings", kind: .openURL(storageSettings)))
        }
    }
}
