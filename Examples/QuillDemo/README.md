# QuillDemo

Interactive demo app for [swift-quill](../..).

Explore library capabilities: pick a scenario, adjust config, see Quill render Markdown in real-time streaming.

## Run

```
cd Examples/QuillDemo
open QuillDemo.xcodeproj
```

Select an iOS Simulator (iPhone, iOS 17+) and press Cmd+R.

## What's here

- **Config screen** — choose scenario, preset, theme, integrations
- **Streaming screen** — see Quill render live, with reset/restart controls and an optional inspector overlay

## Scenarios

- **Quick start** — simple intro content
- **Code walkthrough** — exercises syntax highlighting
- **Long-form article** — sustained streaming test
- **Kitchen sink** — every supported Markdown feature
- **Image-heavy** — exercises ImageLoading

## Dependencies

Uses the parent `swift-quill` package via local path. Edit library source → rebuild demo → changes reflected immediately.

## Scope

This is a reference implementation, not a polished product. For library documentation, see [../../README.md](../../README.md) and the DocC bundle.

## Limitations

- The inspector overlay shows configuration and elapsed time but not per-chunk counts.
