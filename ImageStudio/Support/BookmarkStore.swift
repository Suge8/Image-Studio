import Foundation

enum BookmarkStore {
    private static let key = "outputDirectoryBookmark"

    static func save(_ url: URL) {
        do {
            let data = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: key)
            UserDefaults.standard.set(url.path, forKey: "outputDirectoryPath")
        } catch {
            UserDefaults.standard.set(url.path, forKey: "outputDirectoryPath")
        }
    }

    static func load() -> URL? {
        if let data = UserDefaults.standard.data(forKey: key) {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                _ = url.startAccessingSecurityScopedResource()
                return url
            }
        }
        if let path = UserDefaults.standard.string(forKey: "outputDirectoryPath") {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return nil
    }
}
