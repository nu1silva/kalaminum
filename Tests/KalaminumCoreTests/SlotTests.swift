import Foundation
import Testing
@testable import KalaminumCore

@Suite struct SlotTests {
    private func date(_ s: String, tz: String = "Europe/Amsterdam") -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: tz)
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.date(from: s)!
    }

    private func minute(_ d: Date, tz: String) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: tz)!
        return cal.component(.minute, from: d)
    }

    @Test func floorsToQuarterHour() {
        let slot = Slot(containing: date("2026-11-02 14:29:59"))
        #expect(slot.start == date("2026-11-02 14:15:00"))
        #expect(slot.end == date("2026-11-02 14:30:00"))
        #expect(Slot(containing: date("2026-11-02 14:30:00")).start == date("2026-11-02 14:30:00"))
    }

    @Test(arguments: ["Asia/Kathmandu", "Pacific/Chatham", "Asia/Kolkata", "America/St_Johns"])
    func alignsToLocalQuarterHoursInOddOffsets(tz: String) {
        let slot = Slot(containing: date("2026-06-15 10:07:00", tz: tz))
        #expect(slot.start == date("2026-06-15 10:00:00", tz: tz))
        #expect(minute(slot.next.start, tz: tz) == 15)
    }

    @Test func lastCompletedIsPreviousSlot() {
        #expect(Slot.lastCompleted(at: date("2026-11-02 14:00:01")).start == date("2026-11-02 13:45:00"))
    }

    @Test func dayHas96SlotsNormallyAnd100OnFallBack() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        #expect(Slot.day(containing: date("2026-11-02 12:00:00"), calendar: cal).count == 96)
        // 2026-10-25: clocks go back one hour in the EU.
        #expect(Slot.day(containing: date("2026-10-25 12:00:00"), calendar: cal).count == 100)
        #expect(Slot.day(containing: date("2026-03-29 12:00:00"), calendar: cal).count == 92)
    }

    @Test func contiguity() {
        let a = Slot(containing: date("2026-11-02 09:00:00"))
        #expect(Slot.areContiguous([a, a.next, a.next.next]))
        #expect(!Slot.areContiguous([a, a.next.next]))
    }
}
