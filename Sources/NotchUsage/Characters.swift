import SwiftUI

// MARK: - Mood

enum Mood {
    case happy      // >50% remaining: relaxed stroll
    case worried    // 20–50%: sweating, hurried
    case critical   // <20%: trembling
    case sleeping   // error / expired token: zzz

    static func from(window: UsageWindow?, hasError: Bool) -> Mood {
        if hasError { return .sleeping }
        guard let remaining = window?.remainingPercent else { return .sleeping }
        if remaining > 50 { return .happy }
        if remaining > 20 { return .worried }
        return .critical
    }

    var tint: Color {
        switch self {
        case .happy: return .green
        case .worried: return .yellow
        case .critical: return .red
        case .sleeping: return .gray
        }
    }
}

// MARK: - Clawd (the official Claude Code pixel crab)

/// Faithful reproduction of the Clawd sprite shipped inside Claude Code's CLI.
/// The original is terminal art built from quadrant block characters, three
/// cells tall, with poses that only change the eye/claw glyphs:
///
///      ▐▛███▜▌        ▗▟▛███▜▙▖
///     ▝▜█████▛▘        ▜█████▛      feet:  ▘▘ ▝▝
///       ▘▘ ▝▝
///     (standing)       (arms-up)
///
/// The eye row is drawn body-on-black, so the unfilled quadrants become the
/// eyes. We decode each character into a 2×2 quadrant grid and render the
/// result as square pixels — identical geometry to the terminal original.
enum ClawdSprite {
    /// clawd_body in every Claude Code theme: rgb(215,119,87)
    static let bodyColor = Color(red: 215 / 255, green: 119 / 255, blue: 87 / 255)

    enum Pose {
        case standing, lookLeft, lookRight, armsUp
    }

    enum Pixel: UInt8 {
        case clear, body, dark
    }

    static let gridWidth = 18
    static let gridHeight = 6

    /// Official pose table (verbatim from the CLI's mini-Clawd component).
    static func grid(pose: Pose, eyesClosed: Bool) -> [[Pixel]] {
        let r1L: String, eye: String, r1R: String, r2L: String, r2R: String
        switch pose {
        case .standing:  (r1L, eye, r1R, r2L, r2R) = (" ▐", "▛███▜", "▌", "▝▜", "▛▘")
        case .lookLeft:  (r1L, eye, r1R, r2L, r2R) = (" ▐", "▟███▟", "▌", "▝▜", "▛▘")
        case .lookRight: (r1L, eye, r1R, r2L, r2R) = (" ▐", "▙███▙", "▌", "▝▜", "▛▘")
        case .armsUp:    (r1L, eye, r1R, r2L, r2R) = ("▗▟", "▛███▜", "▙▖", " ▜", "▛ ")
        }
        let rows: [[(text: String, onBlack: Bool)]] = [
            [(r1L, false), (eyesClosed ? "█████" : eye, true), (r1R, false)],
            [(r2L, false), ("█████", true), (r2R, false)],
            [("  ▘▘ ▝▝  ", false)],
        ]

        var grid = Array(repeating: Array(repeating: Pixel.clear, count: gridWidth), count: gridHeight)
        for (rowIndex, segments) in rows.enumerated() {
            var col = 0
            for segment in segments {
                for ch in segment.text {
                    let q = quads(ch)
                    for (filled, dr, dc) in [(q.tl, 0, 0), (q.tr, 0, 1), (q.bl, 1, 0), (q.br, 1, 1)] {
                        grid[rowIndex * 2 + dr][col * 2 + dc] =
                            filled ? .body : (segment.onBlack ? .dark : .clear)
                    }
                    col += 1
                }
            }
        }
        return grid
    }

    private static func quads(_ c: Character) -> (tl: Bool, tr: Bool, bl: Bool, br: Bool) {
        switch c {
        case "█": return (true, true, true, true)
        case "▛": return (true, true, true, false)
        case "▜": return (true, true, false, true)
        case "▙": return (true, false, true, true)
        case "▟": return (false, true, true, true)
        case "▐": return (false, true, false, true)
        case "▌": return (true, false, true, false)
        case "▀": return (true, true, false, false)
        case "▄": return (false, false, true, true)
        case "▘": return (true, false, false, false)
        case "▝": return (false, true, false, false)
        case "▖": return (false, false, true, false)
        case "▗": return (false, false, false, true)
        default:  return (false, false, false, false)
        }
    }
}

struct ClawdView: View {
    let mood: Mood
    let t: TimeInterval
    var scale: CGFloat = 1

    private var px: CGFloat { 1.7 * scale }

    private var patrolPeriod: Double { mood == .happy ? 6.0 : 3.5 }

    /// -1...1 triangle wave: Clawd patrols sideways, as crabs do.
    private var patrolPhase: Double {
        let phase = (t / patrolPeriod).truncatingRemainder(dividingBy: 1)
        return abs(phase * 2 - 1) * 2 - 1
    }

    private var walking: Bool { mood == .happy || mood == .worried }

