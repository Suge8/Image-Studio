<div align="center">

<img src="design/promo/shots/logo-256.png" width="120" alt="Image Studio 图标">

# Image Studio

**一句提示词，一批好图 — 轻量 mac 原生 AI 绘图工作室。**

[![CI](https://github.com/Suge8/Image-Studio/actions/workflows/ci.yml/badge.svg)](https://github.com/Suge8/Image-Studio/actions/workflows/ci.yml)
![Platform](https://img.shields.io/badge/macOS-15%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange)
![License](https://img.shields.io/badge/license-Apache--2.0-green)

[English](README.md) | 简体中文

<img src="design/promo/shots/hero-readme-zh.png" alt="Image Studio 截图">

</div>

## ✨ 为什么好用

- **用现成的，零成本** — 复用本机 `codex login`（ChatGPT 订阅），不用额外买 key。
- **也可以带 key** — 兼容任何 OpenAI-Images 格式的中转：`gpt-image`、`nano-banana` 系列，生成前先看到每张单价。
- **真·原生** — 2.4 MB 的 SwiftUI 应用，零第三方依赖，不是 Electron，不是浏览器标签页。
- **天生并行** — 每张图独立请求；上一批还在跑，下一批照发不误。
- **文件夹即历史** — 结果落在你选的目录里。快速预览、拖进 Finder，没有数据库，没有绑架。
- **诚实的选项** — 只显示后端真正支持的尺寸（实测验证），没有安慰剂下拉框。

## 🚀 三步上手

**1 · 安装**（macOS 15+，Xcode 16+）

```bash
git clone https://github.com/Suge8/Image-Studio.git && cd Image-Studio
make install && make run
```

**2 · 接一个通道** — 任选其一，左上角胶囊随时切换：

| 通道 | 配置 |
|---|---|
| **Codex** | 终端跑一次 `codex login`（选 ChatGPT），完事。 |
| **中转** | 设置 → 第三方中转 → 填 Base URL 和 API Key → 保存并检查。Key 存 macOS 钥匙串。 |

**3 · 生成**

<div align="center"><img src="design/promo/shots/demo-generate.gif" alt="生成演示"></div>

写一句提示词，按 **⌘↩**，图片完成一张进一张画廊。

## 🎛️ 顺手技巧

| | |
|---|---|
| 基于结果迭代 | 右键 → **用作参考图** |
| 参考图 | 拖入、粘贴（**⌘V**）或点击虚线框 — 最多 16 张 |
| 复用提示词 | ★ 收藏（内置 Logo 提案板模板），时钟图标看历史 |
| 预览 | 选中图片按 **空格** 快速预览 |
| 单张失败 | 悬停 → 只重试那一张 |

## 🛠️ 开发

```bash
make test       # 单元测试
make package    # Release 打包 → dist/
```

架构与设计文档在 [`docs/`](docs/)，从 [`AGENTS.md`](AGENTS.md) 开始。欢迎贡献 — [CONTRIBUTING.md](.github/CONTRIBUTING.md) · [SECURITY.md](.github/SECURITY.md) · [Apache-2.0](LICENSE)
