# Image Studio — Agent 导览

macOS 15+ 原生图片工作室 App（Swift 6 / SwiftUI）。双通道：Codex（复用本机 `codex login`，Responses + `image_generation` tool）/ 第三方中转（API Key，异步任务轮询）；输出目录即历史。

## 目录

| 路径 | 内容 |
|---|---|
| `ImageStudio/` | App 源码：`Engine/` 网络与生成，`Features/` UI+Store，`Support/` 工具 |
| `ImageStudioTests/` | 单元测试 |
| `ImageStudio.xcodeproj/` | Xcode 工程 |
| `scripts/` | 构建 / 测试 / 安装 / 打包 |
| `site/` | 官网源（SvelteKit + Svelte 5，双语；`npm run build`，部署到 Vercel，root 选 `site/`） |
| `CONTEXT.md` | 领域术语表（活文档，冲突时随手修订） |
| `docs/mac-app-design.md` | 架构设计事实源（v1 + v2 附记） |
| `docs/v2-design.md` | 双通道架构与实测事实源 |
| `docs/DESIGN.md` | UI 设计系统事实源 |
| `docs/PRODUCT.md` | 产品边界（三行版） |
| `.github/` | CONTRIBUTING / SECURITY（英文社区件） |

## 常用命令

```bash
make test       # 单元测试
make build      # Release → build/
make install    # 装到 ~/Applications/Image Studio.app
make package    # zip → dist/Image-Studio-macOS.zip
make run        # 打开已安装 App
make clean
```

等价脚本：`scripts/build.sh`、`test.sh`、`install.sh`、`package.sh`、`run.sh`。

## 约束（短）

- 零第三方依赖；无旧系统兼容枝（15+ only）
- 不重做 OAuth；Codex 鉴权只读 `~/.codex`；中转 key 存 Keychain
- 一路请求 1 张图；多图 = 并行多路（两通道同）
- Codex 尺寸只认 auto/1024²/1536×1024/1024×1536，非法值被后端静默忽略（实测）
- 参考图上限 16；目录即历史，不建 DB
- 双通道设计事实源：`docs/v2-design.md`

## 文档

- 产品：`docs/PRODUCT.md`；术语：`CONTEXT.md`
- 架构：`docs/mac-app-design.md` + `docs/v2-design.md`；UI：`docs/DESIGN.md`
- 用户向：`README.md`（英）/ `README.zh-CN.md`（中）；变更：`CHANGELOG.md`
- UI 字符串双语：`ImageStudio/Localizable.xcstrings`（en 源 + zh-Hans）
