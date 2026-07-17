# Image Studio — macOS App 架构设计

> 目标：极简、高性能、轻量、无功能/兼容冗余；架构清晰；生图可无限并行；历史可渲染。  
> 平台：**macOS 15+ only**（不背旧系统兼容）。  
> 状态：**已实现（v0.1）** — 见仓库根目录 `ImageStudio.xcodeproj`。
>
> **v2 附记（已实现）**：新增第三方中转通道（enum 分派两实现，非 protocol 抽象层）与 UI 重设计，事实源见 `docs/v2-design.md`。与本文冲突处以 v2 为准：参考图上限 16（非 5）；Codex 尺寸仅 auto/1024²/1536×1024/1024×1536（实测非法值被静默忽略）；“不做多 backend 抽象”指投机性预留，真实第二后端已落地。

---

## 1. 产品一句话

**一个工作台：写 prompt、可选丢参考图、一次并行出任意多张图；结果落盘到指定目录，目录即历史。**

不做第二个产品面。不做账号体系。不做云。不做插件。

---

## 2. 硬约束

| 约束 | 决策 |
|---|---|
| 系统 | macOS 15.0+，Swift 6，SwiftUI |
| 兼容 | 不支持 14/13；不写 availability 分叉；不保留旧 API 垫片 |
| 依赖 | 默认零第三方；系统框架 only |
| 鉴权 | 复用本机 `codex login`（`~/.codex/auth.json`），App 内不重做 OAuth |
| 后端 | 现有 Codex ChatGPT image responses API（与 Python CLI 同协议） |
| 参考图 | 0–5 张（API 上限，不是产品假装的限制） |
| 并行 | **产品层不设并发上限**；N 张 = N 个独立请求同时飞 |
| 历史 | **不建历史数据库**；输出目录里的图片直接渲染为历史 |

---

## 3. 明确不做（防冗余）

- generate / edit / batch 三套 UI → 合并为一种工作流  
- 模式 Tab、项目系统、多窗口工作区  
- App 内登录、套餐/计费 UI  
- SQLite/Core Data 历史库、标签、搜索引擎  
- 人为「最多同时 3 路」之类的产品限流（限流只作为 429 后的退避重试）  
- dry-run、复杂 model 市场、预设商城、插件  
- 为未来多 backend 预留的协议抽象层  

---

## 4. 信息架构：单屏

```
┌──────────────────────────────────────────────────────────┐
│  Image Studio              [~/Pictures/Image Studio ▾] ⚙ │
├─────────────────┬────────────────────────────────────────┤
│ 参考图 0–5       │  画廊 = 当前任务 + 历史（同源）          │
│ [+][图]…         │  ┌────┐┌────┐┌────┐┌────┐             │
│                 │  │new ││ …  ││hist││hist│             │
│ Prompt          │  └────┘└────┘└────┘└────┘             │
│ ┌─────────────┐ │  新图插到最前；历史按文件时间倒序         │
│ │             │ │                                        │
│ └─────────────┘ │                                        │
│ 张数 N  画质 尺寸 │                                        │
│ 背景            │                                        │
│ [ 生成 ⌘↩ ]     │                                        │
└─────────────────┴────────────────────────────────────────┘
```

**交互公理**

1. 无参考图 → generate；有参考图 → edit。用户不选模式。  
2. 输出路径顶栏常驻，一点即改。  
3. 画廊渲染的是「目录中的图 + 进行中的占位」，不是另一套数据。  
4. 主操作只有一个：生成。

---

## 5. 架构总览

