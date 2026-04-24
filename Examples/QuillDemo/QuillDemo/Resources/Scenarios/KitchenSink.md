# Kitchen sink

A reference scenario exercising every supported Markdown feature. Use this to spot regressions at a glance.

## Heading levels

# Heading level 1
## Heading level 2
### Heading level 3
#### Heading level 4
##### Heading level 5
###### Heading level 6

## Inline styles

The quick **bold fox** jumps over the *lazy italic dog*. Sometimes it is ***both bold and italic***. Inline `code` sits calmly next to prose. ~~Struck-through~~ text indicates deletions if your theme renders strikethrough. Links look like [this](https://www.swift.org) and bare references like <https://www.apple.com/swift/> should render correctly too.

## Unordered list

- First item
- Second item with **bold** inside
- Third item with `inline code`
  - Nested first
  - Nested second
    - Deeply nested

## Ordered list

1. Step one
2. Step two
3. Step three
   1. Sub-step
   2. Another sub-step

## Mixed nesting

1. Numbered parent
   - Bulleted child
   - Bulleted child with [link](https://swift.org/documentation/)
2. Second parent
   1. Numbered grandchild
   2. Another grandchild

## Blockquotes

> A single-line quote demonstrates the blockquote style.

> Multi-line quotes preserve line breaks.
>
> They handle paragraph breaks inside the quote too, which is useful for citing longer passages.

## Fenced code block with language

```swift
import SwiftUI
import QuillSwiftUI

struct ChatMessageView: View {
    let messageID: UUID
    let chunks: AsyncStream<String>

    var body: some View {
        QuillStreamView(
            chunks: chunks,
            streamID: messageID
        )
    }
}
```

## Fenced code block without language

```
generic monospace output
no highlighting expected
```

## Horizontal rules

Above the rule.

---

Below the rule.

## Table

| Feature | Supported | Notes |
| --- | :---: | --- |
| Headings 1–6 | yes | all levels |
| Bold / italic | yes | incl. combined |
| Code block | yes | fenced with language |
| Table | yes | simple layout |
| Image | yes | via ImageLoader |

## Image

![Picsum placeholder](https://picsum.photos/seed/quill/600/300)

## Task list

- [x] Write kitchen sink scenario
- [x] Verify every feature renders
- [ ] Keep an eye on regressions

## Closing

If anything above renders incorrectly, open an issue on the swift-quill repository with a screenshot of the kitchen sink and the preset / theme selected.
