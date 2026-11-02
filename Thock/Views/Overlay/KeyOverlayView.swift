import SwiftUI

/// One keycap in the overlay keyboard.
struct KeyCap: Identifiable {
    let id = UUID()
    let label: String
    /// Shift-layer glyph shown above the main label, if any.
    let sub: String?
    /// Width in key units (1.0 = a standard square key).
    let width: CGFloat
    /// Physical macOS key codes that map onto this cap.
    let codes: [Int64]

    init(label: String, sub: String? = nil, width: CGFloat, codes: [Int64]) {
        self.label = label
        self.sub = sub
        self.width = width
        self.codes = codes
    }
}

/// Row items: plain caps plus two special composite caps.
enum KeyItem: Identifiable {
    case cap(KeyCap)
    /// 1u cap split by a diagonal: upper-left half is esc, lower-right is backtick.
    case escBacktick
    /// 2.75u right-shift "gate" with a half-height up arrow nestled inside.
    case shiftGate

    var id: UUID {
        switch self {
        case .cap(let cap): return cap.id
        case .escBacktick: return Self.escBacktickID
        case .shiftGate: return Self.shiftGateID
        }
    }

    private static let escBacktickID = UUID()
    private static let shiftGateID = UUID()
}

/// SwiftUI rendering of a compact ANSI keyboard that lights up
/// the keycaps reported by `KeyOverlayModel`.
struct KeyOverlayView: View {
    @ObservedObject var model: KeyOverlayModel

    /// Height of a 1-unit key at scale 1.0; all sizes derive from the scale
    /// so the content always matches the aspect-locked window exactly.
    private let baseUnit: CGFloat = 26

    private var unit: CGFloat { baseUnit * model.scale }
    private var spacing: CGFloat { 4 * model.scale }
    private var pad: CGFloat { 8 * model.scale }
    private var isLight: Bool { model.theme == "light" }

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: spacing) {
                    ForEach(row) { item in
                        itemView(item)
                    }
                }
            }
        }
        .padding(pad)
        .background(isLight ? Color.white.opacity(0.55 + 0.45 * model.opacity) : Color.black.opacity(0.35 + 0.65 * model.opacity))
        .clipShape(RoundedRectangle(cornerRadius: 12 * (unit / baseUnit), style: .continuous))
    }

    @ViewBuilder
    private func itemView(_ item: KeyItem) -> some View {
        switch item {
        case .cap(let cap):
            KeyCapView(
                cap: cap,
                isActive: cap.codes.contains(where: { model.isActive($0) }),
                unit: unit,
                spacing: spacing,
                isLight: isLight
            )
        case .escBacktick:
            SplitCapView(
                escActive: model.isActive(53),
                tickActive: model.isActive(50),
                unit: unit,
                isLight: isLight
            )
        case .shiftGate:
            GateShiftView(
                shiftActive: model.isActive(60),
                upActive: model.isActive(126),
                unit: unit,
                spacing: spacing,
                isLight: isLight
            )
        }
    }

    // ANSI layout, 15 units per row. Codes are physical macOS key codes,
    // layout independent.
    private static let rows: [[KeyItem]] = [
        // Number row: esc shares a diagonally split cap with backtick.
        [
            .escBacktick,
            .cap(KeyCap(label: "1", sub: "!", width: 1, codes: [18])),
            .cap(KeyCap(label: "2", sub: "@", width: 1, codes: [19])),
            .cap(KeyCap(label: "3", sub: "#", width: 1, codes: [20])),
            .cap(KeyCap(label: "4", sub: "$", width: 1, codes: [21])),
            .cap(KeyCap(label: "5", sub: "%", width: 1, codes: [23])),
            .cap(KeyCap(label: "6", sub: "^", width: 1, codes: [22])),
            .cap(KeyCap(label: "7", sub: "&", width: 1, codes: [26])),
            .cap(KeyCap(label: "8", sub: "*", width: 1, codes: [28])),
            .cap(KeyCap(label: "9", sub: "(", width: 1, codes: [25])),
            .cap(KeyCap(label: "0", sub: ")", width: 1, codes: [29])),
            .cap(KeyCap(label: "-", sub: "_", width: 1, codes: [27])),
            .cap(KeyCap(label: "=", sub: "+", width: 1, codes: [24])),
            .cap(KeyCap(label: "⌫", width: 2, codes: [51])),
        ],
        // QWERTY row
        [
            .cap(KeyCap(label: "⇥", width: 1.5, codes: [48])),
            .cap(KeyCap(label: "Q", width: 1, codes: [12])),
            .cap(KeyCap(label: "W", width: 1, codes: [13])),
            .cap(KeyCap(label: "E", width: 1, codes: [14])),
            .cap(KeyCap(label: "R", width: 1, codes: [15])),
            .cap(KeyCap(label: "T", width: 1, codes: [17])),
            .cap(KeyCap(label: "Y", width: 1, codes: [16])),
            .cap(KeyCap(label: "U", width: 1, codes: [32])),
            .cap(KeyCap(label: "I", width: 1, codes: [34])),
            .cap(KeyCap(label: "O", width: 1, codes: [31])),
            .cap(KeyCap(label: "P", width: 1, codes: [35])),
            .cap(KeyCap(label: "[", sub: "{", width: 1, codes: [33])),
            .cap(KeyCap(label: "]", sub: "}", width: 1, codes: [30])),
            .cap(KeyCap(label: "\\", sub: "|", width: 1.5, codes: [42])),
        ],
        // Home row
        [
            .cap(KeyCap(label: "⇪", width: 1.75, codes: [57])),
            .cap(KeyCap(label: "A", width: 1, codes: [0])),
            .cap(KeyCap(label: "S", width: 1, codes: [1])),
            .cap(KeyCap(label: "D", width: 1, codes: [2])),
            .cap(KeyCap(label: "F", width: 1, codes: [3])),
            .cap(KeyCap(label: "G", width: 1, codes: [5])),
            .cap(KeyCap(label: "H", width: 1, codes: [4])),
            .cap(KeyCap(label: "J", width: 1, codes: [38])),
            .cap(KeyCap(label: "K", width: 1, codes: [40])),
            .cap(KeyCap(label: "L", width: 1, codes: [37])),
            .cap(KeyCap(label: ";", sub: ":", width: 1, codes: [41])),
            .cap(KeyCap(label: "'", sub: "\"", width: 1, codes: [39])),
            .cap(KeyCap(label: "↩", width: 2.25, codes: [36])),
        ],
        // Shift row: right shift is a "gate" with the up arrow inside.
        [
            .cap(KeyCap(label: "⇧", width: 2.25, codes: [56])),
            .cap(KeyCap(label: "Z", width: 1, codes: [6])),
            .cap(KeyCap(label: "X", width: 1, codes: [7])),
            .cap(KeyCap(label: "C", width: 1, codes: [8])),
            .cap(KeyCap(label: "V", width: 1, codes: [9])),
            .cap(KeyCap(label: "B", width: 1, codes: [11])),
            .cap(KeyCap(label: "N", width: 1, codes: [45])),
            .cap(KeyCap(label: "M", width: 1, codes: [46])),
            .cap(KeyCap(label: ",", sub: "<", width: 1, codes: [43])),
            .cap(KeyCap(label: ".", sub: ">", width: 1, codes: [44])),
            .cap(KeyCap(label: "/", sub: "?", width: 1, codes: [47])),
            .shiftGate,
        ],
        // Bottom row
        [
            .cap(KeyCap(label: "fn", width: 1, codes: [63])),
            .cap(KeyCap(label: "⌃", width: 1.25, codes: [59, 62])),
            .cap(KeyCap(label: "⌥", width: 1.25, codes: [58])),
            .cap(KeyCap(label: "⌘", width: 1.25, codes: [55])),
            .cap(KeyCap(label: "space", width: 5, codes: [49])),
            .cap(KeyCap(label: "⌘", width: 1.25, codes: [54])),
            .cap(KeyCap(label: "⌥", width: 1, codes: [61])),
            .cap(KeyCap(label: "←", width: 1, codes: [123])),
            .cap(KeyCap(label: "↓", width: 1, codes: [125])),
            .cap(KeyCap(label: "→", width: 1, codes: [124])),
        ],
    ]
}

