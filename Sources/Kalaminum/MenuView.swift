import AppKit
import KalaminumCore
import SwiftUI

struct MenuView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if let warning = model.store.loadWarning {
                Text(warning).font(.caption).foregroundStyle(.orange)
            }
            if let error = model.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            SummaryView(totals: model.dayTotals)
            Divider()
            DayTimeline(model: model)
            if !model.selection.isEmpty { selectionBar }
            Divider()
            footer
        }
        .padding(12)
        .frame(width: 340)
        .onAppear { model.refreshNow() }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Button { model.changeDay(by: -1) } label: { Image(systemName: "chevron.left") }
            Button { model.changeDay(by: 1) } label: { Image(systemName: "chevron.right") }
                .disabled(model.isViewingToday)
            Text(Format.day(model.viewedDay, offset: model.dayOffset)).font(.headline)
            Spacer()
            if !model.isViewingToday {
                Button("Today") { model.dayOffset = 0; model.clearSelection() }
            }
        }
        .buttonStyle(.borderless)
    }

    private var selectionBar: some View {
        let slots = model.selection.sorted()
        return HStack {
            Text(Format.span(slots)).font(.callout.monospacedDigit())
            Text(Format.duration(minutes: slots.count * 15)).font(.callout).foregroundStyle(.secondary)
            Spacer()
            Button("Deselect") { model.clearSelection() }
            Button("Edit…") { model.promptForSelection() }.keyboardShortcut(.defaultAction)
        }
        .controlSize(.small)
    }

    private var footer: some View {
        HStack {
            Button("Log last 15 min…") { model.promptForLastSlot() }
            Spacer()
            Menu {
                if model.isPaused, let until = model.pausedUntil {
                    Text("Paused until \(Format.time(until))")
                    Button("Resume reminders") { model.resume() }
                } else {
                    Button("Pause for 1 hour") { model.pause(for: 3600) }
                    Button("Pause for 2 hours") { model.pause(for: 7200) }
                    Button("Pause until tomorrow") { model.pauseUntilTomorrow() }
                }
                Divider()
                Toggle("Open at login", isOn: Binding(
                    get: { model.launchesAtLogin },
                    set: { model.setLaunchesAtLogin($0) }))
                Button("Show log file in Finder") { model.revealLogFile() }
                Divider()
                Button("Quit Kalaminum") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: model.isPaused ? "pause.circle" : "gearshape")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .controlSize(.small)
    }
}

private struct SummaryView: View {
    let totals: [ActivityTotal]

    var body: some View {
        let logged = totals.reduce(0) { $0 + $1.minutes }
        let longest = max(totals.first?.minutes ?? 1, 1)
        VStack(alignment: .leading, spacing: 4) {
            if totals.isEmpty {
                Text("Nothing logged yet.").foregroundStyle(.secondary)
            } else {
                ForEach(totals.prefix(6)) { total in
                    HStack(spacing: 6) {
                        Text(total.activity).lineLimit(1).frame(width: 110, alignment: .leading)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.activity(total.activity))
                                .frame(width: max(3, geo.size.width * CGFloat(total.minutes) / CGFloat(longest)))
                        }
                        .frame(height: 8)
                        Text(Format.duration(minutes: total.minutes))
                            .monospacedDigit().foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .trailing)
                    }
                    .font(.callout)
                }
                if totals.count > 6 {
                    Text("+ \(totals.count - 6) more").font(.caption).foregroundStyle(.secondary)
                }
                Text("Logged \(Format.duration(minutes: logged))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct DayTimeline: View {
    let model: AppModel

    var body: some View {
        let slots = model.timelineSlots
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(slots.enumerated()), id: \.element) { index, slot in
                        let activity = model.store.activity(for: slot)
                        let previous = index > 0 ? model.store.activity(for: slots[index - 1]) : nil
                        SlotRow(
                            slot: slot,
                            activity: activity,
                            continuesRun: activity != nil && activity?.lowercased() == previous?.lowercased(),
                            isNow: model.isViewingToday && slot == model.currentSlot,
                            isSelected: model.selection.contains(slot)
                        )
                        .id(slot)
                        .onTapGesture {
                            model.select(slot, extending: NSEvent.modifierFlags.contains(.shift))
                        }
                    }
                }
            }
            .frame(height: 320)
            .onAppear {
                let anchor = model.isViewingToday ? model.currentSlot : slots.first { model.store.activity(for: $0) != nil }
                if let anchor { proxy.scrollTo(anchor, anchor: .center) }
            }
        }
        Text("Click a slot to select it, shift-click to select a range.")
            .font(.caption2).foregroundStyle(.tertiary)
    }
}

private struct SlotRow: View {
    let slot: Slot
    let activity: String?
    let continuesRun: Bool
    let isNow: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(Format.time(slot.start))
                .font(.callout.monospacedDigit())
                .foregroundStyle(slot.start.isOnTheHour ? .primary : .secondary)
                .frame(width: 64, alignment: .trailing)
            Rectangle()
                .fill(activity.map(Color.activity) ?? Color.secondary.opacity(0.15))
                .frame(width: 4)
            if let activity {
                Text(continuesRun ? "" : activity).lineLimit(1)
            } else {
                Text("—").foregroundStyle(.quaternary)
            }
            Spacer()
            if isNow {
                Text("now").font(.caption2.bold()).foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(Color.accentColor))
            }
        }
        .frame(height: 22)
        .padding(.trailing, 6)
        .background(isSelected ? Color.accentColor.opacity(0.25) : .clear)
        .contentShape(Rectangle())
    }
}

private extension Date {
    var isOnTheHour: Bool { Calendar.current.component(.minute, from: self) == 0 }
}
