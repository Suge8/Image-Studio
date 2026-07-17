import XCTest
@testable import ImageStudio

final class OutputNamingTests: XCTestCase {
    func testSlugStripsNoise() {
        XCTAssertEqual(OutputNaming.slug(from: "A Bronze Shield!"), "a-bronze-shield")
        XCTAssertEqual(OutputNaming.slug(from: "   "), "image")
    }

    func testFileNameSingleAndMulti() {
        let date = Date(timeIntervalSince1970: 0)
        let single = OutputNaming.fileName(prompt: "Cat", index: 1, total: 1, date: date)
        XCTAssertTrue(single.hasSuffix("-cat.png"))
        XCTAssertFalse(single.contains("-01.png"))

        let multi = OutputNaming.fileName(prompt: "Cat", index: 2, total: 4, date: date)
        XCTAssertTrue(multi.hasSuffix("-cat-02.png"))
    }

    func testUniqueURLIncrements() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = dir.appendingPathComponent("shot.png")
        try Data([0x00]).write(to: first)
        let next = OutputNaming.uniqueURL(in: dir, preferredName: "shot.png")
        XCTAssertEqual(next.lastPathComponent, "shot-2.png")
    }
}
