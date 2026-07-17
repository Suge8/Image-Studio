import Foundation

enum OutputNaming {
    static func slug(from prompt: String, maxLength: Int = 40) -> String {
        let lowered = prompt.lowercased()
        let mapped = lowered.map { character -> Character in
            if character.isLetter || character.isNumber {
                return character
            }
            return "-"
        }
        var collapsed = String(mapped)
        while collapsed.contains("--") {
            collapsed = collapsed.replacingOccurrences(of: "--", with: "-")
        }
        collapsed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        if collapsed.isEmpty { return "image" }
        if collapsed.count <= maxLength { return collapsed }
        let end = collapsed.index(collapsed.startIndex, offsetBy: maxLength)
        return String(collapsed[..<end]).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    static func fileName(prompt: String, index: Int, total: Int, date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: date)
        let body = slug(from: prompt)
        if total <= 1 {
            return "\(stamp)-\(body).png"
        }
        return String(format: "%@-%@-%02d.png", stamp, body, index)
    }

    static func uniqueURL(in directory: URL, preferredName: String) -> URL {
        let fm = FileManager.default
        let url = directory.appendingPathComponent(preferredName)
        if !fm.fileExists(atPath: url.path) {
            return url
        }
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var n = 2
        while true {
            let candidate = directory.appendingPathComponent("\(stem)-\(n).\(ext)")
            if !fm.fileExists(atPath: candidate.path) {
                return candidate
            }
            n += 1
        }
    }
}
