import Foundation
import Observation

/// What you did during one slot.
public struct Entry: Codable, Equatable, Sendable {
    public var start: Date
    public var activity: String
    public var loggedAt: Date

    public init(start: Date, activity: String, loggedAt: Date) {
        self.start = start
        self.activity = activity
        self.loggedAt = loggedAt
    }
}

/// Time spent on one activity within some set of slots.
public struct ActivityTotal: Equatable, Sendable, Identifiable {
    public let activity: String
    public let slotCount: Int
    public var id: String { activity.lowercased() }
    public var minutes: Int { slotCount * 15 }
}

public struct StoreError: LocalizedError {
    public let errorDescription: String?
}

/// The activity log, persisted as a single human-readable JSON file.
@Observable
public final class EntryStore {
    public private(set) var entries: [Date: Entry] = [:]
    /// Set when the log file on disk couldn't be read at launch.
    public private(set) var loadWarning: String?

    /// `nil` keeps everything in memory (used by tests).
    @ObservationIgnored public let fileURL: URL?
    @ObservationIgnored private var canSave = true

    public init(fileURL: URL?) {
        self.fileURL = fileURL
        load()
    }

    public static var defaultFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kalaminum", isDirectory: true)
            .appendingPathComponent("entries.json")
    }

    // MARK: Reading

    public func activity(for slot: Slot) -> String? {
        entries[slot.start]?.activity
    }

    /// Distinct activities, most recently logged first.
    public func recentActivities(limit: Int = 9) -> [String] {
        let newestFirst = entries.values.sorted { ($0.loggedAt, $0.start) > ($1.loggedAt, $1.start) }
        var seen = Set<String>()
        var result: [String] = []
        for entry in newestFirst where seen.insert(entry.activity.lowercased()).inserted {
            result.append(entry.activity)
            if result.count == limit { break }
        }
        return result
    }

    /// The unbroken run of unlogged slots directly before `slot`, oldest first.
    /// Stops at the first logged slot, after `limit` slots, or before `notBefore`.
    public func unloggedRun(before slot: Slot, limit: Int, notBefore: Date) -> [Slot] {
        var run: [Slot] = []
        var candidate = slot.previous
        while run.count < limit, candidate.start >= notBefore, activity(for: candidate) == nil {
            run.append(candidate)
            candidate = candidate.previous
        }
        return run.reversed()
    }

    /// Per-activity totals (case-insensitive), largest first.
    public func totals(for slots: [Slot]) -> [ActivityTotal] {
        var counts: [String: (name: String, count: Int)] = [:]
        for slot in slots {
            guard let activity = activity(for: slot) else { continue }
            counts[activity.lowercased(), default: (activity, 0)].count += 1
        }
        return counts.values
            .map { ActivityTotal(activity: $0.name, slotCount: $0.count) }
            .sorted { $0.slotCount != $1.slotCount ? $0.slotCount > $1.slotCount : $0.activity < $1.activity }
    }

    // MARK: Writing

    /// Records `activity` for every slot given. An empty activity clears the slots.
    public func log(_ activity: String, for slots: [Slot], at now: Date = Date()) throws {
        let trimmed = activity.trimmingCharacters(in: .whitespacesAndNewlines)
        for slot in slots {
            entries[slot.start] = trimmed.isEmpty
                ? nil
                : Entry(start: slot.start, activity: trimmed, loggedAt: now)
        }
        try save()
    }

    public func clear(_ slots: [Slot]) throws {
        try log("", for: slots)
    }

    // MARK: Persistence

    private func load() {
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else { return }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            // Don't risk overwriting a log we merely failed to read.
            canSave = false
            loadWarning = "Couldn't open \(url.path): \(error.localizedDescription). Changes won't be saved this session."
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let list = try decoder.decode([Entry].self, from: data)
            for var entry in list {
                // Snap hand-edited timestamps onto slot boundaries.
                entry.start = Slot(containing: entry.start).start
                if let existing = entries[entry.start], existing.loggedAt > entry.loggedAt { continue }
                entries[entry.start] = entry
            }
        } catch {
            let backup = url.deletingPathExtension()
                .appendingPathExtension("unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            loadWarning = "\(url.lastPathComponent) was unreadable, so it was moved to \(backup.lastPathComponent) and a new log was started."
        }
    }

    private func save() throws {
        guard let url = fileURL else { return }
        guard canSave else {
            throw StoreError(errorDescription: "Saving is disabled because the log file couldn't be read at launch.")
        }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let list = entries.values.sorted { $0.start < $1.start }
        try encoder.encode(list).write(to: url, options: .atomic)
    }
}
