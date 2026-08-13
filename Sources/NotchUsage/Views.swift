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

struct CompactLeadingView: View {
    @ObservedObject var model: UsageModel

    var body: some View {
        Image(systemName: model.errorMessage == nil ? "asterisk" : "exclamationmark.triangle.fill")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(UsageFormat.statusColor(remaining: model.fiveHour?.remainingPercent))
    }
}

struct CompactTrailingView: View {
    @ObservedObject var model: UsageModel

    var body: some View {
        Text(trailingText)
            .font(.system(size: 11, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
    }

    private var trailingText: String {
        guard model.errorMessage == nil else { return "!" }
        let remaining = UsageFormat.percent(model.fiveHour?.remainingPercent)
        let reset = UsageFormat.clockTime(model.fiveHour?.resetsAt)
        return "\(remaining) · \(reset)"
    }
}

// MARK: - Expanded view (shown on hover)

struct ExpandedView: View {
    @ObservedObject var model: UsageModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .leading, spacing: 10) {
                header

                if let error = model.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
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
            }
            .padding(4)
            .frame(width: 280)
        }
    }

    private var header: some View {
        HStack {
            Text("Claude Code 사용량")
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
