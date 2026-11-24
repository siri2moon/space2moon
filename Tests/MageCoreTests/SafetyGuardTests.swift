import Foundation
import Testing
@testable import MageCore

struct SafetyGuardTests {
    let home = URL(filePath: "/Users/tester")

    @Test(arguments: [
        "Library/Caches/com.spotify.client",
        "Library/Developer/Xcode/DerivedData/App-abc",
        "Downloads/installer.dmg",
        ".npm/_cacache",
        "Library/Messages/Attachments/ab/01/IMG_0001.HEIC",
    ])
    func `allows items inside the home folder`(_ path: String) {
        #expect(SafetyGuard.allows(home.appending(path: path), home: home))
    }

    @Test(arguments: [
        "", "Library", "Library/Caches", "Downloads", "Documents", ".Trash",
        "Library/Messages/Attachments", "Library/Application Support/MobileSync/Backup",
    ])
    func `refuses the category roots themselves`(_ path: String) {
        #expect(!SafetyGuard.allows(home.appending(path: path), home: home))
    }

    @Test(arguments: [
        "/System/Library/Caches/x", "/Users/other/Library/Caches/x", "/Users/tester2/file",
        "/Users/tester/Library/Mail/V10/INBOX.mbox",
        "/Users/tester/Pictures/Photos Library.photoslibrary/originals/A/1.heic",
        "/Users/tester/Library/Caches/../../Documents",
    ])
    func `refuses paths outside home or sealed by their app`(_ path: String) {
        #expect(!SafetyGuard.allows(URL(filePath: path), home: home))
    }

    @Test func `refuses non-file URLs`() throws {
        let url = try #require(URL(string: "snapshot://local/com.apple.TimeMachine.2026-11-24"))
        #expect(!SafetyGuard.allows(url, home: home))
    }
}

struct OracleTests {
    @Test func `growth is measured against the baseline`() {
        let results: [CategoryID: CategoryResult] = [
            .messages: CategoryResult(id: .messages, items: [], measured: 30_000_000_000),
            .logs: CategoryResult(id: .logs, items: [], measured: 1_000_000),
        ]
        let baseline = ScanSnapshot(date: .distantPast, used: 0, available: 0, totals: ["messages": 25_000_000_000])
        let insights = Oracle.divine(results: results, volume: nil, baseline: baseline)
        #expect(insights.first?.category == .messages)
        #expect(insights.first?.growth == 5_000_000_000)
        #expect(insights.last?.growth == nil)
    }

    @Test func `baseline skips snapshots younger than the minimum age`() {
        let now = Date.now
        let old = ScanSnapshot(date: now.addingTimeInterval(-86_400), used: 1, available: 0, totals: [:])
        let fresh = ScanSnapshot(date: now.addingTimeInterval(-60), used: 2, available: 0, totals: [:])
        #expect(Chronicle.baseline(in: [old, fresh], now: now)?.used == 1)
    }
}
