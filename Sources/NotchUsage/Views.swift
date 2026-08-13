import SwiftUI

// MARK: - Formatting helpers

enum UsageFormat {
    static func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded()))%"
    }

    static func clockTime(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func dayTime(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d(E) HH:mm"
        return formatter.string(from: date)
    }

    static func countdown(to date: Date?, from now: Date = Date()) -> String {
        guard let date else { return "—" }
        let seconds = Int(date.timeIntervalSince(now))
        if seconds <= 0 { return "곧 리셋" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours >= 24 {
            return "\(hours / 24)일 \(hours % 24)시간 후"
        }
        if hours > 0 {
            return "\(hours)시간 \(minutes)분 후"
        }
        return "\(minutes)분 후"
    }

    static func statusColor(remaining: Double?) -> Color {
        guard let remaining else { return .gray }
        if remaining > 50 { return Color(red: 0.55, green: 0.85, blue: 0.45) }
        if remaining > 20 { return Color(red: 1.0, green: 0.8, blue: 0.35) }
        return Color(red: 1.0, green: 0.45, blue: 0.45)
    }

    static func phrase(for mood: Mood) -> String {
        switch mood {
        case .happy: return "아직 든든해요!"
        case .worried: return "아껴 써야 해요…"
        case .critical: return "거의 다 썼어요!!"
        case .sleeping: return "쉬는 중… zzz"
        }
    }
}

// MARK: - Compact views (always visible beside the notch)

/// 10fps is plenty for the wiggle animations and keeps the always-on views
/// cheap; time flows into the characters so motion is a pure function of it.
let characterFPS: Double = 1.0 / 10.0

struct CompactLeadingView: View {
    @ObservedObject var model: UsageModel

    var body: some View {
        let mood = Mood.from(window: model.fiveHour, hasError: model.errorMessage != nil)
        TimelineView(.animation(minimumInterval: characterFPS)) { context in
            HStack(spacing: 2) {
                ClawdView(mood: mood, t: context.date.timeIntervalSinceReferenceDate)
                Text(UsageFormat.percent(model.fiveHour?.remainingPercent))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(UsageFormat.statusColor(remaining: model.fiveHour?.remainingPercent))
            }
        }
    }
}

struct CompactTrailingView: View {
    @ObservedObject var model: UsageModel

    var body: some View {
        // A Plus plan may only report a weekly window — show what exists.
        let window = model.codexFiveHour ?? model.codexSevenDay
        let mood = Mood.from(window: window, hasError: model.codexErrorMessage != nil)
        TimelineView(.animation(minimumInterval: characterFPS)) { context in
            HStack(spacing: 2) {
                Text(UsageFormat.percent(window?.remainingPercent))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(UsageFormat.statusColor(remaining: window?.remainingPercent))
                CodexPetView(mood: mood, t: context.date.timeIntervalSinceReferenceDate)
            }
        }
    }
}

// MARK: - Expanded view (shown on hover)

struct ExpandedView: View {
    @ObservedObject var model: UsageModel

    private let claudeTint = ClawdSprite.bodyColor
    private let codexTint = Color(red: 0.47, green: 0.62, blue: 0.98)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .leading, spacing: 8) {
                header

                providerCard(
                    title: "Claude Code",
                    tint: claudeTint,
                    mood: claudeMood,
                    error: model.errorMessage,
                    character: { t in ClawdView(mood: claudeMood, t: t, scale: 1.4) },
                    rows: claudeRows(now: context.date)
                )

                providerCard(
                    title: codexTitle,
                    tint: codexTint,
                    mood: codexMood,
                    error: model.codexErrorMessage,
                    character: { t in CodexPetView(mood: codexMood, t: t, scale: 1.4) },
                    rows: codexRows(now: context.date)
                )
            }
            .padding(6)
            .frame(width: 296)
        }
    }

    // MARK: Moods

    private var claudeMood: Mood {
        Mood.from(window: model.fiveHour, hasError: model.errorMessage != nil)
    }

    private var codexMood: Mood {
        Mood.from(
            window: model.codexFiveHour ?? model.codexSevenDay,
            hasError: model.codexErrorMessage != nil
        )
    }

    private var codexTitle: String {
        if let plan = model.codexPlan, !plan.isEmpty {
            return "Codex (\(plan.capitalized))"
        }
        return "Codex"
    }

    // MARK: Rows

    private func claudeRows(now: Date) -> [(String, UsageWindow?, String)] {
        var rows: [(String, UsageWindow?, String)] = [
            (
                "5시간 세션",
                model.fiveHour,
                "\(UsageFormat.clockTime(model.fiveHour?.resetsAt)) 리셋 · \(UsageFormat.countdown(to: model.fiveHour?.resetsAt, from: now))"
            ),
            (
                "주간 (전체)",
                model.sevenDay,
                "\(UsageFormat.dayTime(model.sevenDay?.resetsAt)) 리셋"
            ),
        ]
        if model.sevenDayOpus?.utilization != nil {
            rows.append(("주간 (Opus)", model.sevenDayOpus, "\(UsageFormat.dayTime(model.sevenDayOpus?.resetsAt)) 리셋"))
        }
        if model.sevenDaySonnet?.utilization != nil {
            rows.append(("주간 (Sonnet)", model.sevenDaySonnet, "\(UsageFormat.dayTime(model.sevenDaySonnet?.resetsAt)) 리셋"))
        }
        return rows
    }

    private func codexRows(now: Date) -> [(String, UsageWindow?, String)] {
        var rows: [(String, UsageWindow?, String)] = []
        if model.codexFiveHour != nil {
            rows.append((
                "5시간 세션",
                model.codexFiveHour,
                "\(UsageFormat.clockTime(model.codexFiveHour?.resetsAt)) 리셋 · \(UsageFormat.countdown(to: model.codexFiveHour?.resetsAt, from: now))"
            ))
        }
        rows.append((
            "주간",
            model.codexSevenDay,
            "\(UsageFormat.dayTime(model.codexSevenDay?.resetsAt)) 리셋 · \(UsageFormat.countdown(to: model.codexSevenDay?.resetsAt, from: now))"
        ))
        return rows
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 5) {
            Text("✦")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.4))
            Text("TokenNotch")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            if let updated = model.lastUpdated {
                Text("\(UsageFormat.clockTime(updated)) 갱신")
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.45))
            }
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(3)
                    .background(Circle().fill(.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .help("NotchUsage 종료")
        }
        .padding(.horizontal, 2)
    }

    private func providerCard(
        title: String,
        tint: Color,
        mood: Mood,
        error: String?,
        character: @escaping (TimeInterval) -> some View,
        rows: [(String, UsageWindow?, String)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                TimelineView(.animation(minimumInterval: characterFPS)) { context in
                    character(context.date.timeIntervalSinceReferenceDate)
                }
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: 4)
                speechBubble(UsageFormat.phrase(for: mood))
            }

            if let error {
                Text(error)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(rows, id: \.0) { row in
                cuteRow(title: row.0, window: row.1, resetText: row.2)
            }
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(tint.opacity(0.13))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(tint.opacity(0.3), lineWidth: 1)
        )
    }

    private func speechBubble(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(.white.opacity(0.12)))
            .lineLimit(1)
    }

    private func cuteRow(title: String, window: UsageWindow?, resetText: String) -> some View {
        let remaining = window?.remainingPercent
        let color = UsageFormat.statusColor(remaining: remaining)
        return VStack(alignment: .leading, spacing: 3.5) {
            HStack {
                Text(title)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text("남음 \(UsageFormat.percent(remaining))")
                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.black.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(color))
            }
            HPBar(remainingFraction: (remaining ?? 0) / 100, color: color)
            Text(resetText)
                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

/// Game-style HP bar: the filled part is what you have LEFT.
private struct HPBar: View {
    let remainingFraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.1))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.65)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(7, geo.size.width * min(max(remainingFraction, 0), 1)))
                    .overlay(alignment: .top) {
                        // little glossy highlight, very video-gamey
                        Capsule()
                            .fill(.white.opacity(0.35))
                            .frame(width: max(0, geo.size.width * min(max(remainingFraction, 0), 1) - 6), height: 1.6)
                            .offset(y: 1.3)
                    }
            }
        }
        .frame(height: 7)
    }
}
