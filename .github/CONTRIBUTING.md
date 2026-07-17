# Contributing to Image Studio

Thanks for helping out. This project values small, verified changes over large speculative ones.

## Setup

- macOS 15+ and Xcode 16+
- `git clone`, then `make test` to confirm a green baseline

## Ground rules

1. **Zero third-party dependencies.** System frameworks only. A PR that adds a package needs a written case for why the standard library cannot do the job.
2. **Tests must pass.** Run `make test` before pushing. New behavior needs coverage; UI changes need at least a manual verification note in the PR.
3. **Docs are the source of truth.** If your change touches product scope, architecture, or UI, update the matching file: `docs/PRODUCT.md`, `docs/mac-app-design.md` / `docs/v2-design.md`, or `docs/DESIGN.md`. `CONTEXT.md` defines the vocabulary; use its terms in code and docs.
4. **Both UI languages.** Every user-facing string goes through the String Catalog (`ImageStudio/Localizable.xcstrings`) with an English key and a zh-Hans translation.
5. **No history database.** The output folder is the history. Do not add persistence layers for gallery state.
6. **Honest errors.** No silent fallbacks, no fake success states. Failed slots show a human-readable, localized message and a retry path.

## Workflow

1. Fork and branch from `main`
2. Keep each PR to one concern; match the existing code style
3. `make test` green, then open a PR describing what changed and how you verified it

## Commands

```bash
make test       # unit tests
make build      # Release build
make install    # install to ~/Applications
make package    # distributable zip
```
