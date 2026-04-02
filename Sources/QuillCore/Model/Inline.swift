package indirect enum Inline: Equatable, Sendable {
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
