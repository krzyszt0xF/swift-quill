# Document Architecture

A guide to building well-structured documents with explicit organization.

## Block Hierarchy

Understanding block nesting is fundamental to correct rendering.

### Heading Levels

Headings create the document outline and influence the navigation structure.

#### Fourth-Level Headings

Fourth-level headings are used for fine-grained sections within a subsection.

---

## Lists and Nesting

### Unordered Lists

- Top-level item about parsing strategy
- Second item about rendering approach
  - Nested item covering fragment caching
  - Another nested item on cache invalidation
    - Deeply nested item on eviction policy
    - Another deep item on memory thresholds
      - Fourth-level nesting for edge case documentation
  - Back to second level
- Third top-level item about performance measurement

### Ordered Lists

1. Initialize the rendering pipeline
2. Configure the theme and layout parameters
3. Set up the stream coordinator
   1. Create the document renderer
   2. Wire the height coordinator
   3. Configure the buffered stream commit scheduler
      1. Set the minimum module length
      2. Set the maximum buffering delay
      3. Register the commit callback
   4. Initialize the visual feeder
4. Begin accepting streaming input
5. Process parser events through the reducer
   1. Apply the event to the reducer state
   2. Build a streaming snapshot
   3. Apply the snapshot to the renderer

### Task Lists

- [x] Implement block-level parsing
- [x] Add inline formatting support
- [ ] Add table rendering
- [x] Implement code block highlighting
- [ ] Add image loading with aspect ratio updates
- [x] Wire height measurement coordinator
- [ ] Complete accessibility annotations
  - [x] Add heading accessibility traits
  - [ ] Add list item accessibility labels
  - [ ] Add code block language announcements
- [x] Implement streaming cancellation

### Mixed Lists

- Configuration options
  1. Theme selection
  2. Layout parameters
  3. Rendering preset
- Runtime behaviors
  1. Stream lifecycle management
     - Start and bootstrap
     - Append chunks
     - Finish and flush
  2. Height invalidation
     - Coalescing interval
     - Minimum delta threshold
  3. Enrichment scheduling
     - Syntax highlighting
     - Image loading

---

## Block Quotes

> The simplest form of a block quote contains a single paragraph of text. This paragraph should wrap across multiple lines to exercise the block quote layout path.

> **Nested block quotes** test the rendering of recursive structures.
>
> > This is a second-level nested quote. It should be visually indented further than the parent quote.
> >
> > > Third level of nesting is rare but must render correctly. The indentation should continue to increase and the vertical bar indicators should stack.

> A multi-paragraph block quote tests paragraph spacing within the quote container.
>
> This second paragraph should have appropriate spacing above it while remaining inside the same block quote indicator.
>
> And a third paragraph completes the multi-paragraph test case.

### Block Quotes with Lists

> Inside a block quote, lists should render with proper indentation:
>
> - First item in the quoted list
> - Second item with more detail
>   - Nested item inside the quoted list
> - Third item to complete the list
>
> And text after the list should return to normal quote formatting.

> Ordered lists in quotes:
>
> 1. Step one of the quoted procedure
> 2. Step two with additional context
> 3. Step three concluding the procedure

---

## Heading Density Section

### First Subsection

A brief paragraph between headings.

### Second Subsection

Another brief paragraph testing heading-to-heading transitions.

### Third Subsection

Testing rapid heading succession.

#### Sub-subsection A

Detail under the third subsection.

#### Sub-subsection B

More detail at the same level.

### Fourth Subsection

Back to the third heading level.

---

## Complex Nesting

### Lists Inside Block Quotes Inside Lists

- Outer list item
  > Quoted content inside a list item
  >
  > - Inner list inside the quote
  > - Second inner list item
  
- Second outer item with no quote

### Deep Ordered Nesting

1. Level one
   1. Level two
      1. Level three
         1. Level four -- testing maximum practical nesting depth
         2. Second item at level four
      2. Back to level three
   2. Back to level two
2. Back to level one
3. Another level-one item for completeness

---

## Structural Transitions

### Heading to List

- Immediate list after heading tests the transition rendering

### Heading to Block Quote

> Immediate quote after heading tests another transition type

### Heading to Thematic Break

---

### After Thematic Break

Content after a thematic break should render with appropriate spacing.

## Final Section

### Summary Items

- The document contains 8 headings at level 2
- Headings range from H1 through H4
- Lists include ordered, unordered, and task variants
- Nesting reaches 4 levels in both list types
- Block quotes nest 3 levels deep
- Mixed structural elements test transition rendering
- Thematic breaks separate major sections

### Closing Notes

This fixture exercises the structural block rendering path with minimal prose content.
Each section is intentionally short to maximize the ratio of structural elements to flowing text.
