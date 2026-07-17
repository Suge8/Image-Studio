# Image Studio — 设计系统

> UI 设计唯一事实源。改 UI 前读这里；改完与这里对齐。
> 设计方法：impeccable product register（工具应消失在任务里，earned familiarity）。

## 1. 定位与策略

- **配色策略**：Restrained——中性系统色 + 单一品牌强调色，图片内容才是画面主角。
- **场景**：Mac 用户在桌面专注出图/改图；UI 低调衬托彩色图片。
- **锚点参照**：Raycast（紧凑控件 + popover 收纳）、macOS 照片（画廊交互）、Linear（状态语义与克制动效）。

## 2. 颜色

| Token | 值 | 用途 |
|---|---|---|
| `Color.brand` | 珊瑚：dark `#F5856B` · light `#D9614D` | 单色场合：图标 tint、pin、选中框 |
| `LinearGradient.brand` | 柔和多彩：珊瑚→玫瑰→紫罗兰→天青（中饱和，Apple Intelligence 风） | 主 CTA（生成按钮）、focus ring；小元素禁用渐变防花 |
| 窗口底 | 系统 `.background` | 全窗统一底色（分区靠间距与留白，不用色差不用分割线） |
| 控件底 | `.quaternary.opacity(0.45)` | chips、胶囊、缩略图占位 |

规则：**无分割线、无色块分区**；跟随系统明暗，不自造主题开关。

## 3. 排版

系统字体（SF Pro），固定字阶：

| 用途 | 字号 |
|---|---|
| 标题（设置/日志面板） | `.title2.weight(.semibold)` |
| 正文 / prompt | `.body` |
| 控件文字（chips、胶囊） | `.callout` |
| 辅助说明 | `.caption` / `.caption2` + `.secondary`/`.tertiary` |
| 数字（计数、耗时） | `.monospacedDigit()` + `.contentTransition(.numericText())` |

## 4. 布局

```
┌ 窗口（hiddenTitleBar，红绿灯浮层）─────────────┐
│ Composer 340pt 定宽        │ Gallery 自适应     │
│  通道胶囊（顶部，留 40pt）  │  纯图网格，无标题行 │
│  Prompt（主角，focus 光晕） │  自适应列 150–240   │
│  参考图条 56pt             │                    │
│  参数 chips 一行           │                    │
│  生成按钮 + 费用           │                    │
│  ⚙ 设置（左下角）          │                    │
└───────────────────────────┴────────────────────┘
```

- 圆角：卡片/输入框 12，chips/小件 9–10
- 间距：区块 14–16，条目 8，紧凑 2–6
- 低频功能一律收 popover（参数）或设置面板（目录、语言、通道配置）

## 5. 组件词汇（全 App 统一，不发明第二种）

| 组件 | 形态 | 出现位置 |
|---|---|---|
| Chip | 胶囊 icon+label（或 icon-only），点击弹 popover | 参考图 / 张数 / 尺寸 / 画质 / 收藏 |
| 通道胶囊 | 圆角矩形，brand 图标 + 通道·模型 + chevron | Composer 顶部 |
| Popover | 系统 popover，内容 padding 14 | 一切参数调整、历史、收藏 |
| Toast | 顶部胶囊材质浮层，3s 自动消失，点击关闭 | 瞬态反馈 |
| Blocked card | 橙色 8% 底 + 图标 + 一句话 + 行动按钮 | 未登录 / 未配 key |
| 骨架 | GenerativeShimmer：品牌渐变呼吸 + 流光扫过 + 已耗时计时 | 生成中槽位 |
| 空状态 | 图标 + 引导句 + 可点样例 prompt | 空画廊 |

## 6. 动效（150–250ms，指数缓出，只表达状态）

| 场景 | 规格 |
|---|---|
| 图片完成弹入 | opacity 0→1 + scale 0.96→1，200ms ease-out |
| 骨架等待 | 品牌渐变呼吸 2.2s + 流光 1.8s 循环（唯一循环动画，等待即语义） |
| 网格重排 | spring 300ms（value: items.map(\.id)） |
| hover | 背景 `.primary.opacity(0.08)` / 卡片 scale 1.02 + 阴影，120–150ms |
| toast | 顶部滑入+淡入，spring 300ms |
| focus ring | 边框色/宽过渡 150ms |
| 全部 | 遵循 `accessibilityReduceMotion` 降级为直切 |

禁止：装饰动画、页面加载编排、bounce/elastic、进度环造假（上游 progress 不可靠，用已耗时计时）。

## 7. 交互规范

- 一切可点元素：`hoverHighlight()`（hover 高亮）+ `.pointerStyle(.link)`（手型）
- 快捷键：`⌘↩` 生成 · `esc` 停止 · `空格` Quick Look · `⇧⌘V` 粘贴参考图 · `⇧⌘L` 日志
- 画廊：单击选中、双击打开、拖出到 Finder、右键完整菜单（含"用作参考图"迭代闭环）
- 错误：人话 + 双语，可行动（失败格带重试按钮）；**任何交互不静默失败**，最少给 toast

## 8. 文案

- String Catalog（`ImageStudio/Localizable.xcstrings`）：源语言 en，zh-Hans 全量翻译；新 UI 字符串必须同步补双语
- 错误文案说人话并给出路（"上游服务过载，请稍后重试"），原始错误进日志不进 UI

## 9. 按钮语言

- 主 CTA：胶囊渐变按钮（`BrandProminentButtonStyle`），`arrow.up` 图标，自适应宽度水平居中
- 次级操作一律 **icon-only + `.help` tooltip**（设置、日志、停止、参考图入口、收藏）
- 停止：icon-only 圆钮（`stop.fill`），仅生成中出现在主按钮右侧，spring 弹入

## 10. 品牌资产

| 资产 | 位置 | 用途 |
|---|---|---|
| Logo 定稿（层叠画布，扁平） | `design/promo/visual/logo-final-flat.png` | 品牌标志源文件 |
| App 图标 | `ImageStudio/Assets.xcassets/AppIcon.appiconset`（源 `design/promo/visual/app-icon-1024.png`） | Dock / Finder |
| 吉祥物系列（软胶 3D，珊瑚→紫 + 炭黑） | `design/promo/visual/asset-3d-{hero,waving,painting,sleeping,frame}.png` | 空状态、设置彩蛋、宣传物料 |
| 应用内资产 | `Assets.xcassets/MascotSleeping`（空画廊）、`MascotHero`（设置底部） | 透明底 480px |
| Promo 成品 | `design/promo/shots/`：`social-github-1280x640.png`（GitHub social preview）、`hero-readme-{en,zh}.png`（双语 README 头图）、`demo-generate.gif`（生成流程演示） | 对外 |

吉祥物使用纪律：只出现在空状态、设置彩蛋与对外物料；不进高频操作路径，不做装饰性堆叠。
