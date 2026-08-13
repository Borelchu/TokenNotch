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

// MARK: - Clawd (Claude's crab)

/// A tiny orange crab drawn with plain SwiftUI shapes, sized for the
/// menubar-height compact area. `t` is a continuous time value; all motion is
/// a pure function of it so the view stays cheap to re-render.
struct ClawdView: View {
    let mood: Mood
    let t: TimeInterval
    var scale: CGFloat = 1

    private var walkSpeed: Double {
        switch mood {
        case .happy: return 5
        case .worried: return 10
        case .critical: return 14
        case .sleeping: return 0
        }
    }

    /// Crabs walk sideways: patrol ±6pt inside the compact slot.
    private var patrolOffset: CGFloat {
        guard mood == .happy || mood == .worried else { return 0 }
        let period: Double = mood == .happy ? 6.0 : 3.5
        let phase = (t / period).truncatingRemainder(dividingBy: 1)
        let triangle = abs(phase * 2 - 1) * 2 - 1 // -1...1 triangle wave
        return CGFloat(triangle) * 6
    }

    private var bob: CGFloat {
        mood == .sleeping ? 0 : CGFloat(sin(t * walkSpeed)) * 1.2
    }

    private var tremble: CGFloat {
        mood == .critical ? CGFloat(sin(t * 40)) * 0.8 : 0
    }

    /// Blink roughly every ~4s using overlapping sines as cheap pseudo-noise.
    private var blinking: Bool {
        if mood == .sleeping { return true }
        let n = sin(t * 1.7) * sin(t * 2.3)
        return n > 0.93
    }

    private let clawdOrange = Color(red: 0.85, green: 0.47, blue: 0.34)

    var body: some View {
        ZStack {
            // Claws, tucked at the sides and bobbing out of phase
            clawPair

            // Legs
            legRow

            // Body
            Ellipse()
                .fill(clawdOrange)
                .frame(width: 15, height: 10)
                .offset(y: 2)

            // Eyes
            eyes

            // Mood extras
            if mood == .worried || mood == .critical {
                sweatDrop
            }
            if mood == .sleeping {
                sleepZs
            }
        }
        .frame(width: 24, height: 18)
        .offset(x: patrolOffset + tremble, y: bob)
        .scaleEffect(scale)
        .frame(width: 24 * scale, height: 18 * scale)
    }

    private var clawPair: some View {
        ForEach(0..<2, id: \.self) { side in
            let sign: CGFloat = side == 0 ? -1 : 1
            let wave = sin(t * walkSpeed + Double(side) * .pi)
            Circle()
                .fill(clawdOrange)
                .frame(width: 5.5, height: 5.5)
                .overlay( // pincer notch
                    Circle()
                        .fill(.black)
                        .frame(width: 2.2, height: 2.2)
                        .offset(x: sign * 1.6, y: -1.2)
                        .blendMode(.destinationOut)
                )
                .compositingGroup()
                .offset(
                    x: sign * 9,
                    y: -1 + CGFloat(mood == .sleeping ? 0 : wave) * 1.2
                )
        }
    }

    private var legRow: some View {
        ForEach(0..<3, id: \.self) { i in
            let x = CGFloat(i - 1) * 4.4
            let wave = mood == .sleeping ? 0 : sin(t * walkSpeed + Double(i) * 2.1)
            Capsule()
                .fill(clawdOrange.opacity(0.9))
                .frame(width: 1.6, height: 4)
                .offset(x: x, y: 7 + CGFloat(wave) * 0.8)
        }
    }

    private var eyes: some View {
        ForEach(0..<2, id: \.self) { side in
            let sign: CGFloat = side == 0 ? -1 : 1
            ZStack {
                Circle().fill(.white).frame(width: 4.4, height: 4.4)
                Circle().fill(.black).frame(width: 2, height: 2).offset(y: 0.3)
            }
            .scaleEffect(y: blinking ? 0.15 : 1)
            .offset(x: sign * 3, y: -2.5)
        }
    }

    private var sweatDrop: some View {
        Circle()
            .fill(Color(red: 0.4, green: 0.7, blue: 1.0))
            .frame(width: 2.6, height: 2.6)
            .offset(
                x: 8,
                y: -6 + CGFloat((t * 2).truncatingRemainder(dividingBy: 1)) * 3
            )
            .opacity(mood == .critical ? 1 : 0.85)
    }

    private var sleepZs: some View {
        let phase = (t / 2).truncatingRemainder(dividingBy: 1)
        return Text("z")
            .font(.system(size: 6, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(1 - phase))
            .offset(x: 8, y: -4 - CGFloat(phase) * 5)
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
