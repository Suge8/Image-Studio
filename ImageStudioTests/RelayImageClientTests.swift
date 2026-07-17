import Foundation
import Testing
@testable import ImageStudio

@Suite("RelayImageClient")
struct RelayImageClientTests {
    // MARK: - Payload

    @Test func payloadMinimal() throws {
        let payload = RelayImageClient.buildPayload(
            prompt: "a cat",
            references: [],
            model: "gpt-image-2",
            aspect: .auto,
            imageSize: .auto
        )
        #expect(payload["model"] as? String == "gpt-image-2")
        #expect(payload["prompt"] as? String == "a cat")
        #expect(payload["n"] as? Int == 1)
        #expect(payload["async"] as? Bool == true)
        // auto 不发送，让上游用默认
        #expect(payload["size"] == nil)
        #expect(payload["imageSize"] == nil)
        #expect(payload["image"] == nil)
    }

    @Test func payloadFull() throws {
        let refs = [PreparedImage(dataURL: "data:image/png;base64,AAAA")]
        let payload = RelayImageClient.buildPayload(
            prompt: "edit",
            references: refs,
            model: "nano-banana-pro",
            aspect: .landscape,
            imageSize: .k2
        )
        #expect(payload["size"] as? String == "16:9")
        #expect(payload["imageSize"] as? String == "2K")
        #expect(payload["image"] as? [String] == ["data:image/png;base64,AAAA"])
    }

    // MARK: - 提交解析

    @Test func parseSubmitTask() throws {
        let data = Data(#"{"task_id":"task_abc","status":"processing","progress":0}"#.utf8)
        guard case .task(let id) = try RelayImageClient.parseSubmit(data) else {
            Issue.record("expected task"); return
        }
        #expect(id == "task_abc")
    }

    @Test func parseSubmitSyncImages() throws {
        // 标准 OpenAI 同步中转：直接返回结果
        let data = Data(#"{"created":1,"data":[{"b64_json":"QUJD"}]}"#.utf8)
        guard case .images(let images) = try RelayImageClient.parseSubmit(data) else {
            Issue.record("expected images"); return
        }
        #expect(images.first?.b64 == "QUJD")
    }

    @Test func parseSubmitError() throws {
        let data = Data(#"{"error":"余额不足"}"#.utf8)
        #expect(throws: RelayError.self) {
            try RelayImageClient.parseSubmit(data)
        }
        do {
            _ = try RelayImageClient.parseSubmit(data)
        } catch let error as RelayError {
            #expect(error.message == "余额不足")
        }
    }

    // MARK: - 任务解析

    @Test func parseTaskPending() throws {
        let data = Data(#"{"task_id":"t","status":"in_progress","progress":45}"#.utf8)
        guard case .pending = try RelayImageClient.parseTask(data) else {
            Issue.record("expected pending"); return
        }
    }

    @Test func parseTaskCompletedURL() throws {
        let data = Data(#"{"created":1,"data":[{"url":"https://cdn.example.com/a.png"}]}"#.utf8)
        guard case .completed(let images) = try RelayImageClient.parseTask(data) else {
            Issue.record("expected completed"); return
        }
        #expect(images.first?.url == "https://cdn.example.com/a.png")
    }

    @Test func parseTaskFailed() throws {
        let data = Data(#"{"task_id":"t","status":"failed","error":{"message":"上游生成失败","code":""}}"#.utf8)
        guard case .failed(let message) = try RelayImageClient.parseTask(data) else {
            Issue.record("expected failed"); return
        }
        #expect(message == "上游生成失败")
    }

    // MARK: - 模型列表

    @Test func parseModels() throws {
        let json = #"""
        {"object":"list","data":[
            {"id":"gpt-image-2","price_config":{"request_price":0.04}},
            {"id":"nano-banana-pro","price_config":{"request_price":0.18}},
            {"id":"no-price"}
        ]}
        """#
        let models = try RelayImageClient.parseModels(Data(json.utf8))
        #expect(models.count == 3)
        #expect(models[0].id == "gpt-image-2")
        #expect(models[0].price == 0.04)
        #expect(models[2].price == nil)
    }

    // MARK: - URL 派生

    @Test func taskURLIsSiteLevel() throws {
        let config = RelayConfig(
            baseURL: URL(string: "https://www.right.codes/draw")!,
            apiKey: "sk-test"
        )
        #expect(config.submitURL.absoluteString == "https://www.right.codes/draw/v1/images/generations")
        #expect(config.modelsURL.absoluteString == "https://www.right.codes/draw/v1/models")
        // 任务查询是站点级，不带 /draw 前缀
        #expect(config.taskURL(id: "task_x").absoluteString == "https://www.right.codes/v1/tasks/task_x")
    }

    @Test func taskURLWithoutBasePath() throws {
        let config = RelayConfig(baseURL: URL(string: "https://api.example.com")!, apiKey: "k")
        #expect(config.taskURL(id: "t1").absoluteString == "https://api.example.com/v1/tasks/t1")
    }
}
