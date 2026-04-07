import UIKit

public extension QuillTheme {
    static var `default`: QuillTheme {
        Self(
            blockquote: .init(
                barColor: .separator,
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
                backgroundColor: .systemBackground,
                borderColor: UIColor.separator.withAlphaComponent(0.14),
                borderWidth: 1,
                copyButtonTint: .label,
                cornerRadius: 20,
                font: UIFont(name: "Menlo-Regular", size: 14) ?? .monospacedSystemFont(ofSize: 14, weight: .regular),
                headerFont: .systemFont(ofSize: 12, weight: .semibold),
                languageLabelColor: .label,
                lineSpacing: 2,
                padding: 12,
                textColor: .label
            ),
            heading: .init(
                fontScales: [.relative(1.75), .relative(1.5), .relative(1.25), .relative(1.125), .relative(1), .relative(0.875)],
                fontWeights: [.bold, .bold, .semibold, .semibold, .medium, .medium],
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
                backgroundColor: .systemGray6,
                fontSizeOffset: -1,
                textColor: .label
            ),
            link: .init(
                color: .systemBlue,
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
                bodyFont: .systemFont(ofSize: 14),
                cellPadding: UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12),
                headerFont: .systemFont(ofSize: 14, weight: .semibold),
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
