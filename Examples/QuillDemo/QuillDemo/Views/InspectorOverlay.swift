import SwiftUI

struct InspectorOverlay: View {
    let config: PlaygroundConfig
    let runState: StreamingView.RunState
    let elapsed: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Preset", config.preset.displayName)
            row("Mode", config.streamingMode.rawValue)
            row("Theme", config.theme.displayName)
            row("Syntax hl", config.syntaxHighlightingEnabled ? "on" : "off")
            row("Image loader", config.imageLoadingEnabled ? "on" : "off")
            Divider()
                .background(Color.secondary.opacity(0.4))
            row("State", runState.rawValue)
            row("Elapsed", String(format: "%.1fs", elapsed))
        }
        .font(.caption)
        .monospaced()
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.secondary.opacity(0.3))
        )
    }
}

private extension InspectorOverlay {
    func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}
