# Security Policy

## Supported versions

The latest release on `main` receives security fixes.

## Reporting a vulnerability

Report privately via [GitHub Security Advisories](https://github.com/Suge8/Image-Studio/security/advisories/new). Do not open a public issue for security problems. You can expect an initial response within a week.

## Scope notes

What the app touches, so you know what matters:

- **Codex credentials**: the app reads `~/.codex/auth.json` (created by `codex login`) and refreshes tokens against `auth.openai.com`. It writes refreshed tokens back to that file and nowhere else.
- **Relay API keys**: stored in the macOS Keychain (`kSecClassGenericPassword`), never in UserDefaults, logs, or source.
- **Network**: requests go only to the ChatGPT backend, the user-configured relay base URL, and image CDN URLs returned by the relay.
- **No telemetry**: the app collects nothing and phones home to no one. Logs stay local in `~/Library/Logs/Image Studio/`.

Reports about key leakage, credential handling, or unexpected network destinations are especially welcome.
