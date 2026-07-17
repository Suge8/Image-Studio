import Foundation

/// 提交时锚定的通道选择（含全部通道参数，不回读可变设置）。
enum ProviderSelection: Sendable {
    /// modelOverride 非空覆写 Codex 配置模型。
    case codex(modelOverride: String?, options: ImageOptions)
    case relay(config: RelayConfig, draft: RelayDraft)
}

struct GenerationRequest: Sendable {
    let prompt: String
    let referenceURLs: [URL]
    let count: Int
    let provider: ProviderSelection
    let outputDirectory: URL
    let runId: UUID
    let itemIDs: [UUID]
}

enum GenerationEvent: Sendable {
    case started(itemID: UUID, index: Int)
    case succeeded(itemID: UUID, index: Int, url: URL)
    case failed(itemID: UUID, index: Int, message: String)
    case finished
}

actor GenerationEngine {
    private let authClient = AuthClient()
    private var currentTask: Task<Void, Never>?

    func generate(_ request: GenerationRequest) -> AsyncStream<GenerationEvent> {
        currentTask?.cancel()
        let (stream, continuation) = AsyncStream.makeStream(of: GenerationEvent.self)
        let authClient = authClient
        currentTask = Task {
            await Self.run(request: request, authClient: authClient, continuation: continuation)
        }
        return stream
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    private static func run(
        request: GenerationRequest,
        authClient: AuthClient,
        continuation: AsyncStream<GenerationEvent>.Continuation
    ) async {
        defer {
            continuation.yield(.finished)
            continuation.finish()
        }

        do {
            try FileManager.default.createDirectory(
                at: request.outputDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            for (idx, itemID) in request.itemIDs.enumerated() {
                continuation.yield(.failed(itemID: itemID, index: idx + 1, message: error.localizedDescription))
            }
            return
        }

        let format: PreparedImageFormat = if case .relay = request.provider { .png } else { .webp }
        let prepared: [PreparedImage]
        do {
            prepared = try request.referenceURLs.map { try ImagePrep.prepare(url: $0, format: format) }
        } catch {
            for (idx, itemID) in request.itemIDs.enumerated() {
                continuation.yield(.failed(itemID: itemID, index: idx + 1, message: error.localizedDescription))
            }
            return
        }

        let codexModel: String
        if case .codex(let override, _) = request.provider,
           let override = override?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            codexModel = override
        } else {
            codexModel = await authClient.resolveModel()
        }
        let stamp = Date()
        let total = request.count

        await withTaskGroup(of: Void.self) { group in
            for index in 0 ..< total {
                let itemID = request.itemIDs[index]
                group.addTask {
                    if Task.isCancelled {
                        continuation.yield(.failed(itemID: itemID, index: index + 1, message: "Cancelled"))
                        return
                    }
                    continuation.yield(.started(itemID: itemID, index: index + 1))
                    do {
                        let url = try await generateOne(
                            request: request,
                            prepared: prepared,
                            codexModel: codexModel,
                            index: index + 1,
                            total: total,
                            stamp: stamp,
                            authClient: authClient
                        )
                        continuation.yield(.succeeded(itemID: itemID, index: index + 1, url: url))
                    } catch is CancellationError {
                        continuation.yield(.failed(itemID: itemID, index: index + 1, message: "Cancelled"))
                    } catch {
                        continuation.yield(
                            .failed(itemID: itemID, index: index + 1, message: error.localizedDescription)
                        )
                    }
                }
            }
        }
    }

    private static func generateOne(
        request: GenerationRequest,
        prepared: [PreparedImage],
        codexModel: String,
        index: Int,
        total: Int,
        stamp: Date,
        authClient: AuthClient
    ) async throws -> URL {
        switch request.provider {
        case .relay(let config, let relayDraft):
            let payload = RelayImageClient.buildPayload(
                prompt: request.prompt,
                references: prepared,
                model: relayDraft.model,
                aspect: relayDraft.aspect,
                imageSize: relayDraft.imageSize
            )
            let data = try await RelayImageClient.generateOne(config: config, payload: payload)
            return try writePNG(data, request: request, index: index, total: total, stamp: stamp)
        case .codex(_, let options):
            return try await generateCodex(
                request: request, prepared: prepared, model: codexModel, options: options,
                index: index, total: total, stamp: stamp, authClient: authClient
            )
        }
    }

    private static func generateCodex(
        request: GenerationRequest,
        prepared: [PreparedImage],
        model: String,
        options: ImageOptions,
        index: Int,
        total: Int,
        stamp: Date,
        authClient: AuthClient
    ) async throws -> URL {
        var auth = try await authClient.loadReady(timeout: AppConstants.requestTimeout)
        let cacheKey = "image-studio-\(request.runId.uuidString.lowercased())-\(index)"
        let slot = GenerationSlotRequest(
            prompt: request.prompt,
            references: prepared,
            options: options,
            model: model,
            cacheKey: cacheKey
        )
        let payload = CodexImageClient.buildPayload(slot)

        var attempt = 0
        while true {
            if Task.isCancelled { throw CancellationError() }
            do {
                var headers = await authClient.requestHeaders(for: auth)
                let imageData: Data
                do {
                    imageData = try await CodexImageClient.streamImage(headers: headers, payload: payload)
                } catch let http as HTTPStatusError where http.status == 401 {
                    auth = try await authClient.refresh(auth, timeout: AppConstants.requestTimeout)
                    headers = await authClient.requestHeaders(for: auth)
                    imageData = try await CodexImageClient.streamImage(headers: headers, payload: payload)
                }
                return try writePNG(imageData, request: request, index: index, total: total, stamp: stamp)
            } catch let imageError as ResponsesImageError {
                guard let retry = CodexImageClient.retryDelay(for: imageError, attempt: attempt),
                      attempt < AppConstants.maxImageRetries
                else { throw imageError }
                attempt += 1
                try await Task.sleep(for: .seconds(retry.0))
            }
        }
    }

    private static func writePNG(
        _ data: Data,
        request: GenerationRequest,
        index: Int,
        total: Int,
        stamp: Date
    ) throws -> URL {
        let name = OutputNaming.fileName(prompt: request.prompt, index: index, total: total, date: stamp)
        let finalURL = OutputNaming.uniqueURL(in: request.outputDirectory, preferredName: name)
        let tempURL = request.outputDirectory.appendingPathComponent(".\(finalURL.lastPathComponent).tmp")
        try data.write(to: tempURL, options: .atomic)
        if FileManager.default.fileExists(atPath: finalURL.path) {
            try FileManager.default.removeItem(at: finalURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: finalURL)
        return finalURL
    }
}
