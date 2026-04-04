import QuillCore
import UIKit

protocol CodeBlockHighlightStore: AnyObject, Sendable {
    func highlightedResult(for blockID: BlockIdentity) -> HighlightedCodeSnapshot?
    func registerSink(_ sink: any CodeBlockHighlightSink, for blockID: BlockIdentity)
    func unregisterSink(for blockID: BlockIdentity)
}
