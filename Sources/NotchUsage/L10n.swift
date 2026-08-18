import Foundation

/// Minimal two-language string table. The app is a bare SPM executable, so
/// instead of bundle-based localization we pick a language once at launch
/// from the system preference (NOTCH_LANG=ko|en overrides, for testing).
enum L10n {
    static let isKorean: Bool = {
        if let forced = ProcessInfo.processInfo.environment["NOTCH_LANG"] {
            return forced.hasPrefix("ko")
        }
        return Locale.preferredLanguages.first?.hasPrefix("ko") ?? false
    }()

    // MARK: Usage rows

    static var fiveHourSession: String { isKorean ? "5시간 세션" : "5-hour session" }
    static var weeklyAll: String { isKorean ? "주간 (전체)" : "Weekly (all)" }
    static var weeklyOpus: String { isKorean ? "주간 (Opus)" : "Weekly (Opus)" }
    static var weeklySonnet: String { isKorean ? "주간 (Sonnet)" : "Weekly (Sonnet)" }
    static var weekly: String { isKorean ? "주간" : "Weekly" }

    static func remainingBadge(_ percent: String) -> String {
        isKorean ? "남음 \(percent)" : "\(percent) left"
    }

    static func resets(at time: String) -> String {
        isKorean ? "\(time) 리셋" : "resets \(time)"
    }

    // MARK: Countdown

    static var resetSoon: String { isKorean ? "곧 리셋" : "resetting soon" }

    static func inDaysHours(_ days: Int, _ hours: Int) -> String {
        isKorean ? "\(days)일 \(hours)시간 후" : "in \(days)d \(hours)h"
    }

    static func inHoursMinutes(_ hours: Int, _ minutes: Int) -> String {
        isKorean ? "\(hours)시간 \(minutes)분 후" : "in \(hours)h \(minutes)m"
    }

    static func inMinutes(_ minutes: Int) -> String {
        isKorean ? "\(minutes)분 후" : "in \(minutes)m"
    }

    // MARK: Speech bubbles

    static func phrase(for mood: Mood) -> String {
        switch mood {
        case .happy: return isKorean ? "아직 든든해요!" : "Plenty left!"
        case .worried: return isKorean ? "아껴 써야 해요…" : "Getting low…"
        case .critical: return isKorean ? "거의 다 썼어요!!" : "Almost out!!"
        case .sleeping: return isKorean ? "쉬는 중… zzz" : "Napping… zzz"
        }
    }

    // MARK: Stats page

    static var statsTokensUsed: String { isKorean ? "사용한 토큰" : "tokens used" }
    static var statsToday: String { isKorean ? "오늘" : "Today" }
    static var statsThisWeek: String { isKorean ? "이번 주" : "This week" }
    static var statsIn: String { isKorean ? "입력" : "in" }
    static var statsOut: String { isKorean ? "출력" : "out" }
    static var statsEmpty: String { isKorean ? "로컬 기록이 없어요" : "No local logs yet" }

    // MARK: Controls

    static var quitHelp: String { isKorean ? "NotchUsage 종료" : "Quit NotchUsage" }
    static var chipHideHelp: String { isKorean ? "노치에서 숨기기" : "Hide from the notch" }
    static var chipShowHelp: String { isKorean ? "노치에 표시" : "Show in the notch" }

    // MARK: Dates

    static var dayTimeFormat: String { isKorean ? "M/d(E) HH:mm" : "E M/d HH:mm" }
    static var dayTimeLocale: Locale { Locale(identifier: isKorean ? "ko_KR" : "en_US") }

    // MARK: Errors

    static var errKeychainNotFound: String {
        isKorean
            ? "키체인에서 Claude Code 자격 증명을 찾을 수 없습니다. Claude Code에 로그인돼 있는지 확인하세요."
            : "Couldn't find Claude Code credentials in the keychain. Make sure you're logged in to Claude Code."
    }

    static func errKeychainDenied(_ status: Int32) -> String {
        isKorean
            ? "키체인 접근이 거부되었습니다 (\(status)). 접근 요청 시 '항상 허용'을 눌러주세요."
            : "Keychain access was denied (\(status)). Choose “Always Allow” when prompted."
    }

    static var errCredentialsMalformed: String {
        isKorean
            ? "키체인의 자격 증명 형식을 해석할 수 없습니다."
            : "Couldn't parse the keychain credentials."
    }

    static var errTokenExpired: String {
        isKorean
            ? "토큰이 만료되었습니다. Claude Code를 한 번 실행하면 갱신됩니다."
            : "Token expired. Run Claude Code once to refresh it."
    }

    static var errAuthFailed: String {
        isKorean
            ? "인증 실패(401). Claude Code를 한 번 실행해 토큰을 갱신하세요."
            : "Authentication failed (401). Run Claude Code once to refresh the token."
    }

    static func errHTTP(_ code: Int) -> String {
        isKorean ? "API 오류 (HTTP \(code))" : "API error (HTTP \(code))"
    }

    static func errNetwork(_ message: String) -> String {
        isKorean ? "네트워크 오류: \(message)" : "Network error: \(message)"
    }

    static var errCodexAuthNotFound: String {
        isKorean
            ? "~/.codex/auth.json이 없습니다. Codex CLI에 로그인돼 있는지 확인하세요."
            : "~/.codex/auth.json not found. Make sure you're logged in to Codex CLI."
    }

    static var errCodexAuthMalformed: String {
        isKorean
            ? "Codex 자격 증명 형식을 해석할 수 없습니다."
            : "Couldn't parse the Codex credentials."
    }

    static var errCodexTokenExpired: String {
        isKorean
            ? "Codex 토큰이 만료되었습니다. codex를 한 번 실행하면 갱신됩니다."
            : "Codex token expired. Run codex once to refresh it."
    }

    static func errDecode(_ detail: String) -> String {
        isKorean ? "응답 해석 실패: \(detail)" : "Failed to parse the response: \(detail)"
    }
}
