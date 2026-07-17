import Foundation

/// 中转出图错误；`retryable=false`（key 无效 / 余额不足 / 任务失败）立即失败不重试。
struct RelayError: Error, LocalizedError, Sendable {
    let message: String
    let retryable: Bool

    var errorDescription: String? { message }
}

enum RelaySubmitResult: Sendable {
    case task(id: String)
    /// 标准 OpenAI 同步中转：提交响应直接带结果，跳过轮询。
    case images([RelayResultImage])
}

enum RelayTaskState: Sendable {
    case pending
    case completed([RelayResultImage])
    case failed(String)
}

struct RelayResultImage: Sendable {
    let url: String?
    let b64: String?
}

/// 第三方中转客户端：POST {base}/v1/images/generations → GET {origin}/v1/tasks/{id} → 下载 CDN 图。
/// 轮询是纪律显式例外：中转无 SSE/webhook，任务查询是唯一接口。
enum RelayImageClient {
    // MARK: - Payload

    static func buildPayload(
        prompt: String,
        references: [PreparedImage],
        model: String,
        aspect: RelayAspect,
        imageSize: RelayImageSize
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "n": 1,
            "async": true,
        ]
        if aspect != .auto { payload["size"] = aspect.rawValue }
        if imageSize != .auto { payload["imageSize"] = imageSize.rawValue }
        if !references.isEmpty { payload["image"] = references.map(\.dataURL) }
        return payload
    }

    // MARK: - 生成一张

    static func generateOne(config: RelayConfig, payload: [String: Any]) async throws -> Data {
        let model = payload["model"] as? String ?? "?"
        AppLog.info("relay submit model=\(model)")
        let submitData = try await send(url: config.submitURL, apiKey: config.apiKey, body: payload)
        switch try parseSubmit(submitData) {
        case .images(let images):
            return try await resolve(images: images)
        case .task(let id):
            AppLog.info("relay task=\(id)")
            let images = try await poll(config: config, taskID: id)
            return try await resolve(images: images)
        }
    }

    private static func poll(config: RelayConfig, taskID: String) async throws -> [RelayResultImage] {
        let deadline = Date.now.addingTimeInterval(AppConstants.requestTimeout)
        try await Task.sleep(for: .seconds(AppConstants.relayPollFirstDelay))
        var consecutiveErrors = 0
        while Date.now < deadline {
            do {
                let data = try await send(url: config.taskURL(id: taskID), apiKey: config.apiKey, body: nil)
                consecutiveErrors = 0
                switch try parseTask(data) {
                case .completed(let images):
                    return images
                case .failed(let message):
                    throw RelayError(message: message, retryable: false)
                case .pending:
                    break
                }
            } catch let error as RelayError where !error.retryable {
                throw error
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // 轮询丢一次包不杀任务；连续多次才判失败
                consecutiveErrors += 1
                AppLog.warn("relay poll error(\(consecutiveErrors)): \(error.localizedDescription)")
                if consecutiveErrors >= AppConstants.relayPollMaxErrors {
                    throw RelayError(
                        message: String(localized: "Task polling failed repeatedly: \(error.localizedDescription)"),
                        retryable: false
                    )
                }
            }
            let jitter = Double.random(in: -0.5 ... 0.5)
            try await Task.sleep(for: .seconds(AppConstants.relayPollInterval + jitter))
        }
        throw RelayError(
            message: String(localized: "Task timed out after \(Int(AppConstants.requestTimeout))s"),
            retryable: false
        )
    }

    private static func resolve(images: [RelayResultImage]) async throws -> Data {
        guard let image = images.first else {
            throw RelayError(message: String(localized: "Task completed but returned no image"), retryable: false)
        }
        if let b64 = image.b64, let data = CodexImageClient.decodeBase64(b64) {
            return data
        }
        guard let urlString = image.url, let url = URL(string: urlString) else {
            throw RelayError(message: String(localized: "Task result has no image URL"), retryable: false)
        }
        return try await download(url: url)
    }

    private static func download(url: URL) async throws -> Data {
        var lastError: Error = RelayError(message: String(localized: "Download failed"), retryable: false)
        for attempt in 0 ... AppConstants.relayDownloadRetries {
            do {
                let request = URLRequest(url: url, timeoutInterval: 60)
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    throw RelayError(message: String(localized: "Image download failed (HTTP \(status))"), retryable: true)
                }
                AppLog.info("relay image \(data.count)B ← \(url.host() ?? "?")")
                return data
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                if attempt < AppConstants.relayDownloadRetries {
                    try await Task.sleep(for: .seconds(2))
                }
            }
        }
        throw RelayError(
            message: String(localized: "Image download failed: \(lastError.localizedDescription)"),
            retryable: false
        )
    }

    // MARK: - 响应解析（纯函数，单测覆盖）

    static func parseSubmit(_ data: Data) throws -> RelaySubmitResult {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RelayError(message: String(localized: "Relay returned an unparsable response"), retryable: false)
        }
        if let images = resultImages(from: obj) {
            return .images(images)
        }
        if let taskID = obj["task_id"] as? String {
            return .task(id: taskID)
        }
        throw RelayError(
            message: serverMessage(obj) ?? String(localized: "Relay submission failed"),
            retryable: false
        )
    }

    static func parseTask(_ data: Data) throws -> RelayTaskState {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RelayError(message: String(localized: "Relay returned an unparsable response"), retryable: false)
        }
        if let images = resultImages(from: obj) {
            return .completed(images)
        }
        if let status = obj["status"] as? String, status == "failed" {
            return .failed(serverMessage(obj) ?? String(localized: "Upstream generation failed"))
        }
        return .pending
    }

    private static func resultImages(from obj: [String: Any]) -> [RelayResultImage]? {
        guard let data = obj["data"] as? [[String: Any]], !data.isEmpty else { return nil }
        return data.map {
            RelayResultImage(url: $0["url"] as? String, b64: $0["b64_json"] as? String)
        }
    }

    private static func serverMessage(_ obj: [String: Any]) -> String? {
        if let error = obj["error"] as? String { return error }
        if let error = obj["error"] as? [String: Any], let message = error["message"] as? String {
            return message
        }
        return obj["message"] as? String
    }

    // MARK: - 模型列表

    static func fetchModels(config: RelayConfig) async throws -> [RelayModel] {
        let data = try await send(url: config.modelsURL, apiKey: config.apiKey, body: nil)
        return try parseModels(data)
    }

    static func parseModels(_ data: Data) throws -> [RelayModel] {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = obj["data"] as? [[String: Any]]
        else {
            throw RelayError(message: String(localized: "Failed to parse model list"), retryable: false)
        }
        return list.compactMap { entry in
            guard let id = entry["id"] as? String else { return nil }
            let price = (entry["price_config"] as? [String: Any])?["request_price"] as? Double
            return RelayModel(id: id, price: price)
        }
    }

    // MARK: - HTTP

    private static func send(url: URL, apiKey: String, body: [String: Any]?) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RelayError(message: String(localized: "Invalid HTTP response"), retryable: true)
        }
        if (200 ... 299).contains(http.statusCode) {
            return data
        }
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let message = obj.flatMap(serverMessage) ?? "HTTP \(http.statusCode)"
        // 401/403（key 无效 / 余额不足）重试无意义
        let fatal = http.statusCode == 401 || http.statusCode == 403
        AppLog.error("relay HTTP \(http.statusCode): \(message)")
        throw RelayError(message: message, retryable: !fatal)
    }
}
