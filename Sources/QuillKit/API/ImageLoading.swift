import UIKit

/// Consumer-provided image loader for standalone image blocks.
public protocol ImageLoading: Sendable {
    func loadImage(from url: URL) async throws -> UIImage
}
