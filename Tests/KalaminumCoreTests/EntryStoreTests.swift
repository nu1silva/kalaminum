import Foundation
import Testing
@testable import KalaminumCore

@Suite struct EntryStoreTests {
    private let nine = Slot(containing: Date(timeIntervalSinceReferenceDate: 815_000_400)) // arbitrary aligned slot
    private func slot(_ offset: Int) -> Slot {
        Slot(containing: nine.start.addingTimeInterval(Double(offset) * Slot.length))
    }

    @Test func logTrimsAndEmptyClears() throws {
        let store = EntryStore(fileURL: nil)
        try store.log("  Coding \n", for: [slot(0), slot(1)])
        #expect(store.activity(for: slot(0)) == "Coding")
        #expect(store.activity(for: slot(1)) == "Coding")
        try store.log("   ", for: [slot(1)])
        #expect(store.activity(for: slot(1)) == nil)
    }

    @Test func recentActivitiesAreDistinctNewestFirst() throws {
        let store = EntryStore(fileURL: nil)
        let t = Date()
        try store.log("Email", for: [slot(0)], at: t)
        try store.log("Coding", for: [slot(1)], at: t.addingTimeInterval(1))
        try store.log("email", for: [slot(2)], at: t.addingTimeInterval(2))
        #expect(store.recentActivities() == ["email", "Coding"])
        #expect(store.recentActivities(limit: 1) == ["email"])
    }

    @Test func unloggedRunStopsAtLoggedSlotLimitAndBoundary() throws {
        let store = EntryStore(fileURL: nil)
        try store.log("Lunch", for: [slot(0)])
        // slots 1...4 empty; asking about slot 5
        #expect(store.unloggedRun(before: slot(5), limit: 32, notBefore: .distantPast) == [slot(1), slot(2), slot(3), slot(4)])
        #expect(store.unloggedRun(before: slot(5), limit: 2, notBefore: .distantPast) == [slot(3), slot(4)])
        #expect(store.unloggedRun(before: slot(5), limit: 32, notBefore: slot(3).start) == [slot(3), slot(4)])
        #expect(store.unloggedRun(before: slot(1), limit: 32, notBefore: .distantPast).isEmpty)
    }

    @Test func totalsGroupCaseInsensitivelyLargestFirst() throws {
        let store = EntryStore(fileURL: nil)
        try store.log("Coding", for: [slot(0), slot(1)])
        try store.log("coding", for: [slot(2)])
        try store.log("Email", for: [slot(3)])
        let totals = store.totals(for: (0..<6).map(slot))
        #expect(totals.map(\.minutes) == [45, 15])
        #expect(totals.first?.id == "coding")
        #expect(totals.last?.activity == "Email")
    }

    @Test func persistsAndReloads() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("entries.json")

        try EntryStore(fileURL: url).log("Writing", for: [slot(0), slot(3)])
        let reloaded = EntryStore(fileURL: url)
        #expect(reloaded.loadWarning == nil)
        #expect(reloaded.activity(for: slot(0)) == "Writing")
        #expect(reloaded.activity(for: slot(3)) == "Writing")
        #expect(reloaded.entries.count == 2)
    }

    @Test func corruptFileIsSetAsideNotLost() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("entries.json")
        try Data("not json".utf8).write(to: url)

        let store = EntryStore(fileURL: url)
        #expect(store.loadWarning != nil)
        #expect(store.entries.isEmpty)
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(files.contains { $0.hasPrefix("entries.unreadable-") })
    }
}
