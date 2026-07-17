import Foundation

enum LibraryEvent: Sendable {
    case reloaded([GalleryItem])
}

actor LibraryStore {
    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "webp", "gif", "heic", "tif", "tiff",
    ]

    nonisolated static func scan(directory: URL) -> [GalleryItem] {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var items: [GalleryItem] = []
        for url in urls {
            let ext = url.pathExtension.lowercased()
            guard imageExtensions.contains(ext) else { continue }
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])
            guard values?.isRegularFile == true else { continue }
            let mtime = values?.contentModificationDate ?? .distantPast
            items.append(
                GalleryItem(
                    id: stableID(for: url),
                    state: .succeeded(url),
                    createdAt: mtime,
                    source: .library
                )
            )
        }
        items.sort { $0.createdAt > $1.createdAt }
        return items
    }

    func load(directory: URL) -> [GalleryItem] {
        Self.scan(directory: directory)
    }

    /// Lightweight directory watcher. Emits full reloads on change.
    nonisolated func watch(directory: URL) -> AsyncStream<LibraryEvent> {
        AsyncStream { continuation in
            continuation.yield(.reloaded(Self.scan(directory: directory)))

            let fd = open(directory.path, O_EVTONLY)
            guard fd >= 0 else {
                continuation.finish()
                return
            }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete, .extend, .attrib],
                queue: DispatchQueue.global(qos: .utility)
            )
            source.setEventHandler {
                continuation.yield(.reloaded(Self.scan(directory: directory)))
            }
            source.setCancelHandler {
                close(fd)
            }
            source.resume()
            continuation.onTermination = { _ in
                source.cancel()
            }
        }
    }

    /// Stable-ish ID from path so SwiftUI diffs don't thrash on reload.
    nonisolated private static func stableID(for url: URL) -> UUID {
        let path = url.standardizedFileURL.path
        var hasher = Hasher()
        hasher.combine(path)
        let value = UInt64(bitPattern: Int64(hasher.finalize()))
        return UUID(uuid: (
            UInt8(truncatingIfNeeded: value >> 56),
            UInt8(truncatingIfNeeded: value >> 48),
            UInt8(truncatingIfNeeded: value >> 40),
            UInt8(truncatingIfNeeded: value >> 32),
            UInt8(truncatingIfNeeded: value >> 24),
            UInt8(truncatingIfNeeded: value >> 16),
            UInt8(truncatingIfNeeded: value >> 8),
            UInt8(truncatingIfNeeded: value),
            0, 0, 0, 0, 0, 0, 0, 1
        ))
    }
}
