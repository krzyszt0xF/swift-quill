import Foundation

/// Product-facing configuration shared by UIKit and SwiftUI Quill surfaces.
public struct QuillConfiguration {
    public var images: Images
    public var streaming: Streaming
    public var theme: QuillTheme
    private var customRenderConfiguration: RenderConfiguration?

    public init(
        streaming: Streaming = .default,
        images: Images = .default,
        theme: QuillTheme = .default
    ) {
        self.images = images
        self.streaming = streaming
        self.theme = theme
        customRenderConfiguration = nil
    }

    package init(
        streaming: Streaming = .default,
        images: Images = .default,
        theme: QuillTheme = .default,
        renderConfiguration: RenderConfiguration
    ) {
        self.images = images
        self.streaming = streaming
        self.theme = theme
        customRenderConfiguration = renderConfiguration
    }
}

extension QuillConfiguration {
    var renderConfiguration: RenderConfiguration {
        if let customRenderConfiguration {
            return customRenderConfiguration
        }

        var renderConfiguration = RenderConfiguration(preset: streaming.preset)
        renderConfiguration.streamingMode = streaming.mode
        return renderConfiguration
    }
}

public extension QuillConfiguration {
    static var `default`: Self {
        Self()
    }

    struct Images {
        public var retryEnabled: Bool

        public init(retryEnabled: Bool = true) {
            self.retryEnabled = retryEnabled
        }
    }

    struct Streaming {
        public var mode: StreamingMode
        public var preset: QuillStreamingPreset

        public init(
            mode: StreamingMode = .smoothedTail,
            preset: QuillStreamingPreset = .balanced
        ) {
            self.mode = mode
            self.preset = preset
        }
    }
}

public extension QuillConfiguration.Images {
    static var `default`: Self {
        Self()
    }
}

public extension QuillConfiguration.Streaming {
    static var `default`: Self {
        Self()
    }
}
