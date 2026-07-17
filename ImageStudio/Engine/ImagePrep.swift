import Foundation
import ImageIO
import UniformTypeIdentifiers

struct PreparedImage: Sendable {
    let dataURL: String
}

/// 上传编码：codex 路用 webp（体积小）；relay 路用 png（协议文档口径，已实测）。
enum PreparedImageFormat {
    case webp, png
}

enum ImagePrep {
    static func prepare(
        url: URL,
        maxEdge: Int = AppConstants.maxInputEdge,
        format: PreparedImageFormat = .webp
    ) throws -> PreparedImage {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw StudioError.message("Image file not found: \(url.path)")
        }
        if let compacted = compact(url: url, maxEdge: maxEdge, format: format) {
            return PreparedImage(dataURL: compacted)
        }
        let data = try Data(contentsOf: url)
        let mime = mimeType(for: url)
        return PreparedImage(dataURL: "data:\(mime);base64,\(data.base64EncodedString())")
    }

    private static func compact(url: URL, maxEdge: Int, format: PreparedImageFormat) -> String? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        let edge = max(width, height)
        let maxPixel = maxEdge > 0 ? min(edge == 0 ? maxEdge : edge, maxEdge) : max(edge, 1)

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let (utType, mime): (UTType, String) = switch format {
        case .webp: (.webP, "image/webp")
        case .png: (.png, "image/png")
        }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data,
            utType.identifier as CFString,
            1,
            nil
        ) else { return nil }
        let destProps: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.9,
        ]
        CGImageDestinationAddImage(dest, cgImage, destProps as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return "data:\(mime);base64,\(data.base64EncodedString())"
    }

    private static func mimeType(for url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension),
           let mime = type.preferredMIMEType {
            return mime
        }
        return "image/png"
    }
}
