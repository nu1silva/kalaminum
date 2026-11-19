import AppKit
import KalaminumCore
import Observation
import ServiceManagement

/// A request to fill in one or more slots.
struct PromptRequest: Identifiable, Equatable {
    enum Kind {
        /// Asked by the 15-minute reminder; offers to back-fill earlier empty slots.
        case reminder
        /// Opened from the timeline to (re)write specific slots.
        case edit
    }

    var id = UUID()
    var slots: [Slot]
    var kind: Kind
}

@MainActor
@Observable
final class AppModel {
    /// `KALAMINUM_DATA=/path/to/file.json` points the app at a different log (handy for development).
    let store = EntryStore(fileURL: ProcessInfo.processInfo.environment["KALAMINUM_DATA"]
        .map { URL(fileURLWithPath: $0) } ?? EntryStore.defaultFileURL)

    /// Refreshed at every slot boundary and whenever the menu opens.
    private(set) var now = Date()
    /// Days back from today shown in the menu (0 = today).
    var dayOffset = 0
    private(set) var selection: Set<Slot> = []
    @ObservationIgnored private var selectionAnchor: Slot?
    private(set) var prompt: PromptRequest?
    var errorMessage: String?

    private(set) var pausedUntil: Date? = UserDefaults.standard.object(forKey: "pausedUntil") as? Date {
        didSet { UserDefaults.standard.set(pausedUntil, forKey: "pausedUntil") }
    }
    private(set) var launchesAtLogin = SMAppService.mainApp.status == .enabled

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var promptWindow: PromptWindowController?

    private var calendar: Calendar { .current }

    // MARK: Lifecycle

    func start() {
        promptWindow = PromptWindowController(model: self)
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshNow(); self?.scheduleNextBoundary() }
        }
        scheduleNextBoundary()
        if CommandLine.arguments.contains("--prompt-now") { promptForLastSlot() }
    }

    func refreshNow() {
        now = Date()
    }

    private func scheduleNextBoundary() {
        timer?.invalidate()
        let boundary = Slot(containing: Date()).end
        let timer = Timer(fire: boundary.addingTimeInterval(0.5), interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.boundaryReached(boundary) }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func boundaryReached(_ boundary: Date) {
        refreshNow()
        scheduleNextBoundary()

        // A timer that fires long after its boundary means the Mac was asleep;
        // don't ask about time it spent with the lid closed.
        guard now.timeIntervalSince(boundary) < 120, !isPaused else { return }
        // Don't yank away an edit in progress; the menu bar badge still flags the gap.
        guard prompt?.kind != .edit else { return }

        let target = Slot.lastCompleted(at: now)
        guard store.activity(for: target) == nil else { return }

        // If an earlier reminder is still unanswered, grow it rather than stacking prompts.
        if var open = prompt, open.kind == .reminder, let first = open.slots.first, first < target {
            open.slots = Slot.range(from: first.start, to: target.end).filter { store.activity(for: $0) == nil }
            showPrompt(open, takeFocus: false)
        } else {
            showPrompt(PromptRequest(slots: [target], kind: .reminder), takeFocus: false)
        }
        NSSound(named: "Tink")?.play()
    }

    // MARK: Prompt

    func showPrompt(_ request: PromptRequest, takeFocus: Bool) {
        prompt = request
        promptWindow?.show(takeFocus: takeFocus)
    }

    func promptForLastSlot() {
        showPrompt(PromptRequest(slots: [Slot.lastCompleted(at: Date())], kind: .reminder), takeFocus: true)
    }

    func promptForSelection() {
        guard !selection.isEmpty else { return }
        showPrompt(PromptRequest(slots: selection.sorted(), kind: .edit), takeFocus: true)
    }

    func dismissPrompt() {
        prompt = nil
        promptWindow?.hide()
    }

    /// Empty slots right before a reminder's slots that could be filled in too.
    func earlierGap(for request: PromptRequest) -> [Slot] {
        guard request.kind == .reminder, let first = request.slots.first else { return [] }
        return store.unloggedRun(before: first, limit: 32, notBefore: calendar.startOfDay(for: first.start))
    }

    /// The activity shared by all `slots`, if they agree.
    func commonActivity(for slots: [Slot]) -> String? {
        let activities = Set(slots.map { store.activity(for: $0) })
        return activities.count == 1 ? activities.first! : nil
    }

    func log(_ activity: String, for slots: [Slot]) {
        do {
            try store.log(activity, for: slots)
            errorMessage = nil
            selection.subtract(slots)
            dismissPrompt()
        } catch {
            errorMessage = "Couldn't save: \(error.localizedDescription)"
        }
    }

    // MARK: Day view

    var isViewingToday: Bool { dayOffset == 0 }

    var viewedDay: Date {
        calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: now))!
    }

    var currentSlot: Slot { Slot(containing: now) }

    /// The slots shown in the timeline: at least 08:00–18:00 (or up to now, for today),
    /// widened to include anything logged outside that window.
    var timelineSlots: [Slot] {
        let all = Slot.day(containing: viewedDay, calendar: calendar)
        let logged = all.filter { store.activity(for: $0) != nil }
        let workStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: viewedDay)!
        let workEnd = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: viewedDay)!

        var lower = min(logged.first?.start ?? workStart, workStart)
        let upper: Date
        if isViewingToday {
            lower = min(lower, currentSlot.start)
            upper = max(logged.last?.end ?? currentSlot.end, currentSlot.end)
        } else {
            upper = max(logged.last?.end ?? workEnd, workEnd)
        }
        return all.filter { $0.start >= lower && $0.start < upper }
    }

    var dayTotals: [ActivityTotal] {
        store.totals(for: Slot.day(containing: viewedDay, calendar: calendar))
    }

    func select(_ slot: Slot, extending: Bool) {
        if extending, let anchor = selectionAnchor {
            selection = Set(Slot.range(from: min(anchor, slot).start, to: max(anchor, slot).end))
        } else {
            selection = selection == [slot] ? [] : [slot]
            selectionAnchor = slot
        }
    }

    func clearSelection() {
        selection = []
        selectionAnchor = nil
    }

    func changeDay(by delta: Int) {
        dayOffset = max(0, dayOffset - delta)
        clearSelection()
    }

    // MARK: Reminders & settings

    var isPaused: Bool {
        guard let pausedUntil else { return false }
        return pausedUntil > now
    }

    /// Show a badge in the menu bar when the slot that just ended hasn't been logged.
    var needsAttention: Bool {
        !isPaused && store.activity(for: Slot.lastCompleted(at: now)) == nil
    }

    func pause(for interval: TimeInterval) {
        pausedUntil = Date().addingTimeInterval(interval)
        refreshNow()
    }

    func pauseUntilTomorrow() {
        pausedUntil = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))
        refreshNow()
    }

    func resume() {
        pausedUntil = nil
    }

    func setLaunchesAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            errorMessage = "Couldn't change login item: \(error.localizedDescription)"
        }
        launchesAtLogin = SMAppService.mainApp.status == .enabled
    }

    func revealLogFile() {
        guard let url = store.fileURL else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            let folder = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(folder)
        }
    }
}
