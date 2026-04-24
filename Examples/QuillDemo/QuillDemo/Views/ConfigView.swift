import QuillKit
import SwiftUI

struct ConfigView: View {
    @State private var config: PlaygroundConfig = .default
    @State private var advancedExpanded = false

    var body: some View {
        Form {
            scenarioSection
            renderingSection
            integrationsSection
            advancedSection
            startSection
        }
        .navigationTitle("QuillDemo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension ConfigView {
    var advancedSection: some View {
        Section {
            DisclosureGroup("Advanced", isExpanded: $advancedExpanded) {
                Picker("Streaming mode", selection: $config.streamingMode) {
                    Text("Smoothed tail").tag(StreamingMode.smoothedTail)
                    Text("Buffered modules").tag(StreamingMode.bufferedModules)
                }
                VStack(alignment: .leading) {
                    HStack {
                        Text("Chunk delay")
                        Spacer()
                        Text("\(Int(config.chunkDelayMs)) ms")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $config.chunkDelayMs, in: 0...500, step: 10)
                }
            }
        }
    }
    
    var integrationsSection: some View {
        Section("Integrations") {
            Toggle("Syntax highlighting", isOn: $config.syntaxHighlightingEnabled)
            Toggle("Image loading", isOn: $config.imageLoadingEnabled)
        }
    }
    
    var renderingSection: some View {
        Section("Rendering") {
            Picker("Preset", selection: $config.preset) {
                ForEach(PresetChoice.allCases) { choice in
                    Text(choice.displayName).tag(choice)
                }
            }
            Picker("Theme", selection: $config.theme) {
                ForEach(ThemeChoice.allCases) { choice in
                    Text(choice.displayName).tag(choice)
                }
            }
        }
    }
    
    var scenarioSection: some View {
        Section("Scenario") {
            Picker("Scenario", selection: $config.scenario) {
                ForEach(Scenario.allCases) { scenario in
                    Text(scenario.displayName).tag(scenario)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    var startSection: some View {
        Section {
            NavigationLink {
                StreamingView(config: config)
            } label: {
                Text("Start streaming")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ConfigView()
    }
}
