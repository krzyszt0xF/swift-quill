import QuillKit
import SwiftUI

private struct ImageLoaderKey: EnvironmentKey {
    static let defaultValue: (any ImageLoading)? = nil
}

extension EnvironmentValues {
    var quillImageLoader: (any ImageLoading)? {
        get { self[ImageLoaderKey.self] }
        set { self[ImageLoaderKey.self] = newValue }
    }
}

public extension View {
    func quillImageLoader(_ imageLoader: (any ImageLoading)?) -> some View {
        environment(\.quillImageLoader, imageLoader)
    }
}
