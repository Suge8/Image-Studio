# Image Studio v2 — 双通道 + UI 重设计

> 状态：**设计稿，待确认**。确认后实施，并将定案并入 `mac-app-design.md`。
> 原则不变：极简、零第三方依赖、macOS 15+ only、一路请求 1 张图、目录即历史。

---

## 1. 目标

1. 新增**第三方中转通道**（Relay）：API Key + Base URL，与现有 Codex 登录态通道并存，随时切换。
2. UI 整体重设计：一眼看懂、动效丝滑、低频参数收进 popover。
3. 拿图快速稳定：轮询节奏、下载重试、错误语义全部显式设计。

## 2. Relay 协议实测事实（2025-01，right.codes，全部端到端验证）

| 事实 | 结论 |
|---|---|
| 提交 | `POST {base}/v1/images/generations`，`async:true`，立即返回 `task_id` |
| 轮询 | `GET {origin}/v1/tasks/{task_id}`（**站点根，不带 /draw**） |
| 完成形状 | `{"created":…,"data":[{"url":"https://fileN.aitohumanize.com/…png"}]}` — CDN URL，需二次下载 |
| 失败形状 | `{"status":"failed","error":{"message":…}}` |
| 实测耗时 | nano-banana-2 ≈35s；edit ≈43s；gpt-image-2 ≈63s；nano-banana-pro ≈69s |
| **progress 不可靠** | nano 系列恒为 0；gpt-image-2 仅 0→2→10→完成。**不做进度环**，做已耗时计时 |
| 参考图 | `"image": ["data:image/png;base64,…"]` 数组，实测可用（ImagePrep 已产出该格式） |
| 尺寸 | `size`: 比例 `1:1/16:9/9:16/4:3` 或像素串；`imageSize`: `1K/2K/4K`（nano/gpt-image vip） |
| 实际输出 | **比例精确尊重，分辨率为近似档位**：1:1+1K → 1254²（gpt-image-2）/ 1024²（nano-banana-2）；16:9+1K → 1376×768；16:9+2K → 1672×941 |
| 模型列表 | `GET {base}/v1/models` 可用，含单价：gpt-image-2 $0.04 · nano-banana-2-lite $0.05 · nano-banana-2 $0.12 · gpt-image-2-vip $0.13 · nano-banana $0.14 · nano-banana-pro $0.18 |
| 鉴权错误 | 无效 key → 401 `{"error":"无效的API Key"}`；余额不足 → 403 `{"error":"余额不足"}` |
| 取消 | 无取消 API；本地取消 = 停止轮询放弃结果 |

## 3. 架构

### 3.1 通道模型

```
Provider（enum，Draft 内单一事实源，持久化）
├── .codex → CodexImageClient（现状，零改动）
└── .relay → RelayImageClient（新增，~180 行）
```

- `GenerationEngine.generateOne` 按 provider 分派；重试策略封装在各自 client（Codex：401 refresh + 限流退避；Relay：见 3.3）。
- ImagePrep / OutputNaming / LibraryStore / 画廊 / 写盘全部复用，不动。
- 设计文档原"不做多 backend 抽象"针对投机性预留；现在是真实第二后端，抽象只到"一个 enum 分派两个实现"，不做 protocol 层。

### 3.2 RelayImageClient（新增）

```
submit(prompt, refs, model, aspect, imageSize) → task_id | 直接结果
poll(task_id)   → in_progress | completed(url/b64) | failed(message)
download(url)   → Data（PNG）
```

- **同步中转兼容**：提交响应若直接含 `data[]`（标准 OpenAI 同步中转）→ 跳过轮询直接取 `b64_json` 或 `url`。一个分支，覆盖两类中转。
- **URL 派生**：配置存 base（默认 `https://www.right.codes/draw`）；提交 = `{base}/v1/images/generations`；轮询 = `{scheme+host}/v1/tasks/{id}`。
- `n` 固定 1；N 张 = N 路并行提交 + 各自独立轮询（沿用现有并行模型）。

### 3.3 轮询与稳定性

> 轮询是项目纪律的显式例外：中转只提供任务查询接口，无 SSE/webhook。

| 项 | 策略 | 理由 |
|---|---|---|
| 首查延迟 | 5s | 实测最快 35s 完成，前 5s 查必为空 |
| 间隔 | 3s ± 0.5s jitter | N 路各自独立轮询；N=64 极端时 ~21 req/s 峰值可接受，jitter 防齐步 |
| 轮询超时 | 300s（复用 `requestTimeout`） | 实测最慢 69s，4K 留余量 |
| 轮询网络错误 | 不计失败，下轮重试；连续 5 次才判失败 | 轮询丢一次包不该杀任务 |
| CDN 下载 | 失败重试 2 次，单次 60s 超时 | 多 CDN 域名（file1/2/5…），偶发抖动 |
| 401/403 | 立即失败，不重试，映射人话文案 | key 无效/余额不足重试无意义 |
| 取消 | 停止轮询、放弃任务 | 无服务端取消 API |

### 3.4 Key 存储

