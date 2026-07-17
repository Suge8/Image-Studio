import AppKit
import Foundation
import ImageIO

actor ThumbnailCache {
    private var memory: [String: NSImage] = [:]

    func image(for url: URL, maxPixel: CGFloat = 512) -> NSImage? {
        let key = cacheKey(url: url, maxPixel: maxPixel)
        if let hit = memory[key] {
            return hit
        }
        guard let cg = loadCGImage(url: url, maxPixel: maxPixel) else { return nil }
        let image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        memory[key] = image
        return image
    }

    func invalidate() {
        memory.removeAll()
    }

    private func cacheKey(url: URL, maxPixel: CGFloat) -> String {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        let mtime = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
        return "\(url.path)|\(mtime)|\(maxPixel)"
    }

    private func loadCGImage(url: URL, maxPixel: CGFloat) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
