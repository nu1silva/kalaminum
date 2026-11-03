import KalaminumCore
import SwiftUI

enum Format {
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "13:00 – 13:45", or "5 slots" for a non-contiguous selection.
    static func span(_ slots: [Slot]) -> String {
        let sorted = slots.sorted()
        guard let first = sorted.first, let last = sorted.last else { return "" }
        guard Slot.areContiguous(sorted) else { return "\(sorted.count) slots" }
        return "\(time(first.start)) – \(time(last.end))"
    }

    static func duration(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        switch (h, m) {
        case (0, _): return "\(m)m"
        case (_, 0): return "\(h)h"
        default: return "\(h)h \(m)m"
        }
    }

    static func day(_ date: Date, offset: Int) -> String {
        switch offset {
        case 0: return "Today"
        case 1: return "Yesterday"
        default: return date.formatted(.dateTime.weekday(.wide).day().month())
        }
    }
}

extension Color {
    /// A stable color per activity name (Swift's `hashValue` is randomized per launch, so roll our own).
    static func activity(_ name: String) -> Color {
        var hash: UInt64 = 5381
        for byte in name.lowercased().utf8 { hash = (hash &* 33) ^ UInt64(byte) }
        return Color(hue: Double(hash % 360) / 360, saturation: 0.5, brightness: 0.85)
    }
}

/// Lays children out left-to-right, wrapping onto new rows as needed.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(maxWidth: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrange(maxWidth: bounds.width, subviews: subviews)
        for (subview, frame) in zip(subviews, layout.frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, width: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return (CGSize(width: width, height: y + rowHeight), frames)
    }
}