```
                    ┌──────────────┐
                    │  StudioView  │  唯一主界面
                    └──────┬───────┘
                           │ 绑定
                    ┌──────▼───────┐
                    │ StudioStore  │  @MainActor @Observable
                    │ 单一事实源    │  draft / run / gallery
                    └──────┬───────┘
           ┌───────────────┼───────────────┐
           │               │               │
   ┌───────▼──────┐ ┌──────▼──────┐ ┌──────▼────────┐
   │ AuthClient   │ │ Generation  │ │ LibraryStore  │
   │ (actor)      │ │ Engine      │ │ (actor)       │
   │ auth.json    │ │ (actor)     │ │ 扫目录/监视   │
   │ refresh      │ │ 无限并行    │ │ 缩略图        │
   └──────┬───────┘ └──────┬──────┘ └──────┬────────┘
          │                │               │
          │         ┌──────▼──────┐        │
          └────────►│ CodexImage  │        │
                    │ Client      │        │
                    │ SSE/API     │        │
                    └──────┬──────┘        │
                           │               │
                    ┌──────▼──────┐        │
                    │ ImagePrep   │        │
                    │ ImageIO     │        │
                    └─────────────┘        │
                           │               │
                    ┌──────▼───────────────▼──┐
                    │   输出目录 (Filesystem)   │
                    │   = 持久化唯一真相        │
                    └─────────────────────────┘
```

**层次规则**

- View 不碰网络、不碰文件枚举细节。  
- Store 只编排意图与 UI 状态。  
- 重活（网络、解码、扫盘）全在 actor / 后台。  
- **文件系统是历史与结果的唯一持久化**；内存状态可重建。

---

## 6. 模块职责

### 6.1 `StudioStore`（主线程，唯一 UI 状态）

```swift
@MainActor
@Observable
final class StudioStore {
    var draft: Draft
    var auth: AuthState                 // unknown | ready | missing | expired
    var run: RunState                   // idle | running(inFlight:total) | cancelling
    var items: [GalleryItem]            // 画廊：进行中槽位 + 已落盘历史
    // intents:
    // submit() / cancel() / setOutputDirectory() / addReferences() / removeReference()
}
```

- 所有按钮、快捷键只调用 Store 的 intent。  
- Engine / Library 通过回调或 `AsyncStream` 把事件送回 Store，由 Store 合并进 `items`。

### 6.2 `GenerationEngine`（actor）

```swift
struct GenerationRequest: Sendable {
    let prompt: String
    let references: [PreparedImage]     // 已压缩，最多 5
    let count: Int                      // N，任意正整数
    let options: ImageOptions           // quality/size/background
    let outputDirectory: URL
}

actor GenerationEngine {
    func generate(_ req: GenerationRequest) -> AsyncStream<GenerationEvent>
    func cancelAll()
}
```

**并行模型**

```
N 张 = N 个独立 Task，同时启动（产品无限并行）
每张：独立 prompt_cache_key（image-studio-{runId}-{index}）
每张：独立重试（401 refresh / 429 backoff）
任一张完成 → 立刻写盘 → yield .succeeded(index, url)
任一张失败 → yield .failed(index, error)，不取消其余
cancelAll → 取消 TaskGroup，已写盘文件保留
```

**关于「无限并行」与限流**

| 层 | 行为 |
|---|---|
| 产品 | 不限制 N，不限制同时 in-flight 数 |
| 传输 | 单连接失败/429 时**该路**退避重试 |
| UI | N 很大时用虚拟化网格，不一次解码 N 张全尺寸 |

不在 Engine 里塞「最大 3 并发」开关——那是兼容/防御式产品阉割。  
若日后 API 系统性打爆，用**可观测数据**再加策略，而不是先预置。

### 6.3 `CodexImageClient`（actor）

- 组装与 Python CLI 等价的 responses payload  
- SSE 解析，抽出生成图 base64  
- 401 → 通知 AuthClient refresh 后由 Engine 重试该路  
- 无 UI 类型；纯 `Sendable` 输入输出  

### 6.4 `AuthClient`（actor）

- 读 `$CODEX_HOME/auth.json`（默认 `~/.codex/auth.json`）  
- refresh_token 刷新并写回  
- `AuthState` 推给 Store；缺失时 UI 只提示去跑 `codex login`  

### 6.5 `ImagePrep`

- ImageIO 缩放：最长边默认 1536（与 CLI 一致）  
- 转成上传用 data URL / 编码字节  
- 全部离主线程  

