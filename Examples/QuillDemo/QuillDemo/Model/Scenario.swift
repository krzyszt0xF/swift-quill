import Foundation

enum Scenario: String, CaseIterable, Identifiable, Hashable, Sendable {
    case codeWalkthrough
    case imageHeavy
    case kitchenSink
    case longForm
    case quickStart

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .codeWalkthrough: return "Code walkthrough"
        case .imageHeavy: return "Image-heavy"
        case .kitchenSink: return "Kitchen sink"
        case .longForm: return "Long-form article"
        case .quickStart: return "Quick start"
        }
    }

    func loadContent() -> String {
        guard
            let url = Bundle.main.url(forResource: resourceName, withExtension: "md"),
            let content = try? String(contentsOf: url, encoding: .utf8)
        else {
            return "# \(displayName)\n\nScenario content could not be loaded."
        }
        return content
    }
}

private extension Scenario {
    var resourceName: String {
        switch self {
        case .codeWalkthrough: return "CodeWalkthrough"
        case .imageHeavy: return "ImageHeavy"
        case .kitchenSink: return "KitchenSink"
        case .longForm: return "LongForm"
        case .quickStart: return "QuickStart"
        }
    }
}
