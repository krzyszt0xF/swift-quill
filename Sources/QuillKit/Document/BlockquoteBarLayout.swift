import QuillCore
import UIKit

struct BlockquoteBarLayout {
    struct BarRun: Equatable {
        let blockID: BlockIdentity
        let level: Int
        let maxY: CGFloat
        let minY: CGFloat
    }

    struct FragmentContext {
        let blockID: BlockIdentity
        let depth: Int
        let maxY: CGFloat
        let minY: CGFloat
    }

    static func makeRuns(from fragments: [FragmentContext]) -> [BarRun] {
        var activeRuns: [Int: BarRun] = [:]
        var barRuns: [BarRun] = []

        for fragment in fragments {
            closeInactiveRuns(
                for: fragment,
                activeRuns: &activeRuns,
                barRuns: &barRuns
            )

            for level in 1...fragment.depth {
                if var activeRun = activeRuns[level], activeRun.blockID == fragment.blockID {
                    activeRun = BarRun(
                        blockID: activeRun.blockID,
                        level: activeRun.level,
                        maxY: max(activeRun.maxY, fragment.maxY),
                        minY: min(activeRun.minY, fragment.minY)
                    )
                    activeRuns[level] = activeRun
                    continue
                }

                if let activeRun = activeRuns[level] {
                    barRuns.append(activeRun)
                }
                activeRuns[level] = BarRun(
                    blockID: fragment.blockID,
                    level: level,
                    maxY: fragment.maxY,
                    minY: fragment.minY
                )
            }
        }

        barRuns.append(contentsOf: activeRuns.values.sorted { lhs, rhs in
            if lhs.minY == rhs.minY {
                return lhs.level < rhs.level
            }
            return lhs.minY < rhs.minY
        })
        return barRuns
    }
}

private extension BlockquoteBarLayout {
    static func closeInactiveRuns(
        for fragment: FragmentContext,
        activeRuns: inout [Int: BlockquoteBarLayout.BarRun],
        barRuns: inout [BlockquoteBarLayout.BarRun]
    ) {
        let inactiveLevels = activeRuns.keys.filter { level in
            guard let activeRun = activeRuns[level] else { return false }
            return level > fragment.depth || activeRun.blockID != fragment.blockID
        }

        for level in inactiveLevels.sorted() {
            guard let activeRun = activeRuns.removeValue(forKey: level) else { continue }
            barRuns.append(activeRun)
        }
    }
}
