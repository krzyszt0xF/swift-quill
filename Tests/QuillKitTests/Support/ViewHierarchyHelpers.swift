@testable import QuillKit
import UIKit

extension UIView {
    @MainActor
    func firstCodeBlockView() -> CodeBlockView? {
        firstSubview()
    }
    
    @MainActor
    func firstDocumentTextView() -> DocumentTextView? {
        firstSubview()
    }
    
    @MainActor
    func firstSubview<T: UIView>(where predicate: ((T) -> Bool)? = nil) -> T? {
        for subview in subviews {
            if let match = subview as? T, predicate?(match) ?? true {
                return match
            }
            
            if let nestedMatch = subview.firstSubview(where: predicate) {
                return nestedMatch
            }
        }
        
        return nil
    }
}

extension QuillView {
    @MainActor
    var hasCodeBlockAttachment: Bool {
        guard
            let textView = firstDocumentTextView(),
            let storage = textView.contentStorage,
            let attributedString = storage.attributedString
        else { return false }
        
        var isCodeBlockPresent = false
        attributedString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedString.length)) { value, _, stop in
            if value is CodeBlockAttachment {
                isCodeBlockPresent = true
                stop.pointee = true
            }
        }
        
        return isCodeBlockPresent
    }
    
    @MainActor
    var hasDocumentContent: Bool {
        guard
            let textView = firstDocumentTextView(),
            let storage = textView.contentStorage,
            let attributedString = storage.attributedString
        else { return false }
        
        return attributedString.length > 0
    }
}

