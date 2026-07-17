import Foundation

/// UserDefaults 单一入口：Draft 偏好与中转模型缓存。
/// API Key 在 KeychainStore；输出目录书签在 BookmarkStore。
enum Preferences {
    private static var defaults: UserDefaults { .standard }

    private enum Key {
        static let provider = "provider"
        static let count = "defaultCount"
        static let codexModel = "modelOverride"
        static let codexSize = "imageSize"
        static let relayBaseURL = "relayBaseURL"
        static let relayModel = "relayModel"
        static let relayAspect = "relayAspect"
        static let relayImageSize = "relayImageSize"
        static let relayModels = "relayModels"
        static let promptHistory = "promptHistory"
        static let favoritePrompts = "favoritePrompts"
        static let favoritesSeeded = "favoritesSeeded"
        static let appleLanguages = "AppleLanguages"
    }

    static func loadDraft() -> Draft {
        var draft = Draft()
        if let saved = BookmarkStore.load() {
            draft.outputDirectory = saved
        }
        if let raw = defaults.string(forKey: Key.provider), let provider = Provider(rawValue: raw) {
            draft.provider = provider
        }
        let count = defaults.integer(forKey: Key.count)
        if count >= 1 { draft.count = count }
        draft.model = defaults.string(forKey: Key.codexModel) ?? ""
        if let raw = defaults.string(forKey: Key.codexSize), let size = ImageSizeOption(rawValue: raw) {
            draft.options.size = size
        }
        if let raw = defaults.string(forKey: Key.relayModel), !raw.isEmpty {
            draft.relay.model = raw
        }
        if let raw = defaults.string(forKey: Key.relayAspect), let aspect = RelayAspect(rawValue: raw) {
            draft.relay.aspect = aspect
        }
        if let raw = defaults.string(forKey: Key.relayImageSize), let size = RelayImageSize(rawValue: raw) {
            draft.relay.imageSize = size
        }
        return draft
    }

    static func save(_ draft: Draft) {
        defaults.set(draft.provider.rawValue, forKey: Key.provider)
        defaults.set(draft.count, forKey: Key.count)
        defaults.set(draft.model, forKey: Key.codexModel)
        defaults.set(draft.options.size.rawValue, forKey: Key.codexSize)
        defaults.set(draft.relay.model, forKey: Key.relayModel)
        defaults.set(draft.relay.aspect.rawValue, forKey: Key.relayAspect)
        defaults.set(draft.relay.imageSize.rawValue, forKey: Key.relayImageSize)
    }

    static var relayBaseURL: URL {
        get {
            guard let raw = defaults.string(forKey: Key.relayBaseURL), let url = URL(string: raw) else {
                return AppConstants.relayDefaultBaseURL
            }
            return url
        }
        set { defaults.set(newValue.absoluteString, forKey: Key.relayBaseURL) }
    }

    static var relayModels: [RelayModel] {
        get {
            guard let data = defaults.data(forKey: Key.relayModels),
                  let models = try? JSONDecoder().decode([RelayModel].self, from: data)
            else { return [] }
            return models
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.relayModels)
        }
    }

    static var promptHistory: [String] {
        get { defaults.stringArray(forKey: Key.promptHistory) ?? [] }
        set { defaults.set(newValue, forKey: Key.promptHistory) }
    }

    /// 收藏提示词；首次读取时 seed 内置模板（一次性，删除后不复活）。
    static var favoritePrompts: [FavoritePrompt] {
        get {
            if !defaults.bool(forKey: Key.favoritesSeeded) {
                defaults.set(true, forKey: Key.favoritesSeeded)
                let seeded = [BuiltinPrompts.logoBoard]
                defaults.set(try? JSONEncoder().encode(seeded), forKey: Key.favoritePrompts)
                return seeded
            }
            guard let data = defaults.data(forKey: Key.favoritePrompts),
                  let favorites = try? JSONDecoder().decode([FavoritePrompt].self, from: data)
            else { return [] }
            return favorites
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.favoritePrompts)
        }
    }

    /// App 语言：nil = 跟随系统；否则为 BCP-47 码（zh-Hans / en）。改后需重启生效。
    static var languageOverride: String? {
        get { defaults.stringArray(forKey: Key.appleLanguages)?.first }
        set {
            if let newValue {
                defaults.set([newValue], forKey: Key.appleLanguages)
            } else {
                defaults.removeObject(forKey: Key.appleLanguages)
            }
        }
    }
}
