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
        formatter.locale = L10n.dayTimeLocale
        formatter.dateFormat = L10n.dayTimeFormat
        return formatter.string(from: date)
    }

    static func countdown(to date: Date?, from now: Date = Date()) -> String {
        guard let date else { return "—" }
        let seconds = Int(date.timeIntervalSince(now))
        if seconds <= 0 { return L10n.resetSoon }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours >= 24 {
            return L10n.inDaysHours(hours / 24, hours % 24)
        }
        if hours > 0 {
            return L10n.inHoursMinutes(hours, minutes)
        }
        return L10n.inMinutes(minutes)
    }

    static func statusColor(remaining: Double?) -> Color {
        guard let remaining else { return .gray }
        if remaining > 50 { return Color(red: 0.55, green: 0.85, blue: 0.45) }
        if remaining > 20 { return Color(red: 1.0, green: 0.8, blue: 0.35) }
        return Color(red: 1.0, green: 0.45, blue: 0.45)
    }

    static func phrase(for mood: Mood) -> String {
        L10n.phrase(for: mood)
    }

    /// 1234 → "1.2K", 45_600_000 → "46M" — compact token counts.
    static func tokens(_ n: Int) -> String {
        func short(_ value: Double, _ suffix: String) -> String {
            let text = String(format: value < 10 ? "%.1f" : "%.0f", value)
            return text.replacingOccurrences(of: ".0", with: "") + suffix
        }
        if n >= 1_000_000_000 { return short(Double(n) / 1e9, "B") }
        if n >= 1_000_000 { return short(Double(n) / 1e6, "M") }
        if n >= 1_000 { return short(Double(n) / 1e3, "K") }
        return "\(n)"
    }

    /// Narrow weekday letter ("월" / "M") for the daily bar chart.
    static func weekdayNarrow(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = L10n.dayTimeLocale
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }
}

// MARK: - Display settings

enum DisplaySettings {
    static let showClaudeKey = "showClaude"
    static let showCodexKey = "showCodex"
}

// MARK: - Compact views (always visible beside the notch)

/// 10fps is plenty for the wiggle animations and keeps the always-on views
/// cheap; time flows into the characters so motion is a pure function of it.
let characterFPS: Double = 1.0 / 10.0

struct CompactLeadingView: View {
    @ObservedObject var model: UsageModel
    @AppStorage(DisplaySettings.showClaudeKey) private var showClaude = true

    var body: some View {
        if showClaude {
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
        } else {
            Color.clear.frame(width: 1, height: 1)
        }
    }
}

struct CompactTrailingView: View {
    @ObservedObject var model: UsageModel
    @AppStorage(DisplaySettings.showCodexKey) private var showCodex = true

    var body: some View {
        if showCodex {
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
        } else {
            Color.clear.frame(width: 1, height: 1)
        }
    }
}

// MARK: - Expanded view (shown on hover)

struct ExpandedView: View {
    @ObservedObject var model: UsageModel
    @AppStorage(DisplaySettings.showClaudeKey) private var showClaude = true
    @AppStorage(DisplaySettings.showCodexKey) private var showCodex = true

    private let claudeTint = ClawdSprite.bodyColor
    private let codexTint = Color(red: 0.47, green: 0.62, blue: 0.98)