### 6.6 `LibraryStore`（历史 = 目录）

```swift
actor LibraryStore {
    func load(directory: URL) async -> [GalleryItem]   // 扫图，按 mtime 倒序
    func events(directory: URL) -> AsyncStream<LibraryEvent>  // FSEvents/DirectoryEnumerator 监视
    func thumbnail(for url: URL, maxPixel: Int) async -> CGImage?
}
```

**历史如何「渲染出来」**

1. 启动 / 切换输出目录 → `load` 一次  
2. 画廊右侧（或整块）用懒加载网格显示缩略图  
3. 新生成成功 → 文件已在目录中 → item 从 `inFlight` 变为 `file(url)`，与历史同一模型  
4. 外部往该目录丢图 / 删图 → 监视器增量更新  

**不需要：**

- 历史表、迁移、索引服务  
- 「收藏夹」第二套存储  

**需要：**

- 安全作用域书签记住用户选的目录  
- 缩略图内存+磁盘小缓存（key = path + mtime），防滚动画廊卡顿  

### 6.7 文件命名（可预期、可排序）

```
{yyyyMMdd-HHmmss}-{shortPromptSlug}-{idx:02d}.png
```

- 同一批共享同一时间戳前缀，便于视觉成组  
- 冲突则在 stem 后追加 `-{2}`…  
- 默认不覆盖；设置里不提供一堆覆盖策略（YAGNI）

---

## 7. 画廊统一模型

```swift
enum GalleryItemState: Equatable {
    case queued
    case inFlight
    case succeeded(URL)
    case failed(String)
}

struct GalleryItem: Identifiable, Equatable {
    let id: UUID
    var state: GalleryItemState
    var createdAt: Date           // 进行中 = 提交时间；成功 = 文件 mtime
    var source: Source            // .session(runId) | .library
}
```

渲染规则：

- `queued` / `inFlight` → 骨架 + 序号  
- `succeeded` → 缩略图（异步）  
- `failed` → 简洁错误态，可单独重试该槽（v1 可整批重试，单槽重试可选）  
- 排序：进行中置顶（按 index），其下历史按 `createdAt` 倒序  

一次 `submit`：

1. 创建 `runId`  
2. 插入 N 个 `queued` item  
3. 并行推进状态  
4. 成功写盘后 `source` 实质与 library 同源（都是文件）  

---

## 8. Draft 与选项

```swift
struct Draft: Equatable {
    var prompt: String = ""
    var references: [ReferenceImage] = []  // max 5
    var count: Int = 4
    var quality: Quality = .auto           // auto|low|medium|high
    var size: ImageSize = .auto            // auto|1024|1536x1024|1024x1536
    var background: Background = .auto     // auto|transparent|opaque
    var outputDirectory: URL               // bookmark 恢复
}
```

设置面板（⚙）仅放低频项：

- 打开 Codex 目录说明 / 重新检测登录  
- 默认张数、默认画质（可选）  
- 关于版本  

**不进设置：** 第二套主题系统、快捷键编辑器、代理矩阵。

---

## 9. 并发与性能

| 路径 | 策略 |
|---|---|
| 生成 | N 路 Task 全开；单路独立重试 |
| SSE | 按事件增量解析，勿整包进内存再拆 |
| 写盘 | 先写临时文件再 `replace`，防半截图进历史 |
| 缩略图 | 解码限最大边（如 512）；主线程只收 `Image` |
| 画廊 | `LazyVGrid` + 可视区加载；万级文件也不全量解码 |
| 扫盘 | 仅枚举常见图片扩展名；后台 actor |
| 取消 | 协作式 `Task.cancel`；已完成文件保留 |
| 内存 | 不在 Store 持有全尺寸 bitmap；只持 URL + 状态 |

---

## 10. 错误语义（对用户诚实）

| 情况 | UI |
|---|---|
| 无 auth | 非阻塞横幅：「运行 `codex login` 后点重试」 |
| 单张 429 耗尽重试 | 该槽失败，其它继续 |
| 全部失败 | `run = idle`，横幅汇总 |
| 目录无写权限 | 提交前校验，直接提示换目录 |
| 参考图 > 5 | 添加时拒绝，toast 一句 |

