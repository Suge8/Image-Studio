import Foundation

struct GenerationSlotRequest: Sendable {
    let prompt: String
    let references: [PreparedImage]
    let options: ImageOptions
    let model: String
    let cacheKey: String
}

enum CodexImageClient {
    static func buildPayload(_ request: GenerationSlotRequest) -> [String: Any] {
        var content: [[String: Any]] = [
            ["type": "input_text", "text": request.prompt],
        ]
        for image in request.references {
            content.append([
                "type": "input_image",
                "image_url": image.dataURL,
            ])
        }

        let tool: [String: Any] = [
            "type": "image_generation",
            "output_format": "png",
            "size": request.options.size.rawValue,
            "quality": request.options.quality.rawValue,
            "background": request.options.background.rawValue,
        ]

        var instructions =
            "Use the available image generation tool to generate exactly one PNG image for the user request. " +
            "Do not use any other tool."
        if !request.references.isEmpty {
            instructions += " Treat the provided input images as edit/reference images for the request."
        }

        return [
            "model": request.model,
            "instructions": instructions,
            "input": [
                [
                    "type": "message",
                    "role": "user",
                    "content": content,
                ],
            ],
            "tools": [tool],
            "tool_choice": ["type": "image_generation"],
            "parallel_tool_calls": false,
            "reasoning": NSNull(),
            "store": false,
            "stream": true,
            "include": [String](),
            "prompt_cache_key": request.cacheKey,
            "client_metadata": ["x-codex-installation-id": "image-studio"],
        ]
    }

    static func streamImage(
        baseURL: URL = AppConstants.baseURL,
        headers: [String: String],
        payload: [String: Any],
        timeout: TimeInterval = AppConstants.requestTimeout
    ) async throws -> Data {
        let url = baseURL.appendingPathComponent("responses")
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let model = payload["model"] as? String ?? "?"
        let cacheKey = payload["prompt_cache_key"] as? String ?? "?"
        AppLog.info("POST \(url.lastPathComponent) model=\(model) cache=\(cacheKey)")

        // Full-body fetch is more reliable than AsyncBytes.lines for multi‑MB SSE frames.
        // Image gen already waits for a result; ~1–3MB body is fine.
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StudioError.message("Invalid HTTP response.")
        }
        AppLog.info("HTTP \(http.statusCode) body=\(data.count)B")

        if !(200 ... 299).contains(http.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? ""
            AppLog.error("HTTP \(http.statusCode): \(text.prefix(300))")
            throw HTTPStatusError(status: http.statusCode, body: text)
        }

