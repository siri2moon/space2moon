import Foundation

public enum Paths {
    public static let home = FileManager.default.homeDirectoryForCurrentUser

    public static func home(_ relative: String) -> URL {
        home.appending(path: relative)
    }
}

enum Listing {
    case ok([URL])
    case missing
    case denied
}

/// Synchronous file system helpers. Called from `@concurrent` scanner functions.
enum FS {
    static let sizeKeys: Set<URLResourceKey> = [
        .isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
    ]

    static func list(_ dir: URL) -> Listing {
        let fm = FileManager()
        do {
            return .ok(try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: []))
        } catch {
            return fm.fileExists(atPath: dir.path(percentEncoded: false)) ? .denied : .missing
        }
    }

    static func exists(_ url: URL) -> Bool {
        FileManager().fileExists(atPath: url.path(percentEncoded: false))
    }

    static func modified(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    /// Bytes actually allocated on disk for a file or a whole folder tree.
    /// Symbolic links are not followed.
    static func size(of url: URL) -> Int64 {
        guard let v = try? url.resourceValues(forKeys: sizeKeys), v.isSymbolicLink != true else { return 0 }
        if v.isDirectory != true {
            return Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
        }
        var total: Int64 = 0
        forEachFile(in: url) { _, size in total += size }
        return total
    }

    /// Walks every regular file below `dir`, reporting its allocated size.
    static func forEachFile(in dir: URL, _ body: (URL, Int64) -> Void) {
        let fm = FileManager()
        guard let walker = fm.enumerator(
            at: dir, includingPropertiesForKeys: Array(sizeKeys), options: [],
            errorHandler: { _, _ in true })
        else { return }
        while let file = walker.nextObject() as? URL {
            if Task.isCancelled { return }
            guard let v = try? file.resourceValues(forKeys: sizeKeys),
                  v.isDirectory != true, v.isSymbolicLink != true
            else { continue }
            body(file, Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0))
        }
    }

    /// Runs a command and returns its standard output, or `nil` if it failed to start.
    static func run(_ executable: String, _ arguments: [String]) -> (status: Int32, output: String)? {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    static func abbreviate(_ url: URL) -> String {
        let path = url.path(percentEncoded: false)
        let home = Paths.home.path(percentEncoded: false)
        return path.hasPrefix(home) ? "~/" + path.dropFirst(home.count) : path
    }
}

public enum Access {
    /// True when the app has Full Disk Access. Only then can it read Mail,
    /// Messages, the Trash and iOS backups. Several probes, because any one
    /// of these places can be missing on a given Mac.
    public static func hasFullDiskAccess() -> Bool {
        let tcc = Paths.home("Library/Application Support/com.apple.TCC/TCC.db")
        if let handle = try? FileHandle(forReadingFrom: tcc) {
            try? handle.close()
            return true
        }
        let fm = FileManager()
        for folder in ["Library/Safari", "Library/Mail", "Library/Messages", ".Trash"] {
            let url = Paths.home(folder)
            guard fm.fileExists(atPath: url.path(percentEncoded: false)) else { continue }
            if (try? fm.contentsOfDirectory(atPath: url.path(percentEncoded: false))) != nil { return true }
        }
        return false
    }
}
