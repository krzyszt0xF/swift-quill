import Foundation
import QuillKit
import UIKit

/// Default image loader using URLSession.
public struct ImageLoader: ImageLoading, Sendable {
    public init() {}

    public func loadImage(from url: URL) async throws -> UIImage {
        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse,
           (200...299).contains(httpResponse.statusCode) == false {
            throw ImageLoadError.httpError
        }

        guard let image = UIImage(data: data) else {
            throw ImageLoadError.invalidImageData
        }

        return image
    }
}

public extension ImageLoader {
    static let `default` = ImageLoader()
}

public enum ImageLoadError: Error, Sendable {
    case httpError
    case invalidImageData
}
