import UIKit

typealias OnCopy = @MainActor (String) -> Void

enum CopyAction {
    @MainActor
    static let live: OnCopy = { UIPasteboard.general.string = $0 }
}
