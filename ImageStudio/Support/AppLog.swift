import AppKit
import Foundation
import os

/// Lightweight diagnostics without Xcode.
/// - File: `~/Library/Logs/Image Studio/app.log` → `tail -f` in Terminal
/// - Memory ring: in-app Log panel
enum AppLog {
    private static let logger = Logger(subsystem: "app.image-studio.ImageStudio", category: "app")
    private static let lock = OSAllocatedUnfairLock(initialState: State())

    private struct State {
        var lines: [String] = []
        let maxLines = 500
        var fileHandle: FileHandle?
        var fileURL: URL?
    }

    static var logFileURL: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Image Studio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("app.log")
    }

    static func bootstrap() {
        lock.withLock { state in
            let url = logFileURL
            state.fileURL = url
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            state.fileHandle = try? FileHandle(forWritingTo: url)
            try? state.fileHandle?.seekToEnd()
        }
        info("Image Studio \(AppConstants.appVersion) started")
        info("log file: \(logFileURL.path)")
    }

    static func info(_ message: String) { write(level: "INFO", message) }
    static func warn(_ message: String) { write(level: "WARN", message) }
    static func error(_ message: String) { write(level: "ERROR", message) }
    static func debug(_ message: String) { write(level: "DEBUG", message) }

    static func snapshot() -> String {
        lock.withLock { state in
            state.lines.joined(separator: "\n")
        }
    }

    static func clear() {
        lock.withLock { state in
            state.lines.removeAll()
            if let url = state.fileURL {
                try? state.fileHandle?.close()
                FileManager.default.createFile(atPath: url.path, contents: Data())
                state.fileHandle = try? FileHandle(forWritingTo: url)
            }
        }
        info("log cleared")
    }

    static func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([logFileURL])
    }

    private static func write(level: String, _ message: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(stamp) [\(level)] \(message)"
        switch level {
        case "ERROR": logger.error("\(message, privacy: .public)")
        case "WARN": logger.warning("\(message, privacy: .public)")
        default: logger.log("\(message, privacy: .public)")
        }
        lock.withLock { state in
            state.lines.append(line)
            if state.lines.count > state.maxLines {
                state.lines.removeFirst(state.lines.count - state.maxLines)
            }
            if let handle = state.fileHandle, let data = (line + "\n").data(using: .utf8) {
                try? handle.write(contentsOf: data)
            }
        }
    }
}