    /// NOTCH_DEMO_PAGE=1 opens on the stats page; =cycle flips pages every
    /// few seconds with the swipe animation (for README captures).
    private static let demoPage = ProcessInfo.processInfo.environment["NOTCH_DEMO_PAGE"]
    @State private var page = Int(demoPage ?? "") ?? 0
    @State private var pageDrag: CGFloat = 0
    private let pageWidth: CGFloat = 284

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .leading, spacing: 8) {
                header
                pager(now: context.date)
                pageDots
            }
            .padding(6)
            .frame(width: 296)
        }
        .onReceive(Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()) { _ in
            guard Self.demoPage == "cycle" else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                page = 1 - page
            }
        }
    }

    // MARK: Pages (swipe between usage and token stats)

    private func pager(now: Date) -> some View {
        HStack(alignment: .top, spacing: 0) {
            usagePage(now: now).frame(width: pageWidth)
            statsPage(now: now).frame(width: pageWidth)
        }
        .offset(x: -CGFloat(page) * pageWidth + pageDrag)
        .frame(width: pageWidth, alignment: .leading)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged { pageDrag = $0.translation.width }
                .onEnded { value in
                    let target: Int
                    if value.translation.width < -40 { target = 1 }
                    else if value.translation.width > 40 { target = 0 }
                    else { target = page }
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        page = target
                        pageDrag = 0
                    }
                }
        )
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .fill(.white.opacity(page == index ? 0.85 : 0.25))
                    .frame(width: 5, height: 5)
                    .contentShape(Circle().scale(2.5))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            page = index
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func usagePage(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if showClaude {
                providerCard(
                    title: "Claude Code",
                    tint: claudeTint,
                    mood: claudeMood,
                    error: model.errorMessage,
                    character: { t in ClawdView(mood: claudeMood, t: t, scale: 1.4) },
                    rows: claudeRows(now: now)
                )
            }

            if showCodex {
                providerCard(
                    title: codexTitle,
                    tint: codexTint,
                    mood: codexMood,
                    error: model.codexErrorMessage,
                    character: { t in CodexPetView(mood: codexMood, t: t, scale: 1.4) },
                    rows: codexRows(now: now)
                )
            }
        }
    }

    private func statsPage(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if showClaude {
                statsCard(title: "Claude Code", tint: claudeTint, daily: model.claudeDaily, now: now)
            }
            if showCodex {
                statsCard(title: codexTitle, tint: codexTint, daily: model.codexDaily, now: now)
            }
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
                L10n.fiveHourSession,
                model.fiveHour,
                "\(L10n.resets(at: UsageFormat.clockTime(model.fiveHour?.resetsAt))) · \(UsageFormat.countdown(to: model.fiveHour?.resetsAt, from: now))"
            ),
            (
                L10n.weeklyAll,
                model.sevenDay,
                L10n.resets(at: UsageFormat.dayTime(model.sevenDay?.resetsAt))
            ),
        ]
        if model.sevenDayOpus?.utilization != nil {
            rows.append((L10n.weeklyOpus, model.sevenDayOpus, L10n.resets(at: UsageFormat.dayTime(model.sevenDayOpus?.resetsAt))))
        }
        if model.sevenDaySonnet?.utilization != nil {
            rows.append((L10n.weeklySonnet, model.sevenDaySonnet, L10n.resets(at: UsageFormat.dayTime(model.sevenDaySonnet?.resetsAt))))
        }
        return rows
    }

    private func codexRows(now: Date) -> [(String, UsageWindow?, String)] {
        var rows: [(String, UsageWindow?, String)] = []
        if model.codexFiveHour != nil {
            rows.append((
                L10n.fiveHourSession,
                model.codexFiveHour,
                "\(L10n.resets(at: UsageFormat.clockTime(model.codexFiveHour?.resetsAt))) · \(UsageFormat.countdown(to: model.codexFiveHour?.resetsAt, from: now))"
            ))
        }
        rows.append((
            L10n.weekly,
            model.codexSevenDay,
            "\(L10n.resets(at: UsageFormat.dayTime(model.codexSevenDay?.resetsAt))) · \(UsageFormat.countdown(to: model.codexSevenDay?.resetsAt, from: now))"
        ))
        return rows
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 5) {
            TimelineView(.animation(minimumInterval: 0.25)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                Text("✦")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.4))
                    .opacity(0.55 + 0.45 * sin(t * 3))
            }
            Text("TokenNotch")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Spacer(minLength: 4)

            providerChip(isOn: showClaude, tint: claudeTint, action: toggleClaude) {
                ClawdView(mood: .happy, t: 0, scale: 0.7)
            }
            providerChip(isOn: showCodex, tint: codexTint, action: toggleCodex) {
                CodexPetView(mood: .happy, t: 0.4, scale: 0.7)
            }

            if let updated = model.lastUpdated {
                Text(UsageFormat.clockTime(updated))
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
            .help(L10n.quitHelp)
        }
        .padding(.horizontal, 2)
    }

    /// Keep at least one provider visible.
    private func toggleClaude() {
        if showClaude, !showCodex { showCodex = true }
        showClaude.toggle()
    }

    private func toggleCodex() {
        if showCodex, !showClaude { showClaude = true }
        showCodex.toggle()
    }

    private func providerChip(
        isOn: Bool,
        tint: Color,
        action: @escaping () -> Void,
        @ViewBuilder face: () -> some View
    ) -> some View {
        Button(action: action) {
            face()
                .frame(width: 24, height: 15)
                .padding(.horizontal, 3)
                .padding(.vertical, 2)
                .background(Capsule().fill(isOn ? tint.opacity(0.35) : .white.opacity(0.07)))
                .overlay(Capsule().stroke(isOn ? tint.opacity(0.9) : .white.opacity(0.2), lineWidth: 1))
                .opacity(isOn ? 1 : 0.4)
                .saturation(isOn ? 1 : 0)
        }
        .buttonStyle(.plain)
        .help(isOn ? L10n.chipHideHelp : L10n.chipShowHelp)
    }

    // MARK: Cards

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
                    let t = context.date.timeIntervalSinceReferenceDate
                    ZStack {
                        character(t)
                        if mood == .happy {
                            sparkle(t: t, offset: 0)
                            sparkle(t: t, offset: 0.55)
                        }
                    }
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
            // stitched-border look
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(tint.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3.5, 3]))
                .padding(1.5)
        )
    }

    // MARK: Stats card (page 2)

    private func statsCard(
        title: String,
        tint: Color,
        daily: [String: DayTokens],
        now: Date
    ) -> some View {
        let today = daily[LocalStats.dayKey(now)] ?? DayTokens()
        let week = weekTokens(daily, now: now)
        let days = lastDays(7, now: now)
        let maxTotal = max(1, days.map { daily[LocalStats.dayKey($0)]?.total ?? 0 }.max() ?? 1)

        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text(L10n.statsTokensUsed)
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }

            if daily.isEmpty {
                Text(L10n.statsEmpty)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                statLine(label: L10n.statsToday, tokens: today, tint: tint)
                statLine(label: L10n.statsThisWeek, tokens: week, tint: tint)

                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(days, id: \.self) { day in
                        let count = daily[LocalStats.dayKey(day)]?.total ?? 0
                        let isToday = Calendar.current.isDate(day, inSameDayAs: now)
                        VStack(spacing: 2) {
                            Text(count > 0 ? UsageFormat.tokens(count) : " ")
                                .font(.system(size: 6, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.55))
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(tint.opacity(isToday ? 1 : 0.5))
                                .frame(height: 4 + 24 * CGFloat(count) / CGFloat(maxTotal))
                            Text(UsageFormat.weekdayNarrow(day))
                                .font(.system(size: 6.5, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(isToday ? 0.9 : 0.4))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(tint.opacity(0.13))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(tint.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3.5, 3]))
                .padding(1.5)
        )
    }

    private func statLine(label: String, tokens: DayTokens, tint: Color) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            Text("\(L10n.statsIn) \(UsageFormat.tokens(tokens.input + tokens.cacheRead + tokens.cacheWrite)) · \(L10n.statsOut) \(UsageFormat.tokens(tokens.output))")
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.45))
            Text(UsageFormat.tokens(tokens.total))
                .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.black.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 1.5)
                .background(Capsule().fill(tint))
        }
    }

    private func weekTokens(_ daily: [String: DayTokens], now: Date) -> DayTokens {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return DayTokens() }
        var sum = DayTokens()
        var day = week.start
        while day < week.end {
            if let tokens = daily[LocalStats.dayKey(day)] { sum.add(tokens) }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return sum
    }

    private func lastDays(_ count: Int, now: Date) -> [Date] {
        (0..<count).reversed().compactMap {
            Calendar.current.date(byAdding: .day, value: -$0, to: now)
        }
    }

    private func sparkle(t: TimeInterval, offset: Double) -> some View {
        let phase = ((t / 2.4) + offset).truncatingRemainder(dividingBy: 1)
        return Text("✦")
            .font(.system(size: 6, weight: .black))
            .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.4))
            .opacity((1 - phase) * 0.9)
            .offset(
                x: CGFloat(sin((phase + offset) * 2 * .pi)) * 12,
                y: -6 - CGFloat(phase) * 9
            )
    }

    private func speechBubble(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(.white.opacity(0.12))
            )
            .background(alignment: .leading) {
                // bubble tail pointing back at the character
                Rectangle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 5, height: 5)
                    .rotationEffect(.degrees(45))
                    .offset(x: -2)
            }
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
                Text(L10n.remainingBadge(UsageFormat.percent(remaining)))
                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.black.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(color))
            }
            HStack(spacing: 4) {
                Text("♥")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(color)
                HPBar(remainingFraction: (remaining ?? 0) / 100, color: color)
            }
            HStack(spacing: 3) {
                Image(systemName: "alarm")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                Text(resetText)
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.5))
            }
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
