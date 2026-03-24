enum SupportedLanguage: String {
    case bash
    case javascript
    case objectiveC = "objective-c"
    case python
    case ruby
    case typescript
    case yaml

    init?(abbreviation: String) {
        switch abbreviation {
        case "js":
            self = .javascript
        case "objc":
            self = .objectiveC
        case "py":
            self = .python
        case "rb":
            self = .ruby
        case "sh":
            self = .bash
        case "ts":
            self = .typescript
        case "yml":
            self = .yaml
        default:
            return nil
        }
    }

    var normalized: String {
        rawValue
    }
}