    private var pose: ClawdSprite.Pose {
        switch mood {
        case .sleeping: return .standing
        case .critical: return .armsUp // panic!
        case .happy, .worried:
            // Raise arms briefly at each patrol turnaround, otherwise look
            // where we're headed (triangle wave falls first, so falling = left).
            if abs(patrolPhase) > 0.92 { return .armsUp }
            let phase = (t / patrolPeriod).truncatingRemainder(dividingBy: 1)
            return phase < 0.5 ? .lookLeft : .lookRight
        }
    }

    private var eyesClosed: Bool {
        if mood == .sleeping { return true }
        let n = sin(t * 1.7) * sin(t * 2.3)
        return n > 0.93
    }

    private var bob: CGFloat {
        guard walking else { return 0 }
        return CGFloat(abs(sin(t * (mood == .happy ? 6 : 11)))) * -1.5
    }

    private var tremble: CGFloat {
        mood == .critical ? CGFloat(sin(t * 40)) * 0.8 : 0
    }

    var body: some View {
        Canvas { context, _ in
            let grid = ClawdSprite.grid(pose: pose, eyesClosed: eyesClosed)
            for (row, cells) in grid.enumerated() {
                for (col, cell) in cells.enumerated() where cell != .clear {
                    let rect = CGRect(
                        x: CGFloat(col) * px, y: CGFloat(row) * px,
                        width: px + 0.3, height: px + 0.3
                    )
                    context.fill(
                        Path(rect),
                        with: .color(cell == .body ? ClawdSprite.bodyColor : .black)
                    )
                }
            }
        }
        .frame(width: CGFloat(ClawdSprite.gridWidth) * px, height: CGFloat(ClawdSprite.gridHeight) * px)
        .overlay(alignment: .topTrailing) {
            if mood == .worried || mood == .critical { sweatDrop }
            if mood == .sleeping { sleepZs }
        }
        .offset(x: CGFloat(patrolPhase) * 5 + tremble, y: bob)
        .frame(width: CGFloat(ClawdSprite.gridWidth) * px + 12, height: max(18, CGFloat(ClawdSprite.gridHeight) * px + 4))
    }

    private var sweatDrop: some View {
        Circle()
            .fill(Color(red: 0.4, green: 0.7, blue: 1.0))
            .frame(width: 2.6, height: 2.6)
            .offset(
                x: 1,
                y: -3 + CGFloat((t * 2).truncatingRemainder(dividingBy: 1)) * 4
            )
    }

    private var sleepZs: some View {
        let phase = (t / 2).truncatingRemainder(dividingBy: 1)
        return Text("z")
            .font(.system(size: 6, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(1 - phase))
            .offset(x: 2, y: -2 - CGFloat(phase) * 5)
    }
}

// MARK: - Codex bot

/// A tiny teal robot face with an antenna, sharing Clawd's mood language.
struct CodexBotView: View {
    let mood: Mood
    let t: TimeInterval
    var scale: CGFloat = 1

    private var speed: Double {
        switch mood {
        case .happy: return 4
        case .worried: return 9
        case .critical: return 13
        case .sleeping: return 0
        }
    }

    private var bob: CGFloat {
        mood == .sleeping ? 0 : CGFloat(sin(t * speed)) * 1.0
    }

    private var tremble: CGFloat {
        mood == .critical ? CGFloat(sin(t * 40)) * 0.8 : 0
    }

    private var blinking: Bool {
        if mood == .sleeping { return true }
        let n = sin(t * 1.9 + 1) * sin(t * 2.7)
        return n > 0.93
    }

    private let botTeal = Color(red: 0.35, green: 0.78, blue: 0.72)

    var body: some View {
        ZStack {
            // Antenna, tip blinking with mood color
            Rectangle()
                .fill(botTeal)
                .frame(width: 1.2, height: 3)
                .offset(y: -7.5)
            Circle()
                .fill(mood.tint)
                .frame(width: 2.6, height: 2.6)
                .offset(y: -9.5)
                .opacity(mood == .sleeping ? 0.4 : (0.6 + 0.4 * sin(t * speed)))

            // Head
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(botTeal)
                .frame(width: 14, height: 11)
                .offset(y: 0.5)

            // Eyes
            ForEach(0..<2, id: \.self) { side in
                let sign: CGFloat = side == 0 ? -1 : 1
                Capsule()
                    .fill(.black)
                    .frame(width: 2.4, height: blinking ? 0.8 : 3.6)
                    .offset(x: sign * 3.2, y: 0)
            }

            // Mouth
            Capsule()
                .fill(.black.opacity(0.7))
                .frame(width: mood == .critical ? 3 : 5, height: 1.2)
                .offset(y: 3.6)

            if mood == .sleeping {
                sleepZs
            }
        }
        .frame(width: 24, height: 18)
        .offset(x: tremble, y: bob)
        .scaleEffect(scale)
        .frame(width: 24 * scale, height: 18 * scale)
    }

    private var sleepZs: some View {
        let phase = (t / 2).truncatingRemainder(dividingBy: 1)
        return Text("z")
            .font(.system(size: 6, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(1 - phase))
            .offset(x: 9, y: -5 - CGFloat(phase) * 5)
    }
}
