import CoreGraphics

/// Spacing token that can be absolute or relative to the body font size.
public enum SpacingValue: Sendable {
    case absolute(CGFloat)
    case relative(CGFloat)

    public func scale(against bodyFontSize: CGFloat) -> CGFloat {
        switch self {
        case let .absolute(value):
            value
        case let .relative(multiplier):
            bodyFontSize * multiplier
        }
    }
}

extension SpacingValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .absolute(value)
    }
}

extension SpacingValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .absolute(CGFloat(value))
    }
}