`Support/KeychainStore.swift`（~40 行，Security 框架）：`kSecClassGenericPassword`，service = bundle id，account = `relay-api-key`。Base URL / 模型选择存 UserDefaults（非机密）。

### 3.5 模型列表

保存 Key/Base URL 时 `GET {base}/v1/models` 拉一次并缓存（含单价）；失败则回落预置 `[gpt-image-2, nano-banana-2, nano-banana-pro]`；下拉底部保留"自定义…"手输。价格用于 UI 显示预估费用。

### 3.6 尺寸模型（per-provider，不做就近映射）

**Codex 通道实测事实（2025-01 对照实验）**：`image_generation` tool 只认 `auto / 1024x1024 / 1536x1024 / 1024x1536`；发 `2048x1152` 会被**静默忽略回落 auto**（实测输出 1254×1254 正方形）。旧版 App 的 2K 家族选项（2048x2048/2048x1152/1152x2048）从未生效——本次修复：**Codex 通道删除 2K 假选项**，只保留 4 个合法值。要大图/宽比例走 Relay 通道。

另实测：SSE 的 partial image 与 final 字节级相同，现有"取第一个 partial"逻辑无质量损失，保留。

两通道参数语义不同，**各存各的、各显各的**，不发明统一抽象再偷偷映射：

```swift
struct Draft {
    var provider: Provider = .codex
    var options: ImageOptions          // Codex：quality/size/background（现状不动）
    var relay: RelayDraft              // Relay：model / aspect / imageSize
}
struct RelayDraft {
    var model: String = "gpt-image-2"
    var aspect: RelayAspect = .auto    // auto|1:1|16:9|9:16|4:3
    var imageSize: RelayImageSize = .auto  // auto|1K|2K|4K
}
```

Codex 尺寸选项收敛为 `auto / 1:1 / 3:2 / 2:3`（即 4 个合法值）。Composer 参数 chips 按当前 provider 显示对应集合；画质/背景仅 Codex 显示。

### 3.7 顺手架构收口（同一次改造内，均有独立理由）

1. **Preferences 收敛**：现散在 `init`/`savePreferences` 的裸字符串 UserDefaults key → 一个 `Preferences` 类型统一读写（provider 配置也放这）。
2. **LogView 1s Timer 轮询日志** 违反自家纪律 → AppLog 内存环形缓冲 + 变更回调。
3. **GalleryCell 缩略图**加载无取消保护 → 随 UI 改造一并收口。

## 4. UI 设计

> UI 设计事实源已迁至 `docs/DESIGN.md`（配色 token、组件词汇、动效规格、交互规范）。本节保留当时的设计推导过程供回溯，现状以 DESIGN.md 为准。

### 4.1 布局

```
┌──────────────────────────────────────────────────────────────┐
│ Image Studio      [⌘ Codex · gpt-5.x ▾]  [~/Pictures/… ▾] ⚙ │  toolbar
├───────────────────────┬──────────────────────────────────────┤
│ PROMPT（主角，大输入区）│  画廊                                 │
│ ┌───────────────────┐ │  ┌────┐ ┌────┐ ┌────┐ ┌────┐        │
│ │                   │ │  │▒▒▒▒│ │▒▒▒▒│ │img │ │img │        │
│ │                   │ │  │ 12s│ │ 09s│ └────┘ └────┘        │
│ └───────────────────┘ │  └────┘ └────┘                       │
│ 参考图 ▢▢▢ ＋（拖/贴） │  hover 浮起 · 空格预览 · 拖出 · 右键   │
│ [4 张] [1:1·1K] [auto]│                                      │
│ ┌───────────────────┐ │                                      │
│ │    生成  ⌘↩       │ │                                      │
│ └───────────────────┘ │                                      │
└───────────────────────┴──────────────────────────────────────┘
```

- **Provider 胶囊**（toolbar）：`⌘ Codex · gpt-5.x` ↔ `☁ 中转 · nano-banana-pro`。点击弹 popover：两通道单选 + relay 模型下拉（含单价）；中转未配置时点击引导去设置。当前通道一眼可见。
- **参数 chips**：`4 张`、`1:1 · 1K`、`画质 auto`（Codex only）。点击各弹 popover 调整；chips 文案即当前值，无需进设置查看。
- **生成按钮**：Relay 模式下方 caption 显示预估费用（`$0.04 × 4 = $0.16`）。运行中按钮形变为进度态（`完成 2/4 · 12s`）+ 停止。

### 4.2 关键状态（全枚举）

| 状态 | 呈现 |
|---|---|
| Codex 未登录（codex 通道） | Composer 内 inline 卡片：「运行 `codex login` 后重试」+ 重试按钮；生成按钮禁用并显示原因 |
| 中转未配置（relay 通道） | 同上 inline：「填入 API Key」+ 打开设置按钮 |
| 空画廊 | 引导文案 + 2 个示例 prompt（点击填入）——首次打开一眼懂 |
| queued / inFlight | 骨架 shimmer + 已耗时计时（实测 progress 不可靠，不画进度环）|
| 成功 | 缩略图 fade+scale 弹入 |
| 单格失败 | 格内错误人话文案 + **单格重试按钮**（补齐设计文档开放点）|
| 余额不足 / key 无效 | toast + 格内明确文案（不写 "HTTP 403"）|
| 取消 | 格内「已取消」，可重试 |

