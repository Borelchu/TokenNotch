import Foundation
import Security
import SwiftUI

// MARK: - API response

struct UsageWindow: Decodable {
    let utilization: Double?
    let resetsAt: Date?

    var remainingPercent: Double? {
        utilization.map { max(0, 100 - $0) }
    }
}

struct UsageResponse: Decodable {
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?
    let sevenDaySonnet: UsageWindow?
    let sevenDayOpus: UsageWindow?
}

// MARK: - Errors

enum UsageError: LocalizedError {
    case keychainNotFound
    case keychainDenied(OSStatus)
    case credentialsMalformed
    case tokenExpired
    case http(Int)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .keychainNotFound:
            return "키체인에서 Claude Code 자격 증명을 찾을 수 없습니다. Claude Code에 로그인돼 있는지 확인하세요."
        case let .keychainDenied(status):
            return "키체인 접근이 거부되었습니다 (\(status)). 접근 요청 시 '항상 허용'을 눌러주세요."
        case .credentialsMalformed:
            return "키체인의 자격 증명 형식을 해석할 수 없습니다."
        case .tokenExpired:
            return "토큰이 만료되었습니다. Claude Code를 한 번 실행하면 갱신됩니다."
        case let .http(code):
            return code == 401
                ? "인증 실패(401). Claude Code를 한 번 실행해 토큰을 갱신하세요."
                : "API 오류 (HTTP \(code))"
        case let .network(message):
            return "네트워크 오류: \(message)"
        }
    }
}

// MARK: - Keychain

enum ClaudeCredentials {
    /// Reads the OAuth access token that Claude Code stores in the login keychain.
    ///
    /// Goes through the security CLI first: reading with SecItemCopyMatching from an
    /// ad-hoc-signed binary pops a blocking keychain ACL dialog on every rebuild
    /// (the binary's identity changes), while /usr/bin/security is already trusted.
    static func accessToken() throws -> String {
        let data: Data
        if let cliData = readViaSecurityCLI() {
            data = cliData
        } else {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "Claude Code-credentials",
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            switch status {
            case errSecSuccess where item is Data:
                data = item as! Data
            case errSecItemNotFound:
                throw UsageError.keychainNotFound
            default:
                throw UsageError.keychainDenied(status)
            }
        }
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let oauth = root["claudeAiOauth"] as? [String: Any],
            let token = oauth["accessToken"] as? String
        else {
            throw UsageError.credentialsMalformed
        }
        if let expiresAt = oauth["expiresAt"] as? Double,
           Date(timeIntervalSince1970: expiresAt / 1000) < Date() {
            throw UsageError.tokenExpired
        }
        return token
    }

    private static func readViaSecurityCLI() -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, !data.isEmpty else { return nil }
        return data
    }
}

// MARK: - API client

enum UsageAPI {
    private static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    /// Runs off the main actor: the keychain read shells out to /usr/bin/security,
    /// which must not block the UI.
    static func fetchUsage() async throws -> UsageResponse {
        let token = try ClaudeCredentials.accessToken()
        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("NotchUsage/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw UsageError.http(http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            if let date = isoFractional.date(from: string) ?? iso.date(from: string) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Unparseable date: \(string)"
            ))
        }
        return try decoder.decode(UsageResponse.self, from: data)
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
}

// MARK: - Model

@MainActor
final class UsageModel: ObservableObject {
    @Published var fiveHour: UsageWindow?
    @Published var sevenDay: UsageWindow?
    @Published var sevenDaySonnet: UsageWindow?
    @Published var sevenDayOpus: UsageWindow?
    @Published var lastUpdated: Date?
    @Published var errorMessage: String?

    func refresh() async {
        do {
            let usage = try await UsageAPI.fetchUsage()

            fiveHour = usage.fiveHour
            sevenDay = usage.sevenDay
            sevenDaySonnet = usage.sevenDaySonnet
            sevenDayOpus = usage.sevenDayOpus
            lastUpdated = Date()
            errorMessage = nil
            NSLog("NotchUsage: 5h %@%% used, 7d %@%% used",
                  usage.fiveHour?.utilization.map { String($0) } ?? "?",
                  usage.sevenDay?.utilization.map { String($0) } ?? "?")
        } catch let error as UsageError {
            errorMessage = error.errorDescription
            NSLog("NotchUsage error: %@", error.errorDescription ?? "\(error)")
        } catch let error as DecodingError {
            errorMessage = "응답 해석 실패: \(error)"
            NSLog("NotchUsage decode error: %@", "\(error)")
        } catch {
            errorMessage = UsageError.network(error.localizedDescription).errorDescription
            NSLog("NotchUsage network error: %@", error.localizedDescription)
        }
    }
}
