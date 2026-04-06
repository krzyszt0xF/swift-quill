import QuillCore
import UIKit

enum ImageLoadResult {
    case failed
    case loaded(UIImage)
}

protocol ImageLoadStore: AnyObject, Sendable {
    func loadResult(for blockID: BlockIdentity) -> ImageLoadResult?
    func register(sink: any ImageLoadSink, for blockID: BlockIdentity)
    func resolvedAspectRatio(for blockID: BlockIdentity) -> CGFloat?
    func retryLoad(blockID: BlockIdentity, source: String?)
    var retryEnabled: Bool { get }
    func unregisterSink(for blockID: BlockIdentity)
}
