<div align="center">

<img src="design/promo/shots/logo-256.png" width="120" alt="Image Studio icon">

# Image Studio

A small native Mac app that turns a prompt into a batch of images.

[![CI](https://github.com/Suge8/Image-Studio/actions/workflows/ci.yml/badge.svg)](https://github.com/Suge8/Image-Studio/actions/workflows/ci.yml)
![Platform](https://img.shields.io/badge/macOS-15%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange)
![License](https://img.shields.io/badge/license-Apache--2.0-green)

English | [简体中文](README.zh-CN.md) | [Website](https://image-studio-orpin.vercel.app)

<img src="design/promo/shots/hero-readme-en.png" alt="Image Studio screenshot">

</div>

## What you get

- Free with your ChatGPT subscription. The app reuses your local `codex login`, so there is nothing new to buy.
- Works with any OpenAI-Images-compatible relay too. Bring your own key and see the per-image price before you generate. Tested with `gpt-image` and the `nano-banana` family.
- 2.4 MB of SwiftUI, zero third-party dependencies.
- Each image is its own request. Submit the next batch while the previous one is still running.
- Results land in a folder you choose, and that folder is the history. Quick Look, drag to Finder, no database.
- Size options match what each backend actually accepts. We verified against live endpoints and removed the ones that silently fall back.

## Install

Requires macOS 15+ and Xcode 16+.

```bash
git clone https://github.com/Suge8/Image-Studio.git && cd Image-Studio
make install && make run
```

## Connect a channel

Pick one or both. Switch anytime from the capsule at the top left.

| Channel | Setup |
|---|---|
| **Codex** | Run `codex login` once in Terminal and choose ChatGPT. |
| **Relay** | Settings → Third-party Relay → base URL and API key → *Save & Verify*. Keys go to the macOS Keychain. |

## Generate

<div align="center"><img src="design/promo/shots/demo-generate.gif" alt="Generation demo"></div>

Type a prompt, press **⌘↩**. Finished images drop into the gallery one by one.

## Tips

| | |
|---|---|
| Iterate on a result | Right-click → **Use as Reference** |
| Add reference images | Drag, paste (**⌘V**), or click the dropzone, up to 16 |
| Reuse a prompt | ★ favorites (a logo-board template ships built in), clock icon for history |
| Preview | Select an image, press **Space** |
| One slot failed | Hover it and retry only that one |

## Development

```bash
make test       # unit tests
make package    # Release zip → dist/
```

Architecture and design docs live in [`docs/`](docs/). Start at [`AGENTS.md`](AGENTS.md). Contributions welcome: [CONTRIBUTING.md](.github/CONTRIBUTING.md) · [SECURITY.md](.github/SECURITY.md) · [Apache-2.0](LICENSE)