禁止：静默吞错、假成功、自动降到「串行模式」却不告知。

---

## 11. 技术选型（macOS 15+ 专用）

| 用途 | 选用 |
|---|---|
| UI | SwiftUI + Observation |
| 并发 | Swift concurrency / actors / TaskGroup |
| 网络 | URLSession（bytes / 流式） |
| 图片 | ImageIO / CoreGraphics |
| 目录监视 | FSEvents 或 `DispatchSource` 文件监视 |
| 存储偏好 | `AppStorage` + security-scoped bookmark |
| 预览 | Quick Look（`QLPreviewPanel`）可选 |

不引入 Electron、不引入 Python runtime 嵌进 App（那是打包，不是这个设计的目标）。

---

## 12. 工程目录（建议）

```
apps/ImageStudio/
  Package.swift                    // 或 Xcode project，二选一，不双轨
  Sources/
    App/
      ImageStudioApp.swift
    Features/
      Studio/
        StudioView.swift
        StudioStore.swift
        GalleryView.swift
        ComposerView.swift         // prompt + refs + 参数
    Engine/
      GenerationEngine.swift
      CodexImageClient.swift
      AuthClient.swift
      ImagePrep.swift
      LibraryStore.swift
      Models.swift                 // Draft, GalleryItem, API DTO
    Support/
      OutputNaming.swift
      BookmarkStore.swift
  Tests/
    EngineTests/
    StoreTests/
```

测试重点：payload 形状、SSE 解析、命名冲突、Store 状态合并、取消。  
UI 测试后置；Engine 先绿。

---

## 13. 与现有 Python CLI 的关系

| | Python CLI | Mac App |
|---|---|---|
| 协议 | 同源 Codex responses | 同源，Swift 重实现 |
| 并行 | 现为串行 for-loop | 无限并行 TaskGroup |
| 历史 | 无 | 输出目录渲染 |
| 批处理 | JSONL | 用 N + 画廊替代 |
| 去留 | 可继续作脚本入口 | 独立 App 目标 |

不要求 App 链到 Python 包；**协议兼容、实现独立**。  
CLI 可保留给自动化；App 不依赖它运行。

---

## 14. 实现顺序（可验证里程碑）

1. **工程骨架** macOS 15、单窗口、空 Store  
2. **AuthClient** 读 token + 单测  
3. **CodexImageClient** 单张 generate 命令行/测试跑通  
4. **ImagePrep + 参考图** edit 跑通  
5. **GenerationEngine** N 路并行 + 取消 + 写盘  
6. **LibraryStore** 扫目录 + 缩略图  
7. **Studio UI** Composer + Gallery 接 Store  
8. **打磨** 快捷键、失败态、QL 预览、书签权限  

每步结束都有可运行证据；不平行堆五个半成品层。

---

## 15. 默认值（可改，需显式）

| 项 | 默认 |
|---|---|
| 系统 | macOS 15+ |
| N | 4 |
| 并行上限 | **无** |
| 输出目录 | `~/Pictures/Image Studio` |
| 格式 | PNG |
| quality/size/background | auto |
| 参考图上限 | 5（API） |
| 输入最长边 | 1536 |

---

## 16. 设计裁决备忘

1. **目录即历史** — 消灭历史子系统。  
2. **无限并行** — 产品直觉优先；正确性靠单路重试，不靠假上限。  
3. **单 Store** — 禁止 ViewModel 丛林。  
4. **15+ only** — 用新 API，不写兼容枝。  
5. **零第三方起步** — 有测量证据再加依赖。  

---

## 17. 开放点（实现前只需定这些）

- [ ] Bundle ID / 签名团队（本地 ad-hoc 也可先跑）  
- [ ] 单槽失败是否提供「重试这一张」（可 v1.1）  
- [ ] 画廊是否分组显示「同一批」（靠文件名前缀即可，无需新模型）  
