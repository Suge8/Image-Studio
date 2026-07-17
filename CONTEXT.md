# Image Studio 术语表

本项目上下文里每个词的准确含义。发现用法与本表冲突或遇到未收录的高频术语，与用户确认后随手修订，不必专门立项（活文档）。

## 生成

**通道（Provider）**:
生成图片走的后端路线，二选一：`codex` 或 `relay`。提交时锚定为 `ProviderSelection` 快照，不回读可变设置。
_Avoid_: backend、后端（指代通道时）、渠道

**Codex 通道**:
复用本机 `codex login` 登录态（`~/.codex/auth.json`），经 ChatGPT Responses API + `image_generation` tool 出图。App 只读该目录，不重做 OAuth。
_Avoid_: 官方通道、原生登录

**中转（Relay）**:
第三方 OpenAI Images 兼容服务（如 right.codes），API Key 鉴权，异步任务模式：提交拿 `task_id`，轮询取结果，再下载 CDN 图。
_Avoid_: 代理、proxy、镜像

**宿主模型（host model）**:
Codex 通道里承载 `image_generation` tool 的 Responses 模型名（如 `gpt-5.6-sol`），不是底层 gpt-image 模型名。
_Avoid_: 模型（单独使用时须区分宿主模型与中转模型）

**批次（run）**:
一次提交产生的 N 路并行请求，共享一个 `runId` 与文件名时间戳前缀。会话期内每个批次的请求快照保留在 `runRequests`，供单格重试。
_Avoid_: 任务组、批量

**槽位（slot）**:
批次内的单张图请求，独立生命周期（queued → inFlight → succeeded/failed）、独立重试。一路请求只出一张图。
_Avoid_: 子任务

## 界面

**画廊（Gallery）**:
右侧网格，渲染"进行中槽位 + 输出目录已有图片"的统一列表。目录即历史：不建数据库，文件系统是唯一持久化。
_Avoid_: 历史记录页、相册

**参考图（reference）**:
随 prompt 上传的输入图（≤16 张），有参考图即 edit 语义，无则 generate，用户不选模式。
_Avoid_: 垫图、底图

**Chip**:
Composer 里的胶囊参数按钮（张数/尺寸/画质/收藏），点击弹 popover 调整。
_Avoid_: 标签、tag

**收藏提示词（favorite prompt）**:
用户保存的可复用 prompt，支持置顶/删除；内置"Logo 画板"模板 seed 一次，删除不复活。
_Avoid_: 预设、模板（内置项除外）

**提示词历史（prompt history）**:
最近 50 条提交过的 prompt，自动去重记录，时钟按钮弹出。与收藏互不混用：历史是自动的，收藏是主动的。

## 存储

**目录即历史**:
输出目录中的图片文件直接渲染为画廊历史，文件系统是唯一事实源。禁止为历史建 DB、索引或第二套存储。

**Preferences**:
UserDefaults 的唯一入口（`Support/Preferences.swift`）。散写 UserDefaults 视为违规。

**KeychainStore**:
中转 API Key 的唯一存放处。Key 不得进 UserDefaults、日志或源码。