private struct KeyCapView: View {
    let cap: KeyCap
    let isActive: Bool
    let unit: CGFloat
    let spacing: CGFloat
    let isLight: Bool

    var body: some View {
        let fs = unit / 26
        VStack(spacing: 0) {
            if let sub = cap.sub {
                Text(sub)
                    .font(.system(size: 8 * fs, weight: .medium, design: .rounded))
                    .opacity(isActive ? 1 : 0.75)
                Text(cap.label)
                    .font(.system(size: 10.5 * fs, weight: .medium, design: .rounded))
            } else {
                Text(cap.label)
                    .font(.system(size: 11 * fs, weight: .medium, design: .rounded))
            }
        }
        .foregroundStyle(isActive ? Color.white : (isLight ? Color.black.opacity(0.7) : Color.white.opacity(0.65)))
        .frame(width: cap.width * unit + (cap.width - 1) * spacing, height: unit)
        .background(
            RoundedRectangle(cornerRadius: 5 * fs, style: .continuous)
                .fill(isActive ? Color.accentColor : (isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.14)))
        )
        .animation(.easeOut(duration: 0.08), value: isActive)
    }
}

/// 1u cap split by a bottom-left → top-right diagonal. The upper-left
/// triangle is esc, the lower-right triangle is backtick; each half lights
/// up independently.
private struct SplitCapView: View {
    let escActive: Bool
    let tickActive: Bool
    let unit: CGFloat
    let isLight: Bool