        let text = String(data: data, encoding: .utf8) ?? ""
        do {
            let image = try extractImageFromSSE(text)
            AppLog.info("image decoded \(image.count)B")
            return image
        } catch {
            AppLog.error("SSE extract failed: \(error.localizedDescription)")
            // Helpful summary without dumping megabytes of base64
            AppLog.debug(sseSummary(text))
            throw error
        }
    }

    /// Parse complete SSE body; return first decodable image (partial or final).
    static func extractImageFromSSE(_ text: String) throws -> Data {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        var lastStatus: String?
        var lastErrorEvent: [String: Any]?
        var eventTypes: [String] = []
        var parseFailures = 0

        for block in normalized.components(separatedBy: "\n\n") {
            guard let event = parseSSEBlock(block) else {
                if !block.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    parseFailures += 1
                }
                continue
            }
            if let type = event["type"] as? String {
                eventTypes.append(type)
            }
            if let image = extractImageResult(
                from: event,
                lastStatus: &lastStatus,
                lastError: &lastErrorEvent,
                acceptPartial: true
            ) {
                AppLog.debug("hit image via \(event["type"] as? String ?? "?") events=\(eventTypes.count)")
                return image
            }
        }

        AppLog.warn(
            "no image in SSE; events=\(eventTypes.joined(separator: ",")) parseFailures=\(parseFailures) lastStatus=\(lastStatus ?? "nil")"
        )

        if let lastErrorEvent {
            throw ResponsesImageError(event: lastErrorEvent)
        }
        if let lastStatus {
            throw StudioError.message("Responses stream ended without an image result; last status was \(lastStatus).")
        }
        throw StudioError.message("Responses stream ended without an image generation result.")
    }

    static func parseSSEBlock(_ block: String) -> [String: Any]? {
        var dataLines: [String] = []
        for raw in block.split(whereSeparator: \.isNewline).map(String.init) {
            let line = raw.hasSuffix("\r") ? String(raw.dropLast()) : raw
            if line.hasPrefix("data:") {
                let value = line.dropFirst(5)
                if value.first == " " {
                    dataLines.append(String(value.dropFirst()))
                } else {
                    dataLines.append(String(value))
                }
            }
        }
        guard !dataLines.isEmpty else { return nil }
        return parseSSEData(dataLines.joined(separator: "\n"))
    }

    static func parseSSEData(_ block: String) -> [String: Any]? {
        let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj
    }

    static func extractImageResult(
        from event: [String: Any],
        lastStatus: inout String?,
        lastError: inout [String: Any]?,
        acceptPartial: Bool = true
    ) -> Data? {
        if let type = event["type"] as? String,
           type == "response.failed" || type == "response.incomplete" {
            lastError = event
        }

        if acceptPartial,
           let type = event["type"] as? String,
           type == "response.image_generation_call.partial_image" {
            if let b64 = event["partial_image_b64"] as? String {
                if let data = decodeBase64(b64) { return data }
                AppLog.warn("partial_image_b64 present but base64 decode failed len=\(b64.count)")
            }
        }

        if let item = event["item"] as? [String: Any],
           let type = item["type"] as? String,
           type == "image_generation_call" {
            if let status = item["status"] as? String {
                lastStatus = status
            }
            if let result = item["result"] as? String {
                if let data = decodeBase64(result) { return data }
                if !result.isEmpty {
                    AppLog.warn("item.result present but base64 decode failed len=\(result.count)")
                }
            }
        }

        if let response = event["response"] as? [String: Any],
           let output = response["output"] as? [[String: Any]] {
            for item in output where (item["type"] as? String) == "image_generation_call" {
                if let status = item["status"] as? String {
                    lastStatus = status
                }
                if let result = item["result"] as? String, let data = decodeBase64(result) {
                    return data
                }
            }
        }

        return nil
    }

    static func decodeBase64(_ string: String) -> Data? {
        var s = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        s = s.replacingOccurrences(of: "\n", with: "")
        s = s.replacingOccurrences(of: "\r", with: "")
        // URL-safe → standard
        if s.contains("-") || s.contains("_") {
            s = s.replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
        }
        let pad = (4 - s.count % 4) % 4
        if pad > 0 { s += String(repeating: "=", count: pad) }
        if let data = Data(base64Encoded: s, options: [.ignoreUnknownCharacters]) {
            return data
        }
        return nil
    }

    private static func sseSummary(_ text: String) -> String {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        var types: [String] = []
        for block in normalized.components(separatedBy: "\n\n") {
            if let event = parseSSEBlock(block), let type = event["type"] as? String {
                types.append(type)
            }
        }
        return "sse events(\(types.count)): \(types.joined(separator: " → "))"
    }

    static func retryDelay(for error: ResponsesImageError, attempt: Int) -> (TimeInterval, String)? {
        // 上游过载与限流同属瞬态故障，都自动退避重试
        if error.code == "server_is_overloaded" {
            return (min(pow(2.0, Double(attempt)) * 5.0, 60.0), "server overloaded")
        }
        guard error.code == "rate_limit_exceeded" else { return nil }
        let message = error.message ?? ""
        if message.contains("input-images per min"), rateLimitBucketExhausted(message) {
            let idx = min(attempt, AppConstants.inputImageRateLimitDelays.count - 1)
            return (AppConstants.inputImageRateLimitDelays[idx], "input-image quota full")
        }
        var parsed: TimeInterval?
        if let match = message.range(
            of: #"try again in\s+(\d+(?:\.\d+)?)\s*(ms|s)"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            let snippet = String(message[match])
            let parts = snippet.split(separator: " ")
            if parts.count >= 4, let value = Double(parts[3]) {
                let unit = parts[4].lowercased()
                parsed = unit.hasPrefix("ms") ? value / 1000.0 : value
            }
        }
        let backoff = min(pow(2.0, Double(attempt)), 16.0)
        if let parsed {
            return (max(parsed, backoff), "image generation rate-limited")
        }
        return (backoff, "image generation rate-limited")
    }

    private static func rateLimitBucketExhausted(_ message: String) -> Bool {
        func capture(_ pattern: String) -> Double? {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: message)
            else { return nil }
            return Double(message[range])
        }
        guard let used = capture(#"Used\s+(\d+(?:\.\d+)?)"#),
              let limit = capture(#"Limit\s+(\d+(?:\.\d+)?)"#)
        else { return false }
        return used >= limit
    }
}

struct HTTPStatusError: Error, LocalizedError, Sendable {
    let status: Int
    let body: String

    var errorDescription: String? {
        if let detail = Self.extractDetail(from: body) {
            return "HTTP \(status): \(detail)"
        }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "HTTP \(status)"
        }
        return "HTTP \(status): \(trimmed.prefix(400))"
    }

    private static func extractDetail(from body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        if let detail = obj["detail"] as? String { return detail }
        if let message = obj["message"] as? String { return message }
        if let error = obj["error"] as? [String: Any], let message = error["message"] as? String {
            return message
        }
        return nil
    }
}

struct ResponsesImageError: Error, LocalizedError, @unchecked Sendable {
    let event: [String: Any]
    let code: String?
    let message: String?

    init(event: [String: Any]) {
        self.event = event
        let response = event["response"] as? [String: Any]
        let errorObj = response?["error"] as? [String: Any]
        self.code = errorObj?["code"] as? String
        self.message = errorObj?["message"] as? String
    }

    var errorDescription: String? {
        switch code {
        case "server_is_overloaded":
            return String(localized: "Upstream servers are overloaded. Please try again later.")
        case "rate_limit_exceeded":
            return String(localized: "Rate limited by upstream; retries exhausted. Please try again later.")
        default:
            if let code, let message {
                return "\(String(localized: "Image generation failed")) (\(code)): \(message)"
            }
            if let message {
                return "\(String(localized: "Image generation failed")): \(message)"
            }
            return String(localized: "Image generation failed.")
        }
    }
}
