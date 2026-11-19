import AppKit
import KalaminumCore
import SwiftUI

/// The small floating "what did you do?" panel.
///
/// Reminders appear without taking keyboard focus, so a prompt firing mid-sentence
/// never swallows your typing — click into it when you're ready.
@MainActor
final class PromptWindowController: NSObject, NSWindowDelegate {
    private let panel: NSPanel
    private unowned let model: AppModel

    init(model: AppModel) {
        self.model = model
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: true)
        super.init()

        panel.title = "Kalaminum"
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let host = NSHostingController(rootView: PromptContainer(model: model))
        host.sizingOptions = .preferredContentSize
        panel.contentViewController = host
    }

    func show(takeFocus: Bool) {
        if !panel.isVisible { positionTopRight() }
        if takeFocus {
            NSApp.activate()
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        panel.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        model.dismissPrompt()
    }

    private func positionTopRight() {
        guard let screen = NSScreen.main else { return panel.center() }
        panel.contentViewController?.view.layoutSubtreeIfNeeded()
        let size = panel.contentViewController?.view.fittingSize ?? panel.frame.size
        let visible = screen.visibleFrame
        panel.setFrameTopLeftPoint(NSPoint(x: visible.maxX - size.width - 16, y: visible.maxY - 12))
    }
}

private struct PromptContainer: View {
    let model: AppModel

    var body: some View {
        if let request = model.prompt {
            // Same id while a reminder grows, so a half-typed answer survives the next boundary.
            PromptView(model: model, request: request).id(request.id)
        }
    }
}

private struct PromptView: View {
    let model: AppModel
    let request: PromptRequest

    @State private var text: String
    @State private var includeGap = false
    @FocusState private var fieldFocused: Bool

    init(model: AppModel, request: PromptRequest) {
        self.model = model
        self.request = request
        _text = State(initialValue: model.commonActivity(for: request.slots) ?? "")
    }

    private var gap: [Slot] { model.earlierGap(for: request) }
    private var isBlank: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(request.kind == .reminder ? "What did you just do?" : "What were you doing?")
                    .font(.headline)
                Text(Format.span(request.slots))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            TextField("e.g. Coding, Email, Lunch…", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($fieldFocused)
                .onSubmit { if !isBlank { submit(text) } }

            let recent = model.store.recentActivities(limit: 9)
            if !recent.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(recent.enumerated()), id: \.offset) { index, activity in
                        Button { submit(activity) } label: {
                            HStack(spacing: 4) {
                                Circle().fill(Color.activity(activity)).frame(width: 7, height: 7)
                                Text(activity).lineLimit(1)
                            }
                        }
                        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                        .help("⌘\(index + 1)")
                    }
                }
            }

            if !gap.isEmpty {
                Toggle(isOn: $includeGap) {
                    Text("Also fill \(gap.count) earlier empty \(gap.count == 1 ? "slot" : "slots") (\(Format.span(gap)))")
                        .font(.callout)
                }
            }

            if let error = model.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                if request.kind == .edit, request.slots.contains(where: { model.store.activity(for: $0) != nil }) {
                    Button("Clear", role: .destructive) { model.log("", for: request.slots) }
                }
                Spacer()
                Button(request.kind == .reminder ? "Skip" : "Cancel") { model.dismissPrompt() }
                    .keyboardShortcut(.cancelAction)
                Button("Log") { submit(text) }
                    .disabled(isBlank)
            }
        }
        .padding(16)
        .padding(.top, 8)
        .frame(width: 400)
        .onAppear { fieldFocused = true }
    }

    private func submit(_ activity: String) {
        model.log(activity, for: request.slots + (includeGap ? gap : []))
    }
}
