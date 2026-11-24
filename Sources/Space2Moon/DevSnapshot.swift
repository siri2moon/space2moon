import AppKit

/// Development aid: `SPACE2MOON_SNAPSHOT=/path/shot.png` writes a PNG of the
/// window after the first scan, so the UI can be checked without screen recording.
enum DevSnapshot {
    static var target: String? { ProcessInfo.processInfo.environment["SPACE2MOON_SNAPSHOT"] }

    static func capture(suffix: String = "") {
        guard let target, let view = NSApp.windows.first(where: \.isVisible)?.contentView else { return }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        let path = suffix.isEmpty ? target : target.replacingOccurrences(of: ".png", with: "-\(suffix).png")
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(filePath: path))
    }
}
