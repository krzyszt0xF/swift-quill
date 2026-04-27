import QuillHighlight
import QuillImageLoader
import QuillKit
import QuillSwiftUI
import SwiftUI

struct StreamingView: View {
    let config: PlaygroundConfig

    @State private var streamID = UUID()
    @State private var streamHandle = QuillStreamHandle()
    @State private var chunkStream: AsyncStream<String> = emptyStream
    @State private var runState: RunState = .idle
    @State private var showInspector = false
    @State private var streamStartedAt: Date?
    @State private var elapsed: TimeInterval = 0

    enum RunState: String {
        case completed
        case idle
        case streaming
    }

    var body: some View {
        ZStack(alignment: .top) {
            renderedArea
            if showInspector {
                InspectorOverlay(
                    config: config,
                    runState: runState,
                    elapsed: elapsed
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .safeAreaInset(edge: .bottom) { controlBar }
        .navigationTitle(config.scenario.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showInspector.toggle()
                    }
                } label: {
                    Image(systemName: showInspector ? "eye.slash" : "eye")
                }
                .accessibilityLabel("Toggle inspector")
            }
        }
        .onAppear {
            if runState == .idle { start() }
        }
        .task(id: runState) {
            guard runState == .streaming, let startedAt = streamStartedAt else { return }
            while !Task.isCancelled, runState == .streaming {
                elapsed = Date().timeIntervalSince(startedAt)
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }
}

private extension StreamingView {
    static let bottomAnchorID = "bottom"

    static var emptyStream: AsyncStream<String> {
        AsyncStream { $0.finish() }
    }

    var controlBar: some View {
        HStack(spacing: 12) {
            Button {
                start()
            } label: {
                Label("Restart", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                cancelCurrentStream()
            } label: {
                Label("Cancel", systemImage: "stop.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(runState != .streaming)
        }
        .padding()
        .background(.bar)
    }

    var renderedArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                QuillStreamView(
                    chunks: chunkStream,
                    streamID: streamID,
                    configuration: config.makeQuillConfiguration(),
                    handle: streamHandle
                )
                .quill.setHighlighter(config.syntaxHighlightingEnabled ? SyntaxHighlighter.default : nil)
                .quill.setImageLoader(config.imageLoadingEnabled ? ImageLoader.default : nil)
                .quill.onStreamFinished {
                    if runState == .streaming {
                        runState = .completed
                    }
                }
                .padding(.horizontal)

                Color.clear
                    .frame(height: 0)
                    .id(Self.bottomAnchorID)
            }
            .onChange(of: elapsed) { _, _ in
                guard runState == .streaming else { return }
                proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
            }
        }
    }
}

private extension StreamingView {
    func cancelCurrentStream() {
        streamHandle.cancelStreaming()
        runState = .completed
        streamStartedAt = nil
    }

    func start() {
        streamID = UUID()
        chunkStream = ChunkStream.stream(
            for: config.scenario,
            chunkDelayMs: config.chunkDelayMs
        )
        streamStartedAt = Date()
        elapsed = 0
        runState = .streaming
    }
}

#Preview {
    NavigationStack {
        StreamingView(config: .default)
    }
}
