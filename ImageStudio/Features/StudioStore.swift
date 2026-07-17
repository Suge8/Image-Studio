import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class StudioStore {
    var draft: Draft
    var auth: AuthState = .unknown
    var run: RunState = .idle
    var items: [GalleryItem] = []
    var toast: String?
    var showSettings = false
    var showLogs = false

    /// 中转 API Key（Keychain 单一事实源，此处为内存镜像）。
    var relayKey: String {
        didSet { KeychainStore.saveRelayKey(relayKey) }
    }

    var relayBaseURL: URL {
        didSet { Preferences.relayBaseURL = relayBaseURL }
    }

    var relayModels: [RelayModel] {
        didSet { Preferences.relayModels = relayModels }
    }

    /// Codex 通道解析出的宿主模型名（override 或 config 默认）。
    var resolvedCodexModel: String = "…"

    private let authClient = AuthClient()
    private let engine = GenerationEngine()
    private let library = LibraryStore()
    private let thumbnails = ThumbnailCache()

    private var libraryTask: Task<Void, Never>?
    /// 多批次并发：每个进行中批次一个消费 Task。
    private var runTasks: [UUID: Task<Void, Never>] = [:]
    private var toastTask: Task<Void, Never>?
    /// 会话期内每个批次的请求快照，供失败槽位单格重试。
    private var runRequests: [UUID: GenerationRequest] = [:]

    var promptHistory: [String] {
        didSet { Preferences.promptHistory = promptHistory }
    }

    var favorites: [FavoritePrompt] {
        didSet { Preferences.favoritePrompts = favorites }
    }

    var sortedFavorites: [FavoritePrompt] {
        FavoritePrompt.sorted(favorites)
    }

    init() {
        draft = Preferences.loadDraft()
        relayKey = KeychainStore.loadRelayKey()
        relayBaseURL = Preferences.relayBaseURL
        relayModels = Preferences.relayModels
        promptHistory = Preferences.promptHistory
        favorites = Preferences.favoritePrompts
    }

    // MARK: - 派生状态

    var relayConfigured: Bool {
        !relayKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var providerLabel: String {
        switch draft.provider {
        case .codex: "Codex · \(resolvedCodexModel)"
        case .relay: "中转 · \(draft.relay.model)"
        }
    }

    /// 生成不可用的原因；nil = 可以生成。
    var blockedReason: String? {
        switch draft.provider {
        case .codex:
            if case .missing = auth { return String(localized: "Codex login not detected") }
            if case .failed(let message) = auth { return message }
            return nil
        case .relay:
            return relayConfigured ? nil : String(localized: "Relay API key not configured")
        }
    }

    var relayModelOptions: [RelayModel] {
        relayModels.isEmpty
            ? AppConstants.relayPresetModels.map { RelayModel(id: $0, price: nil) }
            : relayModels
    }

    var estimatedCost: String? {
        guard draft.provider == .relay,
              let price = relayModelOptions.first(where: { $0.id == draft.relay.model })?.price
        else { return nil }
        return String(format: "≈ $%.2f", price * Double(draft.count))
    }

    // MARK: - 生命周期

    func bootstrap() {
        AppLog.bootstrap()
        ensureOutputDirectory()
        Task {
            await refreshAuth()
            await refreshResolvedCodexModel()
            AppLog.info("auth=\(String(describing: auth)) provider=\(draft.provider.rawValue)")
        }
        startLibraryWatch()
    }

    func refreshAuth() async {
        auth = await authClient.status()
    }

    func refreshResolvedCodexModel() async {
        let override = draft.model.trimmingCharacters(in: .whitespacesAndNewlines)
        resolvedCodexModel = override.isEmpty ? await authClient.resolveModel() : override
    }

    func savePreferences() {
        Preferences.save(draft)
        Task { await refreshResolvedCodexModel() }
    }

    /// 拉取中转模型列表（顺带验证 key）；返回错误文案，nil = 成功。
    func refreshRelayModels() async -> String? {
        let config = RelayConfig(baseURL: relayBaseURL, apiKey: relayKey)
        do {
            let models = try await RelayImageClient.fetchModels(config: config)
            if !models.isEmpty { relayModels = models }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: - 输出目录

    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "选择"
        panel.directoryURL = draft.outputDirectory
        guard panel.runModal() == .OK, let url = panel.url else { return }
        draft.outputDirectory = url
        BookmarkStore.save(url)
        ensureOutputDirectory()
        startLibraryWatch()
    }

    func openOutputDirectory() {
        ensureOutputDirectory()
        NSWorkspace.shared.open(draft.outputDirectory)
    }

    // MARK: - 参考图

    func addReferences(urls: [URL]) {
        var next = draft.references
        for url in urls {
            guard next.count < AppConstants.maxReferences else {
                showToast(String(localized: "Up to \(AppConstants.maxReferences) reference images"))
                break
            }
            if next.contains(where: { $0.url == url }) { continue }
            next.append(ReferenceImage(url: url))
        }
        draft.references = next
    }

    func removeReference(_ id: UUID) {
        draft.references.removeAll { $0.id == id }
    }

    /// 画廊一键迭代：把结果图设为参考图。
    func useAsReference(_ url: URL) {
        addReferences(urls: [url])
        showToast(String(localized: "Added as reference"))
    }

    /// ⌘V：文件 URL 或位图数据（截图）→ 参考图。
    func pasteReferences() {
        let board = NSPasteboard.general
        if let urls = board.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            addReferences(urls: urls.filter { isImageFile($0) })
            return
        }
        guard let image = NSImage(pasteboard: board),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pasted-\(UUID().uuidString.prefix(8)).png")
        do {
            try png.write(to: url)
            addReferences(urls: [url])
        } catch {
            showToast(String(localized: "Paste failed: \(error.localizedDescription)"))
        }
    }

    // MARK: - 生成

    func submit() {
        let prompt = draft.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty || !draft.references.isEmpty else {
            showToast(String(localized: "Write a prompt or add a reference image"))
            return
        }
        if let reason = blockedReason {
            showToast(reason)
            return
        }

        ensureOutputDirectory()
        savePreferences()
        if !prompt.isEmpty {
            recordPromptHistory(prompt)
        }

        let effectivePrompt = prompt.isEmpty
            ? "Edit the provided reference image(s)."
            : prompt

        let provider: ProviderSelection = switch draft.provider {
        case .codex:
            .codex(
                modelOverride: draft.model.isEmpty ? nil : draft.model,
                options: draft.options
            )
        case .relay:
            .relay(
                config: RelayConfig(baseURL: relayBaseURL, apiKey: relayKey),
                draft: draft.relay
            )
        }

        let runId = UUID()
        let itemIDs = (0 ..< draft.count).map { _ in UUID() }
        let request = GenerationRequest(
            prompt: effectivePrompt,
            referenceURLs: draft.references.map(\.url),
            count: draft.count,
            provider: provider,
            outputDirectory: draft.outputDirectory,
            runId: runId,
            itemIDs: itemIDs
        )
        AppLog.info(
            "submit provider=\(draft.provider.rawValue) count=\(draft.count) refs=\(draft.references.count) promptChars=\(effectivePrompt.count)"
        )
        start(request)
    }

    /// 单格重试：沿用该批次锚定的参数，只重跑一张；不可重试时给反馈，不静默。
    func retrySlot(_ item: GalleryItem) {
        guard case .failed = item.state, case .session(let runId) = item.source else { return }
        guard let origin = runRequests[runId] else {
            showToast(String(localized: "This batch is no longer retryable"))
            return
        }
        let request = GenerationRequest(
            prompt: origin.prompt,
            referenceURLs: origin.referenceURLs,
            count: 1,
            provider: origin.provider,
            outputDirectory: origin.outputDirectory,
            runId: UUID(),
            itemIDs: [UUID()]
        )
        items.removeAll { $0.id == item.id }
        start(request)
    }

    private func start(_ request: GenerationRequest) {
        runRequests[request.runId] = request
        let sessionItems = request.itemIDs.enumerated().map { idx, id in
            GalleryItem(
                id: id,
                state: .queued,
                createdAt: .now,
                source: .session(runId: request.runId),
                slotIndex: idx + 1
            )
        }
        // 新批次插到最前；其他批次（含进行中）全部保留
        items = sessionItems + items
        let runId = request.runId
        runTasks[runId] = Task { [weak self] in
            guard let self else { return }
            let stream = await engine.generate(request)
            for await event in stream {
                if Task.isCancelled { break }
                self.apply(event)
            }
            self.runTasks[runId] = nil
            self.recountRun()
            if !Task.isCancelled, self.runTasks.isEmpty {
                self.reloadLibraryKeepingActive()
            }
        }
        recountRun()
    }

    func cancel() {
        guard run.isBusy else { return }
        run = .cancelling
        Task { await engine.cancel() }
        for task in runTasks.values { task.cancel() }
        runTasks.removeAll()
        for index in items.indices {
            switch items[index].state {
            case .queued, .inFlight:
                items[index].state = .failed(String(localized: "Cancelled"))
            default:
                break
            }
        }
        run = .idle
    }

    // MARK: - 画廊操作

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func copyImage(_ url: URL) {
        guard let image = NSImage(contentsOf: url) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        showToast(String(localized: "Image copied"))
    }

    func deleteFile(_ url: URL) {
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            items.removeAll {
                if case .succeeded(let itemURL) = $0.state { return itemURL == url }
                return false
            }
        } catch {
            showToast(String(localized: "Delete failed: \(error.localizedDescription)"))
        }
    }

    func thumbnail(for url: URL) async -> NSImage? {
        await thumbnails.image(for: url)
    }

    func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    // MARK: - 收藏提示词

    func saveCurrentPromptAsFavorite() {
        let text = draft.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard !favorites.contains(where: { $0.text == text }) else {
            showToast(String(localized: "Already in favorites"))
            return
        }
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let title = String(firstLine.prefix(24))
        favorites.append(FavoritePrompt(title: title, text: text))
        showToast(String(localized: "Prompt saved to favorites"))
    }

    func removeFavorite(_ id: UUID) {
        favorites.removeAll { $0.id == id }
    }

    func togglePin(_ id: UUID) {
        guard let idx = favorites.firstIndex(where: { $0.id == id }) else { return }
        favorites[idx].pinned.toggle()
    }

    // MARK: - Private

    private func recordPromptHistory(_ prompt: String) {
        var next = promptHistory
        next.removeAll { $0 == prompt }
        next.insert(prompt, at: 0)
        if next.count > 50 { next.removeLast(next.count - 50) }
        promptHistory = next
    }

    private func isImageFile(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }

    private func apply(_ event: GenerationEvent) {
        switch event {
        case .started(let itemID, _):
            updateItem(id: itemID) { $0.state = .inFlight }
            recountRun()
        case .succeeded(let itemID, let index, let url):
            updateItem(id: itemID) {
                $0.state = .succeeded(url)
                $0.createdAt = .now
            }
            AppLog.info("slot #\(index) ok → \(url.lastPathComponent)")
            recountRun()
        case .failed(let itemID, let index, let message):
            updateItem(id: itemID) { $0.state = .failed(message) }
            AppLog.error("slot #\(index) failed: \(message)")
            recountRun()
        case .finished:
            recountRun()
        }
    }

    private func updateItem(id: UUID, mutate: (inout GalleryItem) -> Void) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        mutate(&items[idx])
    }

    /// 跨批次统计：total = 所有进行中批次的槽位数，inFlight = 其中未完成数。
    private func recountRun() {
        let activeRuns = Set(runTasks.keys)
        let activeBatch = items.filter { item in
            guard case .session(let id) = item.source else { return false }
            return activeRuns.contains(id)
        }
        let inFlight = activeBatch.filter {
            switch $0.state {
            case .queued, .inFlight: true
            default: false
            }
        }.count
        if inFlight == 0 {
            run = .idle
        } else {
            run = .running(inFlight: inFlight, total: max(activeBatch.count, inFlight))
        }
    }

    private func startLibraryWatch() {
        libraryTask?.cancel()
        let directory = draft.outputDirectory
        libraryTask = Task { [weak self] in
            guard let self else { return }
            let stream = library.watch(directory: directory)
            for await event in stream {
                if Task.isCancelled { break }
                if case .reloaded(let libraryItems) = event {
                    self.mergeLibrary(libraryItems)
                }
            }
        }
    }

    private func reloadLibraryKeepingActive() {
        mergeLibrary(LibraryStore.scan(directory: draft.outputDirectory))
    }

    private func mergeLibrary(_ libraryItems: [GalleryItem]) {
        let active = items.filter {
            switch $0.state {
            case .queued, .inFlight, .failed:
                if case .session = $0.source { return true }
                return false
            case .succeeded:
                return false
            }
        }
        let activePaths = Set(active.compactMap { item -> String? in
            if case .succeeded(let url) = item.state { return url.path }
            return nil
        })
        let history = libraryItems.filter { item in
            if case .succeeded(let url) = item.state {
                return !activePaths.contains(url.path)
            }
            return true
        }
        items = active + history
        Task { await thumbnails.invalidate() }
    }

    private func ensureOutputDirectory() {
        try? FileManager.default.createDirectory(
            at: draft.outputDirectory,
            withIntermediateDirectories: true
        )
    }
}
