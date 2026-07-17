import Foundation

// MARK: - 通道

enum Provider: String, CaseIterable, Identifiable, Sendable {
    case codex
    case relay

    var id: String { rawValue }
    var label: String {
        switch self {
        case .codex: "Codex"
        case .relay: String(localized: "Relay")
        }
    }
}

/// Relay 通道参数（协议：比例 + 分辨率档位，实测比例精确、档位近似）。
enum RelayAspect: String, CaseIterable, Identifiable, Sendable {
    case auto
    case square = "1:1"
    case landscape = "16:9"
    case portrait = "9:16"
    case classic = "4:3"

    var id: String { rawValue }
    var label: String { rawValue }
}

enum RelayImageSize: String, CaseIterable, Identifiable, Sendable {
    case auto
    case k1 = "1K"
    case k2 = "2K"
    case k4 = "4K"

    var id: String { rawValue }
    var label: String { rawValue }
}

struct RelayDraft: Equatable, Sendable {
    var model: String = "gpt-image-2"
    var aspect: RelayAspect = .auto
    var imageSize: RelayImageSize = .auto
}

struct RelayConfig: Equatable, Sendable {
    var baseURL: URL
    var apiKey: String

    var submitURL: URL {
        baseURL.appendingPathComponent("v1/images/generations")
    }

    var modelsURL: URL {
        baseURL.appendingPathComponent("v1/models")
    }

    /// 任务查询是站点级接口（scheme+host），不带 base 路径前缀。
    func taskURL(id: String) -> URL {
        var parts = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        parts.path = "/v1/tasks/\(id)"
        parts.query = nil
        return parts.url!
    }
}

/// 中转模型（来自 {base}/v1/models，含单价缓存）。
struct RelayModel: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var price: Double?

    var priceLabel: String? {
        price.map { String(format: "$%.2f", $0) }
    }
}

// MARK: - Codex 通道选项

enum Quality: String, CaseIterable, Identifiable, Sendable {
    case auto, low, medium, high
    var id: String { rawValue }
    var label: String { rawValue }
}

/// Codex image_generation tool 实测只认这 4 个值；
/// 非法值（如 2048x1152）会被后端静默忽略回落 auto。
enum ImageSizeOption: String, CaseIterable, Identifiable, Sendable {
    case auto
    case square = "1024x1024"
    case landscape = "1536x1024"
    case portrait = "1024x1536"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto: "auto"
        case .square: "1:1"
        case .landscape: "3:2"
        case .portrait: "2:3"
        }
    }
}

enum BackgroundOption: String, CaseIterable, Identifiable, Sendable {
    case auto, transparent, opaque
    var id: String { rawValue }
    var label: String { rawValue }
}

struct ImageOptions: Equatable, Sendable {
    var quality: Quality = .auto
    var size: ImageSizeOption = .auto
    var background: BackgroundOption = .auto
}

// MARK: - 收藏提示词

struct FavoritePrompt: Codable, Equatable, Identifiable, Sendable {
    var id: UUID = UUID()
    var title: String
    var text: String
    var pinned: Bool = false

    /// 置顶在前，组内保持添加序（手动拼接保证稳定）。
    static func sorted(_ favorites: [FavoritePrompt]) -> [FavoritePrompt] {
        favorites.filter(\.pinned) + favorites.filter { !$0.pinned }
    }
}

// MARK: - Draft

struct ReferenceImage: Identifiable, Equatable, Sendable {
    let id: UUID
    let url: URL

    init(id: UUID = UUID(), url: URL) {
        self.id = id
        self.url = url
    }
}

struct Draft: Equatable, Sendable {
    var prompt: String = ""
    var references: [ReferenceImage] = []
    var count: Int = 4
    var provider: Provider = .codex
    var options: ImageOptions = .init()
    /// Codex 宿主模型覆写；空 = IMAGE_STUDIO_MODEL / ~/.codex/config.toml / 默认。
    var model: String = ""
    var relay: RelayDraft = .init()
    var outputDirectory: URL

    static var defaultOutputDirectory: URL {
        FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Image Studio", isDirectory: true)
    }

    init(outputDirectory: URL = Draft.defaultOutputDirectory) {
        self.outputDirectory = outputDirectory
    }
}

// MARK: - 状态

enum AuthState: Equatable, Sendable {
    case unknown
    case ready
    case missing
    case failed(String)
}

enum RunState: Equatable, Sendable {
    case idle
    case running(inFlight: Int, total: Int)
    case cancelling

    var isBusy: Bool {
        switch self {
        case .idle: false
        case .running, .cancelling: true
        }
    }
}

enum GalleryItemState: Equatable, Sendable {
    case queued
    case inFlight
    case succeeded(URL)
    case failed(String)
}

enum GallerySource: Equatable, Sendable {
    case session(runId: UUID)
    case library
}

struct GalleryItem: Identifiable, Equatable, Sendable {
    let id: UUID
    var state: GalleryItemState
    var createdAt: Date
    var source: GallerySource
    var slotIndex: Int?

    init(
        id: UUID = UUID(),
        state: GalleryItemState,
        createdAt: Date = .now,
        source: GallerySource,
        slotIndex: Int? = nil
    ) {
        self.id = id
        self.state = state
        self.createdAt = createdAt
        self.source = source
        self.slotIndex = slotIndex
    }
}

enum StudioError: Error, LocalizedError, Sendable {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): text
        }
    }
}

// MARK: - 常量

enum AppConstants {
    /// GPT Image models accept up to 16 input images on the Images/edit path.
    static let maxReferences = 16
    static let maxInputEdge = 1536
    static let defaultModel = "gpt-5.5"
    static let baseURL = URL(string: "https://chatgpt.com/backend-api/codex")!
    static let refreshURL = URL(string: "https://auth.openai.com/oauth/token")!
    static let codexClientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    static let originator = "codex_cli_rs"
    static let maxImageRetries = 4
    static let inputImageRateLimitDelays: [TimeInterval] = [65, 130, 260, 300]
    static let requestTimeout: TimeInterval = 300
    // Relay（实测：最快 35s、最慢 69s 完成；轮询是纪律显式例外——对方无事件接口）
    static let relayPresetModels = ["gpt-image-2", "nano-banana-2", "nano-banana-pro"]
    static let relayPollFirstDelay: TimeInterval = 5
    static let relayPollInterval: TimeInterval = 3
    static let relayPollMaxErrors = 5
    static let relayDownloadRetries = 2
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
}