### 4.3 交互

- 快捷键：`⌘↩` 生成 · `esc` 停止 · `空格` Quick Look · `⌘V` 粘贴参考图
- 画廊：hover 浮起+操作角标 · 双击打开 · **拖出到 Finder/其他 App** · 右键（Finder 显示 / 打开 / **用作参考图** / 复制图片 / 删除文件）
- 「用作参考图」= 一键迭代闭环，是本次最重要的交互补齐
- 参考图：全窗口拖入 + 粘贴 + 点加，多选

### 4.4 动效（全部表达状态，150–250ms，指数缓出）

| 场景 | 动效 |
|---|---|
| 图片完成 | opacity 0→1 + scale 0.96→1，200ms ease-out |
| 骨架等待 | shimmer 微光扫过（唯一循环动画，等待即语义）|
| 网格重排 | items 变化 spring 平滑重排 |
| 生成按钮 | idle↔running 形变 180ms |
| toast | 右上滑入，3s 自动消失 |
| chips popover | 系统默认 |
| 全部 | 遵循 `accessibilityReduceMotion` 降级为直切 |

禁止：装饰性动画、页面加载编排、bounce/elastic。

### 4.5 设置面板（低频项）

- **通道**：Codex（登录状态 + 重新检测）/ 中转（Base URL、API Key、刷新模型列表、余额提示文案）
- **默认**：张数、各通道默认尺寸
- **诊断**：日志（现状保留）

## 5. 文件级改动清单

| 文件 | 动作 |
|---|---|
| `Engine/RelayImageClient.swift` | 新增：submit / poll / download / 错误映射（~180 行）|
| `Support/KeychainStore.swift` | 新增（~40 行）|
| `Support/Preferences.swift` | 新增：UserDefaults 收敛 |
| `Models.swift` | Provider / RelayDraft / RelayAspect / RelayImageSize / RelayModel(含价格) |
| `Engine/GenerationEngine.swift` | generateOne 按 provider 分派 |
| `Features/StudioStore.swift` | provider 状态 + Preferences 接入 + 单格重试 intent + 用作参考图 intent |
| `Features/StudioView.swift` | toolbar 重做（provider 胶囊）+ toast + 设置面板改版 |
| `Features/ComposerView.swift` | 重设计：prompt 主角 + chips/popover + inline 引导 + 费用预估 |
| `Features/GalleryView.swift` | hover / Quick Look / 拖出 / 右键增强 / 动效 / 单格重试 |
| `Support/AppLog.swift` | 环形缓冲 + 变更回调（去 LogView Timer）|

## 6. 测试计划

- `RelayImageClientTests`：payload 形状（含参考图/尺寸映射）、轮询三态解析（in_progress/completed/failed + 同步直返形状）、URL 派生（base→origin）、错误映射（401/403→人话）
- `GenerationEngine` provider 分派单测
- `Preferences` 读写回归
- 现有 Codex 测试保持绿（通道零改动的证据）
- 端到端：真实 key 出图 ≥1 张/模型（已在设计期验证 3 模型 + edit 路径）

## 7. v2.1 追加（已实现）

**Codex 尺寸穷举探测（登录态实测）**：`512x512 / 1536x1536 / 1792x1024 / 1024x1792 / 2048x2048` 全部被后端忽略回落 auto（输出 1254² 正方形）；合法值确认仅 `auto/1024x1024/1536x1024/1024x1536`，与 gpt-image 官方 API 口径一致。注意输出分辨率由模型决定（1:1 实际出 1254²），尺寸值实质是比例语义。

**可靠性**：`server_is_overloaded` 纳入自动退避重试（5s×2^n，cap 60s）；单格重试改为 runId→请求快照字典（会话期），不可重试时 toast 反馈不静默。

**i18n**：String Catalog（源语言 en + zh-Hans 全量翻译，101 key）；设置可选跟随系统/中文/English（AppleLanguages override，重启生效）。错误文案全部人话化且双语。

**UI v2.1**：隐藏系统标题栏（hiddenTitleBar）；分割线全部移除，靠 composer/画廊两档背景色差分区；品牌色换为暗房琥珀（明暗自适应）；通道胶囊移入 composer 顶部；输出目录选择/打开收进设置→通用；prompt 历史（最近 50 条，输入框右下角时钟 popover）；成功图不显文件名（收进 hover tooltip）；所有可点元素统一 hover 高亮 + 手型指针（pointerStyle）。

## 8. 实施顺序

1. Models + KeychainStore + Preferences + RelayImageClient + 单测（协议已验证，先绿）
2. GenerationEngine 分派 + Store 接入
3. 设置面板 + provider 胶囊（此时双通道可端到端出图）
4. Composer / Gallery 重设计 + 动效
5. 端到端验证（两通道各出一批）+ 文档并入 `mac-app-design.md` / README