    var body: some View {
        let fs = unit / 26
        let textColor = isLight ? Color.black.opacity(0.7) : Color.white.opacity(0.65)
        ZStack {
            RoundedRectangle(cornerRadius: 5 * fs, style: .continuous)
                .fill(isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.14))
            UpperLeftTriangle()
                .fill(Color.accentColor)
                .opacity(escActive ? 1 : 0)
            LowerRightTriangle()
                .fill(Color.accentColor)
                .opacity(tickActive ? 1 : 0)
            DiagonalLine()
                .stroke(isLight ? Color.black.opacity(0.25) : Color.white.opacity(0.3),
                        lineWidth: max(1, fs))
            Text("esc")
                .font(.system(size: 7.5 * fs, weight: .medium, design: .rounded))
                .foregroundStyle(escActive ? Color.white : textColor)
                .padding([.leading, .top], 2.5 * fs)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Text("`~")
                .font(.system(size: 7.5 * fs, weight: .medium, design: .rounded))
                .foregroundStyle(tickActive ? Color.white : textColor)
                .padding([.trailing, .bottom], 2.5 * fs)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5 * fs, style: .continuous))
        .frame(width: unit, height: unit)
        .animation(.easeOut(duration: 0.08), value: escActive)
        .animation(.easeOut(duration: 0.08), value: tickActive)
    }
}

/// Right shift rendered as a "gate": a full-width top bar with two legs
/// hanging down, leaving a notch for the embedded half-height up arrow.
private struct GateShiftView: View {
    let shiftActive: Bool
    let upActive: Bool
    let unit: CGFloat
    let spacing: CGFloat
    let isLight: Bool

    private var fs: CGFloat { unit / 26 }
    private var totalWidth: CGFloat { 2.75 * unit + 1.75 * spacing }
    private var barHeight: CGFloat { (unit - spacing) / 2 }
    /// X of the up-arrow slot inside the gate; aligns ↑ exactly with ↓ below.
    private var upX: CGFloat { 0.75 * (unit + spacing) }

    var body: some View {
        let innerGap = spacing / 2
        let inactiveFill = isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.14)
        let textColor = isLight ? Color.black.opacity(0.7) : Color.white.opacity(0.65)
        ZStack(alignment: .topLeading) {
            GateShape(slotX: upX - innerGap,
                      slotWidth: unit + innerGap * 2,
                      barHeight: barHeight,
                      cornerRadius: 5 * fs)
                .fill(shiftActive ? Color.accentColor : inactiveFill)
            Text("⇧")
                .font(.system(size: 11 * fs, weight: .medium, design: .rounded))
                .foregroundStyle(shiftActive ? Color.white : textColor)
                .frame(width: totalWidth, height: barHeight)
            Text("↑")
                .font(.system(size: 9 * fs, weight: .medium, design: .rounded))
                .foregroundStyle(upActive ? Color.white : textColor)
                .frame(width: unit, height: barHeight)
                .background(
                    RoundedRectangle(cornerRadius: 4 * fs, style: .continuous)
                        .fill(upActive ? Color.accentColor : inactiveFill)
                )
                .offset(x: upX, y: barHeight + spacing)
        }
        .frame(width: totalWidth, height: unit)
        .animation(.easeOut(duration: 0.08), value: shiftActive)
        .animation(.easeOut(duration: 0.08), value: upActive)
    }
}

/// "Gate" outline: top bar plus two legs, with a notch for the up arrow.
private struct GateShape: Shape {
    /// Notch horizontal range: [slotX, slotX + slotWidth].
    let slotX: CGFloat
    let slotWidth: CGFloat
    let barHeight: CGFloat
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = cornerRadius
        let w = rect.width
        let h = rect.height
        let slotL = slotX
        let slotR = slotX + slotWidth
        return Path { p in
            p.move(to: CGPoint(x: r, y: 0))
            p.addLine(to: CGPoint(x: w - r, y: 0))
            p.addArc(center: CGPoint(x: w - r, y: r), radius: r,
                     startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            p.addLine(to: CGPoint(x: w, y: h - r))
            p.addArc(center: CGPoint(x: w - r, y: h - r), radius: r,
                     startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            p.addLine(to: CGPoint(x: slotR, y: h))
            p.addLine(to: CGPoint(x: slotR, y: barHeight))
            p.addLine(to: CGPoint(x: slotL, y: barHeight))
            p.addLine(to: CGPoint(x: slotL, y: h))
            p.addLine(to: CGPoint(x: r, y: h))
            p.addArc(center: CGPoint(x: r, y: h - r), radius: r,
                     startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            p.addLine(to: CGPoint(x: 0, y: r))
            p.addArc(center: CGPoint(x: r, y: r), radius: r,
                     startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            p.closeSubpath()
        }
    }
}

/// Upper-left triangle of a rect (bounded by the bottom-left → top-right diagonal).
private struct UpperLeftTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: .zero)
            p.addLine(to: CGPoint(x: rect.maxX, y: 0))
            p.addLine(to: CGPoint(x: 0, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

/// Lower-right triangle of a rect (bounded by the bottom-left → top-right diagonal).
private struct LowerRightTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.maxX, y: 0))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: 0, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

/// The bottom-left → top-right diagonal divider.
private struct DiagonalLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: 0))
        }
    }
}
