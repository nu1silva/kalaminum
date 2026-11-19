import Foundation

/// A 15-minute block of wall-clock time, aligned to :00, :15, :30 and :45.
///
/// Alignment is done on the absolute timeline rather than through calendar
/// components: every real-world UTC offset is a whole multiple of 15 minutes
/// (including +5:45 and +12:45), so flooring to 900 s always lands on a local
/// quarter-hour, and DST transitions can't produce odd or duplicate slots.
public struct Slot: Hashable, Comparable, Sendable {
    public static let length: TimeInterval = 15 * 60

    public let start: Date

    public init(containing date: Date) {
        let t = date.timeIntervalSinceReferenceDate
        start = Date(timeIntervalSinceReferenceDate: (t / Slot.length).rounded(.down) * Slot.length)
    }

    public var end: Date { start.addingTimeInterval(Slot.length) }
    public var next: Slot { Slot(containing: end) }
    public var previous: Slot { Slot(containing: start.addingTimeInterval(-Slot.length)) }

    public static func < (lhs: Slot, rhs: Slot) -> Bool { lhs.start < rhs.start }

    /// The most recent slot that has fully elapsed at `date`.
    public static func lastCompleted(at date: Date) -> Slot {
        Slot(containing: date).previous
    }

    /// Every slot from the one containing `from` up to (not including) `to`.
    public static func range(from: Date, to: Date) -> [Slot] {
        var slots: [Slot] = []
        var slot = Slot(containing: from)
        while slot.start < to {
            slots.append(slot)
            slot = slot.next
        }
        return slots
    }

    /// All slots of the calendar day containing `date` (normally 96; 92 or 100 on DST days).
    public static func day(containing date: Date, calendar: Calendar = .current) -> [Slot] {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return range(from: start, to: end)
    }

    /// True when the slots form one unbroken run (assumes they are sorted).
    public static func areContiguous(_ slots: [Slot]) -> Bool {
        zip(slots, slots.dropFirst()).allSatisfy { $0.next == $1 }
    }
}
