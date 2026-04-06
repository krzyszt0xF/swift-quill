/// Product-facing image presentation options.
public struct ImageOptions: Sendable {
    public var appearance: ImageAppearance
    public var retryEnabled: Bool

    public init(
        appearance: ImageAppearance = .default,
        retryEnabled: Bool = true
    ) {
        self.appearance = appearance
        self.retryEnabled = retryEnabled
    }
}

extension ImageOptions {
    public static let `default`: Self = .init()
}
