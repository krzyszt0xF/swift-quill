import UIKit

public extension QuillTheme {
    static var github: QuillTheme {
        Self(
            blockquote: .init(
                barColor: .systemGray3,
                barCornerRadius: 1.5,
                barLeadingInset: 1,
                barWidth: 3,
                levelSpacing: .relative(1),
                textColor: .secondaryLabel
            ),
            body: .init(
                font: .systemFont(ofSize: 16),
                textColor: .label
            ),
            codeBlock: .init(
                backgroundColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.09, green: 0.10, blue: 0.12, alpha: 1)
                    : UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1)
                },
                borderColor: UIColor.separator.withAlphaComponent(0.14),
                borderWidth: 1,
                copyButtonTint: .label,
                cornerRadius: 6,
                font: UIFont(name: "Menlo-Regular", size: 13) ?? .monospacedSystemFont(ofSize: 13, weight: .regular),
                headerFont: .systemFont(ofSize: 12, weight: .semibold),
                languageLabelColor: .label,
                lineSpacing: 2,
                padding: 12,
                textColor: .label
            ),
            heading: .init(
                fontScales: [
                    .relative(1.75),
                    .relative(1.5),
                    .relative(1.25),
                    .relative(1.125),
                    .relative(1),
                    .relative(0.875)
                ],
                fontWeights: [.semibold, .semibold, .semibold, .semibold, .semibold, .semibold],
                spacingBefore: .relative(0.75)
            ),
            image: .init(
                altTextColor: .secondaryLabel,
                cornerRadius: 16,
                errorIconColor: .secondaryLabel,
                fallbackAspectRatio: 16.0 / 9.0,
                maxHeight: 400,
                placeholderColor: .systemGray5
            ),
            inline: .init(
                backgroundColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark ? UIColor.systemGray5 : UIColor.systemGray6
                },
                fontSizeOffset: -1,
                textColor: .label
            ),
            link: .init(
                color: UIColor { traits in
                    traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.34, green: 0.61, blue: 0.98, alpha: 1)
                    : UIColor(red: 0.02, green: 0.40, blue: 0.85, alpha: 1)
                },
                underlineStyle: .single
            ),
            list: .init(
                bulletMarker: "\u{2022}",
                checkedMarker: "\u{2611}",
                indentPerLevel: .relative(1.5),
                itemSpacing: .relative(0.25),
                uncheckedMarker: "\u{2610}"
            ),
            spacing: .init(
                blockSpacing: .relative(0.5)
            ),
            table: .init(
                bodyFont: UIFont(name: "Menlo-Regular", size: 14)
                ?? .monospacedSystemFont(ofSize: 14, weight: .regular),
                cellPadding: UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12),
                headerFont: UIFont(name: "Menlo-Bold", size: 14)
                ?? .monospacedSystemFont(ofSize: 14, weight: .semibold),
                minimumRowHeight: 44,
                separatorColor: UIColor.separator.withAlphaComponent(0.22),
                separatorWidth: 1
            ),
            thematicBreak: .init(
                color: .separator,
                spacing: .relative(0.5)
            )
        )
    }
}
