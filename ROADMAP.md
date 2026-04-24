# Roadmap

Quill is focused on one product story: fast, native Markdown rendering for streaming iOS interfaces with a small public API.

This roadmap is directional. It does not promise dates or version numbers.

## Near-Term Direction

| Area | Direction |
|------|-----------|
| SwiftUI ergonomics | Keep reducing integration ceremony while preserving a small API surface. |
| Documentation | Expand runnable examples, performance methodology, and migration notes as the API stabilizes. |
| Streaming performance | Continue protecting tail-only updates, frozen-prefix reuse, cancellation behavior, and low visible-layer churn. |
| Accessibility | Run a dedicated VoiceOver audit and document any app-facing customization hooks that prove necessary. |
| Images | Keep image loading optional while improving retry, placeholder, and sizing behavior where needed. |
| Content polish | Improve edge cases in tables, code blocks, lists, links, and selection without turning Quill into a plugin platform. |

## Product Boundaries

Quill is not planned to become a Markdown editor, WebKit wrapper, cross-platform renderer, or custom block plugin system. The priority is a polished iOS SDK for streaming Markdown display.
