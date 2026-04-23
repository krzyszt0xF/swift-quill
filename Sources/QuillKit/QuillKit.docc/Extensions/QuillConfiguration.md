# ``QuillConfiguration``

Configuration for theme, streaming behavior, and image handling.

## Overview

``QuillConfiguration`` bundles all app-specific settings for a ``QuillView``, ``QuillStreamView``, or ``QuillMarkdownView`` instance. It is a value type; creating per-message configurations is cheap, and Quill does not mutate it after passing it in.

Three subsystems:

- ``theme`` controls visual styling (see <doc:CustomizingTheme>)
- ``streaming`` controls pacing and mode (see <doc:StreamingPresets>)
- ``images`` controls image loading behavior

### Default configuration

``QuillConfiguration/default`` provides reasonable settings for typical AI chat integrations: the default theme, balanced streaming preset, and retry-enabled image loading. Use it as-is, or as a starting point:

```swift
var configuration = QuillConfiguration.default
configuration.theme = .github
```

### Per-message configurations

For apps that want different settings per message type (for example, `.snappy` streaming for short replies, `.longForm` for long answers), create a fresh ``QuillConfiguration`` per message:

```swift
let configuration = QuillConfiguration(
    streaming: .init(preset: preset(for: message)),
    theme: .github
)
```

See <doc:StreamingPresets> for per-message preset selection patterns.

## Topics

### Presets

- ``default``

### Creating a configuration

- ``init(streaming:images:theme:)``

### Components

- ``streaming``
- ``images``
- ``theme``

### Nested types

- ``Streaming``
- ``Images``

## ``init(streaming:images:theme:)``

Creates a configuration with the given component settings.

- Parameter streaming: Streaming behavior settings. Defaults to ``Streaming/default``.
- Parameter images: Image handling settings. Defaults to ``Images/default``.
- Parameter theme: Visual theme. Defaults to ``QuillTheme/default``.

All parameters have defaults; specify only the components you want to customize.

## ``default``

The default configuration: default theme, balanced streaming preset, and retry-enabled image loading.

Suitable for most integrations. To customize, copy and modify:

```swift
var configuration = QuillConfiguration.default
configuration.streaming.preset = .snappy
```

## ``streaming``

Streaming behavior configuration.

See ``QuillConfiguration/Streaming`` for the available settings.

## ``images``

Image handling configuration.

See ``QuillConfiguration/Images`` for the available settings.

## ``theme``

Visual theme.

See ``QuillTheme`` and <doc:CustomizingTheme> for customization.

## ``Streaming``

Streaming subsystem configuration.

### Topics

- ``init(mode:preset:)``
- ``mode``
- ``preset``
- ``default``

## ``Streaming/init(mode:preset:)``

Creates streaming configuration with explicit mode and preset.

- Parameter mode: The streaming mode. Defaults to ``StreamingMode/smoothedTail``.
- Parameter preset: The streaming preset. Defaults to ``QuillStreamingPreset/balanced``.

## ``Streaming/mode``

The streaming mode -- see ``StreamingMode``.

## ``Streaming/preset``

The streaming preset -- see <doc:StreamingPresets> for the available presets and their use cases.

## ``Streaming/default``

The default streaming configuration: `.smoothedTail` mode with `.balanced` preset.

## ``Images``

Image loading subsystem configuration.

### Topics

- ``init(retryEnabled:)``
- ``retryEnabled``
- ``default``

## ``Images/init(retryEnabled:)``

Creates image configuration.

- Parameter retryEnabled: Whether failed image loads should retry automatically. Defaults to `true`.

## ``Images/retryEnabled``

Whether failed image loads retry. When `true`, transient network failures trigger automatic retries up to an internal limit.

## ``Images/default``

The default image configuration: retry-enabled.
