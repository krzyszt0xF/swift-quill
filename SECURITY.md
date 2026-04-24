# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 1.0.x   | Yes (after 1.0.0 release) |
| < 1.0   | Pre-release — use latest `main` |

After 1.0, the latest minor version receives security fixes. Older minor versions are not backported unless explicitly stated in the release notes.

## Reporting a vulnerability

Report vulnerabilities through [GitHub's private vulnerability reporting](https://github.com/krzyszt0xF/swift-quill/security/advisories/new). This keeps the report confidential until a fix is ready.

**Do not** open a public issue, post to Discussions, or contact the maintainer via social media.

A good report includes:

- A description of the vulnerability.
- Steps to reproduce (a failing test case or minimal Swift project is ideal).
- The version of Quill affected (git SHA or tag).
- iOS version and device model.
- Any suggested mitigation.

**Response expectations:**

- Acknowledgement within 7 days (best-effort — this is a single-maintainer project).
- Initial assessment within 14 days.
- Critical issues are prioritized. Low-severity issues may roll into the next scheduled release.

## Disclosure policy

Quill follows coordinated disclosure:

- Public disclosure happens after a fix is released, typically within 90 days of the initial report or sooner if the fix lands early.
- Reporters are credited in the security advisory and CHANGELOG unless they request anonymity.
- Quill will request CVE assignment for confirmed vulnerabilities that meet MITRE's threshold.

## Scope

**In scope:**

- Memory safety issues in parsing or rendering (crashes, out-of-bounds reads, retain cycles triggered by untrusted input).
- Infinite loops or exponential behavior on crafted Markdown input (denial of service).
- Issues in `QuillImageLoader` that enable data exfiltration via image URLs.
- Issues in `QuillHighlight` that enable code execution through highlighter payloads.

**Out of scope:**

- Rendering that is unexpected but not unsafe (e.g., ugly styling on edge-case Markdown) — file a regular bug report.
- Issues in user-supplied `ImageLoading` or `SyntaxHighlighting` implementations — those are the consumer's responsibility.
- Issues in transitive dependencies (HighlighterSwift, swift-markdown) — report upstream, but a note to Quill is appreciated so we can track it.

## Security best practices for consumers

- Treat streamed Markdown as untrusted input. Never relay raw chunks from one user to another user's view without moderation.
- Links are not validated by Quill. Your `onLinkTap` handler is the security boundary — validate URL schemes and block `javascript:` or `data:` if unexpected.
- Image loading fetches arbitrary URLs. If your app has privacy requirements, supply a custom `ImageLoading` implementation that restricts allowed hosts.
- Large Markdown documents consume memory proportionally. Apply a length cap before passing content to Quill in adversarial contexts (e.g., user-generated content).
- Syntax highlighting processes code as text only — it does not execute code. However, malformed configurations in custom `SyntaxHighlighting` implementations are your responsibility to validate.
