# Changelog

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [SemVer](https://semver.org/).

## [Unreleased]

## [0.3.0] - 2026-07-18

### Added

- Concurrent batches: keep submitting new prompts while earlier batches are still generating; per-batch stop semantics
- ⌘V pastes clipboard images straight into references
- Brand identity: layered-canvas logo, macOS app icon, clay mascot set (empty state, settings shelf, promo art)
- Author credit and GitHub link in Settings
- CI on GitHub Actions (build + unit tests on macos-26)

### Changed

- Full visual polish: multicolor brand gradient (CTA, focus ring, generating shimmer), hidden title bar, divider-free layout, icon-only secondary actions, redesigned settings and composer
- Relay base URL no longer pre-fills any vendor; empty until configured
- App marketing version aligned with release tags (0.3.0)

## [0.2.0] - 2026-07-17

### Added

- Third-party relay channel: OpenAI-Images-compatible relays with API key (Keychain), async task polling, sync-relay fallback, model list with per-image pricing and cost estimate
- Prompt favorites with pin/delete and a built-in logo-board template; automatic prompt history (last 50)
- Localization: English and Simplified Chinese via String Catalog, language switch in Settings
- Gallery interactions: Quick Look, drag out, double-click open, "Use as Reference", per-slot retry
- Paste reference images (⇧⌘V), sample prompts in the empty state

### Changed

- Full UI redesign: hidden title bar, divider-free layout with surface tiers, amber brand color, parameter chips with popovers, unified hover/pointer feedback
- Codex size options reduced to the four values the endpoint honors (auto, 1:1, 3:2, 2:3); larger sizes route to the relay channel
- Error messages localized and human-readable; `server_is_overloaded` now retries with backoff

### Fixed

- "2K" size options silently ignored by the Codex backend (removed the fake choices)
- Retry button dead on failed slots from earlier batches

## [0.1.0] - 2026-07-17

Initial release: Codex-channel image generation with unlimited parallelism, folder-as-history gallery, reference images, and output naming.
