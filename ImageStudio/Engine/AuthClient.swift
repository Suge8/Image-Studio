import Foundation
import os

struct CodexAuth: @unchecked Sendable {
    var raw: [String: Any]
    var accessToken: String
    var refreshToken: String?
    var accountID: String?
    var isFedRAMP: Bool
    var fileURL: URL
}

actor AuthClient {
    private let fileManager = FileManager.default

    func codexHome() -> URL {
        if let override = ProcessInfo.processInfo.environment["CODEX_HOME"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
    }

    func authFileURL() -> URL {
        codexHome().appendingPathComponent("auth.json")
    }

    func status() async -> AuthState {
        do {
            _ = try await loadReady()
            return .ready
        } catch {
            if let studio = error as? StudioError, case .message(let text) = studio,
               text.localizedCaseInsensitiveContains("not found") || text.localizedCaseInsensitiveContains("login") {
                return .missing
            }
            return .failed(error.localizedDescription)
        }
    }

    func loadReady(timeout: TimeInterval = 30) async throws -> CodexAuth {
        let file = authFileURL()
        var auth = try load(from: file)
        if tokenIsExpiring(auth.accessToken) {
            auth = try await refresh(auth, timeout: timeout)
        }
        return auth
    }

    func refresh(_ auth: CodexAuth, timeout: TimeInterval = 30) async throws -> CodexAuth {
        guard let refreshToken = auth.refreshToken, !refreshToken.isEmpty else {
            throw StudioError.message("Codex refresh token not found. Run `codex login` again.")
        }
        var request = URLRequest(url: AppConstants.refreshURL, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "client_id": AppConstants.codexClientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StudioError.message("Token refresh failed: invalid response.")
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw StudioError.message("Token refresh failed (HTTP \(http.statusCode)): \(text.prefix(400))")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StudioError.message("Token refresh returned invalid JSON.")
        }

        var raw = auth.raw
        var tokens = (raw["tokens"] as? [String: Any]) ?? [:]
        if let access = json["access_token"] as? String { tokens["access_token"] = access }
        if let refresh = json["refresh_token"] as? String { tokens["refresh_token"] = refresh }
        if let idToken = json["id_token"] as? String {
            tokens["id_token"] = idTokenClaims(from: idToken)
        }
        raw["tokens"] = tokens
        raw["last_refresh"] = ISO8601DateFormatter().string(from: Date())

        let encoded = try JSONSerialization.data(withJSONObject: raw, options: [.prettyPrinted, .sortedKeys])
        try encoded.write(to: auth.fileURL, options: .atomic)
        return try parse(raw: raw, fileURL: auth.fileURL)
    }

    func requestHeaders(for auth: CodexAuth) -> [String: String] {
        var headers: [String: String] = [
            "Authorization": "Bearer \(auth.accessToken)",
            "Accept": "application/json",
            "Content-Type": "application/json",
            "originator": AppConstants.originator,
            "User-Agent": userAgent(),
            "version": codexVersion(),
        ]
        if let accountID = auth.accountID {
            headers["ChatGPT-Account-ID"] = accountID
        }
        if auth.isFedRAMP {
            headers["X-OpenAI-Fedramp"] = "true"
        }
        return headers
    }

    func resolveModel() -> String {
        if let env = ProcessInfo.processInfo.environment["IMAGE_STUDIO_MODEL"], !env.isEmpty {
            return env
        }
        let config = codexHome().appendingPathComponent("config.toml")
        if let text = try? String(contentsOf: config, encoding: .utf8),
           let model = Self.firstTOMLString(key: "model", in: text) {
            return model
        }
        return AppConstants.defaultModel
    }

    /// Parse top-level `key = "value"` from Codex config.toml (multiline-safe).
    nonisolated static func firstTOMLString(key: String, in text: String) -> String? {
        let pattern = "^\(NSRegularExpression.escapedPattern(for: key))\\s*=\\s*[\"']([^\"']+)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }

    private func load(from file: URL) throws -> CodexAuth {
        guard fileManager.fileExists(atPath: file.path) else {
            throw StudioError.message("Codex auth file not found. Run `codex login` and choose ChatGPT.")
        }
        let data = try Data(contentsOf: file)
        guard let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StudioError.message("Codex auth file must contain a JSON object.")
        }
        return try parse(raw: raw, fileURL: file)
    }

    private func parse(raw: [String: Any], fileURL: URL) throws -> CodexAuth {
        guard let tokens = raw["tokens"] as? [String: Any] else {
            throw StudioError.message("Codex ChatGPT auth not found. Run `codex login` and choose ChatGPT.")
        }
        guard let access = tokens["access_token"] as? String, !access.isEmpty else {
            throw StudioError.message("Codex ChatGPT access token not found. Run `codex login` and choose ChatGPT.")
        }
        let refresh = tokens["refresh_token"] as? String
        var accountID = tokens["account_id"] as? String
        var isFedRAMP = false
        if let idToken = tokens["id_token"] {
            let claims: [String: Any]
            if let dict = idToken as? [String: Any] {
                claims = dict
            } else if let jwt = idToken as? String {
                claims = idTokenClaims(from: jwt)
            } else {
                claims = [:]
            }
            if accountID == nil {
                accountID = claims["chatgpt_account_id"] as? String
            }
            isFedRAMP = (claims["chatgpt_account_is_fedramp"] as? Bool) ?? false
        }
        return CodexAuth(
            raw: raw,
            accessToken: access,
            refreshToken: refresh,
            accountID: accountID,
            isFedRAMP: isFedRAMP,
            fileURL: fileURL
        )
    }

    private func tokenIsExpiring(_ token: String, leeway: TimeInterval = 60) -> Bool {
        guard let payload = jwtPayload(token),
              let exp = payload["exp"] as? TimeInterval
        else { return false }
        return exp <= Date().timeIntervalSince1970 + leeway
    }

    private func jwtPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: pad)
        guard let data = Data(base64Encoded: base64),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj
    }

    private func idTokenClaims(from jwt: String) -> [String: Any] {
        guard let payload = jwtPayload(jwt) else { return ["raw_jwt": jwt] }
        let auth = payload["https://api.openai.com/auth"] as? [String: Any] ?? [:]
        let profileEmail = payload["https://api.openai.com/profile.email"]
        let email = payload["email"] ?? profileEmail
        var claims: [String: Any] = [
            "chatgpt_account_is_fedramp": (auth["chatgpt_account_is_fedramp"] as? Bool) ?? false,
            "raw_jwt": jwt,
        ]
        if let email { claims["email"] = email }
        if let plan = auth["chatgpt_plan_type"] { claims["chatgpt_plan_type"] = plan }
        if let user = auth["chatgpt_user_id"] ?? auth["user_id"] { claims["chatgpt_user_id"] = user }
        if let account = auth["chatgpt_account_id"] { claims["chatgpt_account_id"] = account }
        return claims
    }

    private func userAgent() -> String {
        let version = codexVersion()
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let system = "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        let machine = {
            var sysinfo = utsname()
            uname(&sysinfo)
            return withUnsafePointer(to: &sysinfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
            }
        }()
        return "\(AppConstants.originator)/\(version) (macOS \(system); \(machine)) image-studio/\(AppConstants.appVersion)"
    }

    /// Backend gates models by the Codex client version header. Must report real CLI version.
    private func codexVersion() -> String {
        if let override = ProcessInfo.processInfo.environment["IMAGE_STUDIO_CODEX_VERSION"], !override.isEmpty {
            return override
        }
        if let cached = Self.codexVersionCache.withLock({ $0 }) {
            return cached
        }
        let resolved = Self.detectCodexCLIVersion() ?? AppConstants.appVersion
        Self.codexVersionCache.withLock { $0 = resolved }
        return resolved
    }

    private static let codexVersionCache = OSAllocatedUnfairLock<String?>(initialState: nil)

    nonisolated static func detectCodexCLIVersion() -> String? {
        let candidates = codexExecutableCandidates()
        for executable in candidates {
            if let version = runCodexVersion(executable: executable) {
                return version
            }
        }
        return nil
    }

    nonisolated private static func codexExecutableCandidates() -> [String] {
        var list: [String] = [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
        ]
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for dir in path.split(separator: ":") {
                list.append("\(dir)/codex")
            }
        }
        // de-dupe, keep order
        var seen = Set<String>()
        return list.filter { seen.insert($0).inserted && FileManager.default.isExecutableFile(atPath: $0) }
    }

    nonisolated private static func runCodexVersion(executable: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["--version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        guard let regex = try? NSRegularExpression(pattern: #"(\d+\.\d+\.\d+)"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }
}
