# Contributing to Quill

Contributions to Quill are welcome. The library is small and the quality bar is high. This document explains how to contribute effectively without wasting your time or ours.

## Ways to contribute

- Report bugs with clear reproduction steps.
- Propose features by opening an issue *before* writing code.
- Fix open bugs or implement features from the issue tracker.
- Improve documentation — DocC articles, README, inline doc comments.
- Add or improve example integrations in `Examples/`.
- Run performance benchmarks on devices not yet covered in [Docs/Performance.md](Docs/Performance.md).

## Before you start

**Bug reports:** Search existing issues first. A good bug report includes:

- Minimal reproduction steps (a short code snippet is ideal).
- Device model and iOS version.
- Quill version (git SHA or tag).
- Whether the issue occurs in static rendering, streaming, or both.
- A screenshot or screen recording if the bug is visual.

**Feature proposals:** Open an issue before writing code. Quill has explicit [Non-Goals](README.md#non-goals) — getting scope alignment first prevents wasted work. Explain the use case, not just the desired API shape.

**Documentation fixes:** No discussion needed. Open a PR directly.

## Development setup

```
git clone https://github.com/krzyszt0xF/swift-quill.git
cd swift-quill
open Package.swift
```

Build the package:

```
swift build
```

Run tests:

```
swift test
```

Run tests for a specific target:

```
swift test --filter QuillCoreTests
```

Run the example app:

```
open Examples/BasicIntegration/BasicIntegration.xcodeproj
```

The project includes a [SwiftLint](.swiftlint.yml) configuration. If you have SwiftLint installed, run it before opening a PR:

```
swiftlint
```

## Project structure

```
Sources/
├── QuillCore/         — Internal parsing and streaming primitives
├── QuillKit/          — Public UIKit renderer (QuillView) and product API
├── QuillSwiftUI/      — SwiftUI wrappers (QuillStreamView, QuillMarkdownView)
├── QuillHighlight/    — Optional syntax highlighter (HighlighterSwift wrapper)
└── QuillImageLoader/  — Optional remote image loader (URLSession)
Tests/                 — Unit and integration tests per target
Examples/              — Runnable integration examples
Docs/                  — Performance methodology, assets, internal research
```

Dependency direction: `QuillCore` is the internal foundation. `QuillKit` depends on `QuillCore`. `QuillSwiftUI` depends on `QuillKit`. `QuillHighlight` and `QuillImageLoader` depend on `QuillKit` and are optional leaf targets. Do not introduce cross-dependencies between leaf targets or reverse the direction.

## Making changes

### Branching

Fork the repo and create a branch from `main`:

- Bug fixes: `fix/short-description`
- Features: `feature/short-description`

Do not commit directly to `main`. Keep branches short-lived and focused on a single change.

### Commits

- One logical change per commit.
- Imperative mood in commit messages ("Add X", not "Added X" or "Adds X").
- Reference issue numbers when applicable (`Fixes #42`).
- Do not squash before review — squashing happens on merge if needed.

### Code style

- Swift 6 strict concurrency mode. All public APIs must be `Sendable`-conformant.
- Follow existing patterns in the codebase. If unsure, open a draft PR and ask.
- No force-unwraps (`!`) in non-test code.
- No force-casts or force-tries — these are errors in the SwiftLint config.
- Public types require a one-line doc comment (`///`). No doc comments on enum cases, properties, methods, or inits.
- See [.swiftlint.yml](.swiftlint.yml) for the full lint configuration.

## Testing

- All new code paths must have tests.
- Use [swift-testing](https://developer.apple.com/documentation/testing) (`@Suite`, `@Test`, `#expect`) for new tests. Do not use XCTest for new test files.
- Tests are organized per target: `QuillCoreTests`, `QuillKitTests`, `QuillSwiftUITests`, `QuillHighlightTests`. Put your tests in the matching target.
- Streaming behavior tests: use the existing test helpers in `Tests/` — do not invent new chunking strategies.
- Test fixtures live in `Tests/<Target>/Fixtures/`. Add new fixtures there if your test needs Markdown input files.
- If your change touches the hot path (parse, reduce, render, height measurement), run the benchmarks described in [Docs/Performance.md](Docs/Performance.md) and include numbers in your PR description.
- If your change alters rendering output, verify visually in the example app before submitting.

## Pull request process

1. Ensure your branch builds and all tests pass locally.
2. Run `swiftlint` and fix any violations.
3. Update [CHANGELOG.md](CHANGELOG.md) under an `## Unreleased` section (create it if missing), following the existing format.
4. Open a PR against `main`, fill out the PR template, and link the related issue.
5. Automated checks must pass.
6. At least one maintainer approval is required.
7. The maintainer merges using "Squash and merge" by default.

Review latency is best-effort — this is a small project maintained in limited time. If your PR sits without feedback for a while, a polite ping in the PR thread is fine.

## What we won't merge

- Changes that violate the [Non-Goals](README.md#non-goals) listed in README.md: no Markdown editing, no WebKit fallback, no custom block plugin system, no LaTeX, no macOS/tvOS/watchOS in v1.x.
- Refactors without a stated user-facing benefit.
- Dependency additions without prior discussion.
- "Cleanup" PRs that rename things for personal preference.
- Breaking API changes without a migration path.
- Performance regressions on the streaming hot path without strong justification.
- Large-scale reformatting or whitespace-only diffs mixed with functional changes.
- Test-only PRs that add mocks for internals instead of testing through the public API.

## Getting help

- [GitHub Discussions](https://github.com/krzyszt0xF/swift-quill/discussions) for questions and ideas.
- [GitHub Issues](https://github.com/krzyszt0xF/swift-quill/issues) for bugs and feature proposals with concrete scope.

There is no Slack, Discord, or email channel. All communication happens on GitHub.

## License

By contributing to Quill, you agree that your contributions will be licensed under the [MIT License](LICENSE).
