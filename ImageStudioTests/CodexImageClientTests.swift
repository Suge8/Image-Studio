import XCTest
@testable import ImageStudio

final class CodexImageClientTests: XCTestCase {
    func testPayloadIsSingleImageRequest() {
        let payload = CodexImageClient.buildPayload(
            GenerationSlotRequest(
                prompt: "a cat",
                references: [],
                options: ImageOptions(),
                model: "gpt-test",
                cacheKey: "image-studio-1"
            )
        )
        XCTAssertEqual(payload["model"] as? String, "gpt-test")
        XCTAssertEqual(payload["stream"] as? Bool, true)
        XCTAssertEqual(payload["parallel_tool_calls"] as? Bool, false)
        XCTAssertEqual(payload["prompt_cache_key"] as? String, "image-studio-1")

        let tools = payload["tools"] as? [[String: Any]]
        XCTAssertEqual(tools?.first?["type"] as? String, "image_generation")
        XCTAssertEqual(tools?.first?["output_format"] as? String, "png")

        let instructions = payload["instructions"] as? String
        XCTAssertTrue(instructions?.contains("exactly one PNG") == true)
    }

    func testPayloadIncludesReferencesForEdit() {
        let payload = CodexImageClient.buildPayload(
            GenerationSlotRequest(
                prompt: "make blue",
                references: [PreparedImage(dataURL: "data:image/png;base64,abc")],
                options: ImageOptions(),
                model: "gpt-test",
                cacheKey: "k"
            )
        )
        let input = payload["input"] as? [[String: Any]]
        let content = input?.first?["content"] as? [[String: Any]]
        XCTAssertEqual(content?.count, 2)
        XCTAssertEqual(content?.last?["type"] as? String, "input_image")
        let instructions = payload["instructions"] as? String
        XCTAssertTrue(instructions?.contains("edit/reference") == true)
    }

    func testExtractImageResultFromItem() {
        var status: String?
        var error: [String: Any]?
        let raw = Data("hi".utf8).base64EncodedString()
        let event: [String: Any] = [
            "item": [
                "type": "image_generation_call",
                "status": "completed",
                "result": raw,
            ],
        ]
        let data = CodexImageClient.extractImageResult(
            from: event,
            lastStatus: &status,
            lastError: &error,
            acceptPartial: false
        )
        XCTAssertEqual(status, "completed")
        XCTAssertEqual(data, Data("hi".utf8))
    }

    func testExtractPartialImage() {
        var status: String?
        var error: [String: Any]?
        let raw = Data("partial".utf8).base64EncodedString()
        let event: [String: Any] = [
            "type": "response.image_generation_call.partial_image",
            "partial_image_b64": raw,
            "partial_image_index": 0,
        ]
        let data = CodexImageClient.extractImageResult(
            from: event,
            lastStatus: &status,
            lastError: &error,
            acceptPartial: true
        )
        XCTAssertEqual(data, Data("partial".utf8))
    }

    func testDecodeBase64AddsPadding() {
        // "hi" base64 is "aGk=" — drop padding to simulate API quirks
        let data = CodexImageClient.decodeBase64("aGk")
        XCTAssertEqual(data, Data("hi".utf8))
    }

    func testRetryDelayForRateLimit() {
        let event: [String: Any] = [
            "response": [
                "error": [
                    "code": "rate_limit_exceeded",
                    "message": "Rate limit reached. Please try again in 2s.",
                ],
            ],
        ]
        let err = ResponsesImageError(event: event)
        let retry = CodexImageClient.retryDelay(for: err, attempt: 0)
        XCTAssertNotNil(retry)
        XCTAssertGreaterThanOrEqual(retry!.0, 1.0)
    }

    func testHTTPStatusErrorSurfacesDetail() {
        let err = HTTPStatusError(
            status: 400,
            body: #"{"detail":"The 'gpt-5.5' model requires a newer version of Codex."}"#
        )
        XCTAssertEqual(
            err.localizedDescription,
            "HTTP 400: The 'gpt-5.5' model requires a newer version of Codex."
        )
    }

    func testModelTOMLParsingIsMultiline() {
        let text = """
        # comment
        foo = 1
        model = "gpt-5.6-sol"
        review_model = "gpt-5.2"
        """
        XCTAssertEqual(AuthClient.firstTOMLString(key: "model", in: text), "gpt-5.6-sol")
    }

    /// Codex image_generation tool 实测只认这 4 个值；非法值（如 2048x1152）会被后端静默忽略回落 auto。
    func testCodexSizeOnlyLegalValues() {
        XCTAssertEqual(
            ImageSizeOption.allCases.map(\.rawValue),
            ["auto", "1024x1024", "1536x1024", "1024x1536"]
        )
    }

    func testExtractImageFromSSEPartialAndFinal() throws {
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let b64 = png.base64EncodedString()
        let sse = """
        event: response.image_generation_call.partial_image
        data: {"type":"response.image_generation_call.partial_image","partial_image_b64":"\(b64)","partial_image_index":0}

        event: response.completed
        data: {"type":"response.completed"}

        """
        let data = try CodexImageClient.extractImageFromSSE(sse)
        XCTAssertEqual(data, png)
    }
}
