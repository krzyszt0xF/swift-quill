import Foundation

struct BufferedStreamConfiguration: Equatable, Sendable {
    var minModuleLength: Int
    var maxBufferingDelay: TimeInterval

    init(
        minModuleLength: Int = 50,
        maxBufferingDelay: TimeInterval = 1.5) {
        self.minModuleLength = max(1, minModuleLength)
        self.maxBufferingDelay = max(0.1, maxBufferingDelay)
    }

    static var `default`: Self { Self() }
}
