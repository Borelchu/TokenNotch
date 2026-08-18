import Foundation

/// Token totals for one local-time day.
struct DayTokens {
    var input = 0       // non-cache input
    var output = 0
    var cacheRead = 0
    var cacheWrite = 0

    var total: Int { input + output + cacheRead + cacheWrite }

    mutating func add(_ other: DayTokens) {
        input += other.input
        output += other.output
        cacheRead += other.cacheRead
        cacheWrite += other.cacheWrite
    }
}

/// Aggregates tokens actually consumed, straight from the CLIs' local logs:
/// Claude Code transcripts (`~/.claude/projects/**.jsonl`, per-message usage)
/// and Codex session rollouts (`~/.codex/sessions/**`, token_count events).
/// The usage APIs only expose window percentages, so the local logs are the
/// only source of absolute counts. Parsed files are cached by (mtime, size),
/// so the 5-minute refresh only re-reads files that changed.
enum LocalStats {
    struct Result {
        var claude: [String: DayTokens] = [:]
        var codex: [String: DayTokens] = [:]
    }

    // Parsed per-message entries are cached, not per-file aggregates: resumed
    // sessions copy earlier history into new files, so deduplication has to
    // happen globally on every collect() pass.
    private struct ClaudeFileCache {
        var mtime: Date
        var size: Int
        var entries: [(key: String, day: String, tokens: DayTokens)]
    }

    private struct CodexFileCache {
        var mtime: Date
        var size: Int
        var day: String
        var tokens: DayTokens
    }

    private static var claudeCache: [String: ClaudeFileCache] = [:]
    private static var codexCache: [String: CodexFileCache] = [:]

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func dayKey(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func collect() -> Result {
        var result = Result()
        collectClaude(into: &result.claude)
        collectCodex(into: &result.codex)
        return result
    }

    // MARK: - Claude Code transcripts

    private static func collectClaude(into byDay: inout [String: DayTokens]) {
        let root = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"]
            .map(URL.init(fileURLWithPath:))
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
        let projects = root.appendingPathComponent("projects")

        var liveFiles = Set<String>()
        for url in jsonlFiles(under: projects) {
            guard let (mtime, size) = stat(url) else { continue }
            let path = url.path
            liveFiles.insert(path)
            if let cached = claudeCache[path], cached.mtime == mtime, cached.size == size {
                continue
            }
            claudeCache[path] = ClaudeFileCache(
                mtime: mtime, size: size, entries: parseClaudeFile(url))
        }
        claudeCache = claudeCache.filter { liveFiles.contains($0.key) }

        var seen = Set<String>()
        for cache in claudeCache.values {
            for entry in cache.entries {
                guard seen.insert(entry.key).inserted else { continue }
                byDay[entry.day, default: DayTokens()].add(entry.tokens)
            }
        }
    }

    private static func parseClaudeFile(_ url: URL) -> [(key: String, day: String, tokens: DayTokens)] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var entries: [(String, String, DayTokens)] = []
        for line in text.split(separator: "\n") {
            guard line.contains("\"type\":\"assistant\"") else { continue }
            guard
                let data = line.data(using: .utf8),
                let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                obj["type"] as? String == "assistant",
                let message = obj["message"] as? [String: Any],
                let usage = message["usage"] as? [String: Any],
                let day = localDay(fromISO: obj["timestamp"] as? String)
            else { continue }

            var tokens = DayTokens()
            tokens.input = intValue(usage["input_tokens"])
            tokens.output = intValue(usage["output_tokens"])
            tokens.cacheRead = intValue(usage["cache_read_input_tokens"])
            tokens.cacheWrite = intValue(usage["cache_creation_input_tokens"])
            guard tokens.total > 0 else { continue }

            // Same message can appear in multiple files (continued sessions);
            // message id + request id identifies one real API response.
            let key: String
            if let id = message["id"] as? String {
                key = "\(id):\(obj["requestId"] as? String ?? "")"
            } else {
                key = UUID().uuidString
            }
            entries.append((key, day, tokens))
        }
        return entries
    }

    // MARK: - Codex session rollouts

    private static func collectCodex(into byDay: inout [String: DayTokens]) {
        let home = ProcessInfo.processInfo.environment["CODEX_HOME"]
            .map(URL.init(fileURLWithPath:))
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        let sessions = home.appendingPathComponent("sessions")

        var liveFiles = Set<String>()
        for url in jsonlFiles(under: sessions) {
            guard let (mtime, size) = stat(url) else { continue }
            let path = url.path
            liveFiles.insert(path)
            if let cached = codexCache[path], cached.mtime == mtime, cached.size == size {
                continue
            }
            // sessions/yyyy/MM/dd/rollout-*.jsonl — the path date is local time.
            let parts = url.pathComponents
            guard parts.count >= 4 else { continue }
            let day = "\(parts[parts.count - 4])-\(parts[parts.count - 3])-\(parts[parts.count - 2])"
            guard day.count == 10, day.allSatisfy({ $0.isNumber || $0 == "-" }) else { continue }
            codexCache[path] = CodexFileCache(
                mtime: mtime, size: size, day: day, tokens: parseCodexFile(url))
        }
        codexCache = codexCache.filter { liveFiles.contains($0.key) }

        for cache in codexCache.values where cache.tokens.total > 0 {
            byDay[cache.day, default: DayTokens()].add(cache.tokens)
        }
    }

    /// The last token_count event carries the session-cumulative totals.
    private static func parseCodexFile(_ url: URL) -> DayTokens {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return DayTokens() }
        var lastUsage: [String: Any]?
        for line in text.split(separator: "\n") {
            guard line.contains("\"token_count\"") else { continue }
            guard
                let data = line.data(using: .utf8),
                let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let payload = obj["payload"] as? [String: Any],
                payload["type"] as? String == "token_count"
            else { continue }
            let info = payload["info"] as? [String: Any]
            if let usage = (info?["total_token_usage"] ?? payload["total_token_usage"]) as? [String: Any] {
                lastUsage = usage
            }
        }
        guard let usage = lastUsage else { return DayTokens() }
        var tokens = DayTokens()
        let cached = intValue(usage["cached_input_tokens"])
        tokens.input = max(0, intValue(usage["input_tokens"]) - cached) // input includes cache
        tokens.cacheRead = cached
        tokens.cacheWrite = intValue(usage["cache_write_input_tokens"])
        tokens.output = intValue(usage["output_tokens"])
        return tokens
    }

    // MARK: - Helpers

    private static func jsonlFiles(under root: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "jsonl" else { return nil }
            return url
        }
    }

    private static func stat(_ url: URL) -> (Date, Int)? {
        guard
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
            let mtime = values.contentModificationDate,
            let size = values.fileSize
        else { return nil }
        return (mtime, size)
    }

    private static func intValue(_ any: Any?) -> Int {
        (any as? NSNumber)?.intValue ?? 0
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// UTC timestamp string → local-time day key (a 16:00Z message lands on
    /// the next day in KST, so date math has to go through a real Date).
    private static func localDay(fromISO string: String?) -> String? {
        guard let string else { return nil }
        guard let date = isoFractional.date(from: string) ?? iso.date(from: string) else {
            return nil
        }
        return dayKey(date)
    }
}
