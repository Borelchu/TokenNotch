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
        if remaining > 50 { return .green }
        if remaining > 20 { return .yellow }
        return .red
    }
}

// MARK: - Compact views (always visible beside the notch)

/// 10fps is plenty for the wiggle animations and keeps the always-on views
/// cheap; time flows into the characters so motion is a pure function of it.
private let characterFPS: Double = 1.0 / 10.0

struct CompactLeadingView: View {
    @ObservedObject var model: UsageModel

    var body: some View {
        let mood = Mood.from(window: model.fiveHour, hasError: model.errorMessage != nil)
        TimelineView(.animation(minimumInterval: characterFPS)) { context in
            HStack(spacing: 2) {
                ClawdView(mood: mood, t: context.date.timeIntervalSinceReferenceDate)
                Text(UsageFormat.percent(model.fiveHour?.remainingPercent))
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(mood.tint)
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
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(mood.tint)
                CodexPetView(mood: mood, t: context.date.timeIntervalSinceReferenceDate)
            }
        }
    }
}

// MARK: - Expanded view (shown on hover)

struct ExpandedView: View {
    @ObservedObject var model: UsageModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .leading, spacing: 10) {
                header

                providerHeader("Claude Code") { t in
                    ClawdView(mood: claudeMood, t: t, scale: 1.3)
                }
                if let error = model.errorMessage {
                    errorText(error)
                }
                usageRow(
                    title: "5시간 세션",
                    window: model.fiveHour,
                    resetText: "\(UsageFormat.clockTime(model.fiveHour?.resetsAt)) 리셋 · \(UsageFormat.countdown(to: model.fiveHour?.resetsAt, from: context.date))"
                )
                usageRow(
                    title: "주간 (전체)",
                    window: model.sevenDay,
                    resetText: "\(UsageFormat.dayTime(model.sevenDay?.resetsAt)) 리셋"
                )
                if model.sevenDayOpus?.utilization != nil {
                    usageRow(
                        title: "주간 (Opus)",
                        window: model.sevenDayOpus,
                        resetText: "\(UsageFormat.dayTime(model.sevenDayOpus?.resetsAt)) 리셋"
                    )
                }
                if model.sevenDaySonnet?.utilization != nil {
                    usageRow(
                        title: "주간 (Sonnet)",
                        window: model.sevenDaySonnet,
                        resetText: "\(UsageFormat.dayTime(model.sevenDaySonnet?.resetsAt)) 리셋"
                    )
                }

                Divider().overlay(Color.gray.opacity(0.4))

                providerHeader(codexTitle) { t in
                    CodexPetView(mood: codexMood, t: t, scale: 1.3)
                }
                if let error = model.codexErrorMessage {
                    errorText(error)
                } else {
                    if model.codexFiveHour != nil {
                        usageRow(
                            title: "5시간 세션",
                            window: model.codexFiveHour,
                            resetText: "\(UsageFormat.clockTime(model.codexFiveHour?.resetsAt)) 리셋 · \(UsageFormat.countdown(to: model.codexFiveHour?.resetsAt, from: context.date))"
                        )
                    }
                    usageRow(
                        title: "주간",
                        window: model.codexSevenDay,
                        resetText: "\(UsageFormat.dayTime(model.codexSevenDay?.resetsAt)) 리셋 · \(UsageFormat.countdown(to: model.codexSevenDay?.resetsAt, from: context.date))"
                    )
                }
            }
            .padding(4)
            .frame(width: 280)
        }
    }

    private var codexTitle: String {
        if let plan = model.codexPlan, !plan.isEmpty {
            return "Codex (\(plan))"
        }
        return "Codex"
    }

    private var claudeMood: Mood {
        Mood.from(window: model.fiveHour, hasError: model.errorMessage != nil)
    }

    private var codexMood: Mood {
        Mood.from(
            window: model.codexFiveHour ?? model.codexSevenDay,
            hasError: model.codexErrorMessage != nil
        )
    }

    private func providerHeader(_ title: String, @ViewBuilder character: @escaping (TimeInterval) -> some View) -> some View {
        HStack(spacing: 6) {
            TimelineView(.animation(minimumInterval: characterFPS)) { context in
                character(context.date.timeIntervalSinceReferenceDate)
            }
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
    }

    private func errorText(_ message: String) -> some View {
        Text(message)
            .font(.caption2)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var header: some View {
        HStack {
            Text("TokenNotch")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            if let updated = model.lastUpdated {
                Text(UsageFormat.clockTime(updated))
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .buttonStyle(.plain)
            .help("NotchUsage 종료")
        }
    }

    private func usageRow(title: String, window: UsageWindow?, resetText: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white)
                Spacer()
                Text("남음 \(UsageFormat.percent(window?.remainingPercent))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(UsageFormat.statusColor(remaining: window?.remainingPercent))
            }
            ProgressView(value: min(max(window?.utilization ?? 0, 0), 100), total: 100)
                .tint(UsageFormat.statusColor(remaining: window?.remainingPercent))
            Text(resetText)
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.gray)
        }
    }
}
