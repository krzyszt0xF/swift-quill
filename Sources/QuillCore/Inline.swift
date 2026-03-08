/// An inline element within block-level markdown content.
///
/// Recursive — styled spans like ``strong(_:)`` contain nested `[Inline]`
/// arrays to support arbitrary nesting (e.g. bold-italic text).
public indirect enum Inline: Equatable, Sendable {
    case code(String)
    case emphasis([Inline])
    case image(source: String?, title: String?, alt: [Inline])
    case inlineHTML(String)
    case lineBreak
    case link(destination: String, children: [Inline])
    case strikethrough([Inline])
    case strong([Inline])
    case text(String)

}
