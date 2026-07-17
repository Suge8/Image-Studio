# Image Studio

English | [简体中文](README.zh-CN.md)

Native macOS studio for AI image generation. Write a prompt, drop in reference images, generate a batch in parallel. Results land in a folder you pick, and that folder is the history.

![Image Studio](design/promo/shots/hero-readme.png)

![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange)
![License](https://img.shields.io/badge/license-Apache--2.0-green)

## Why

Most image tools make you choose between a browser tab and a subscription app. Image Studio is a 2.4 MB native app with zero third-party dependencies that talks to backends you already have:

- **Codex channel**: reuses your local `codex login` session (ChatGPT subscription). No extra key, no extra cost.
- **Relay channel**: bring an API key for any OpenAI-Images-compatible relay. Tested against [right.codes](https://www.right.codes) with `gpt-image-2` and the `nano-banana` family; sync and async (task-polling) relays both work.

## Features

- Unlimited parallel generation: one request per image, each slot retries independently
- Folder-as-history gallery: Quick Look with Space, drag out to Finder, right-click "Use as Reference" to iterate
- Prompt favorites with a built-in logo-board template, plus automatic prompt history
- Reference images (up to 16) via drag, paste (⇧⌘V), or file picker
- Per-channel size options that match what each backend honors (verified against live endpoints, no fake choices)
- Relay model list with per-image pricing and cost estimate before you generate
- English and Simplified Chinese UI

## Install

Build from source (requires macOS 15+ and Xcode 16+):

```bash
git clone git@github.com:Suge8/Image-Studio.git
cd Image-Studio
make install    # builds Release and installs to ~/Applications
make run
```

## Setup

Pick one channel, or configure both and switch from the capsule at the top left:

**Codex**: run `codex login` in Terminal once (choose ChatGPT). The app reads `~/.codex/auth.json` and never writes your credentials anywhere else.

**Relay**: open Settings → Third-party Relay, fill in the base URL and API key, then click "Save & Verify". The model list and prices load from the relay. Keys are stored in the macOS Keychain.

## Usage

1. Write a prompt or pick a favorite (star chip)
2. Adjust count / size / quality from the parameter chips
3. Press ⌘↩. Slots stream into the gallery as they finish
4. Iterate: right-click any result → "Use as Reference"

Size semantics differ by backend. The Codex endpoint honors four values only (auto, 1:1, 3:2, 2:3); the relay accepts aspect ratios (exact) with a 1K/2K/4K tier (approximate, model-dependent). The UI shows only what each backend accepts.

## Development

```bash
make test       # unit tests
make build      # Release build → build/
make package    # zip → dist/
```

Docs live in [`docs/`](docs/): product scope, architecture, and the design system. Start with [`AGENTS.md`](AGENTS.md) for a map.

## Contributing

See [CONTRIBUTING.md](.github/CONTRIBUTING.md). Security reports: [SECURITY.md](.github/SECURITY.md).

## License

[Apache-2.0](LICENSE)
