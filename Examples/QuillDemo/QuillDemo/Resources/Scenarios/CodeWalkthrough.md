# Code walkthrough

This scenario streams code blocks in several languages to exercise syntax highlighting. Toggle **Syntax highlighting** off on the config screen to compare rendered output.

## Swift

A simple streaming consumer that wires `QuillStreamView` into a SwiftUI view:

```swift
import SwiftUI
import QuillSwiftUI

struct ChatBubble: View {
    let messageID: UUID
    let chunks: AsyncStream<String>

    var body: some View {
        QuillStreamView(
            chunks: chunks,
            streamID: messageID
        )
        .quill.onStreamFinished {
            print("done")
        }
    }
}
```

## Python

A minimal async generator that feeds chunks into a consumer:

```python
import asyncio

async def generate_tokens(text: str, chunk_size: int = 4):
    words = text.split(" ")
    for index in range(0, len(words), chunk_size):
        await asyncio.sleep(0.05)
        yield " ".join(words[index:index + chunk_size]) + " "

async def main():
    text = "Streaming markdown should feel natural and calm."
    async for chunk in generate_tokens(text):
        print(chunk, end="", flush=True)

asyncio.run(main())
```

## JSON

Configuration payload echoed from a hypothetical tool-use response:

```json
{
  "streamID": "a3c1-9f2d",
  "preset": "balanced",
  "theme": "default",
  "integrations": {
    "syntaxHighlighting": true,
    "imageLoading": true
  }
}
```

## Inline references

Types mentioned above — `QuillStreamView`, `QuillStreamingPreset`, `StreamingMode` — are part of the public surface. See the DocC catalog for details.
