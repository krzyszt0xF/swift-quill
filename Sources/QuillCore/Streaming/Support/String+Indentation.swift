extension String {
    func removingLeadingIndent(width: Int) -> String {
        guard width > 0 else { return self }

        var remainingWidth = width
        var index = startIndex

        while index < endIndex, remainingWidth > 0 {
            let character = self[index]
            guard character == " " || character == "\t" else { break }
            remainingWidth -= 1
            index = self.index(after: index)
        }

        return String(self[index...])
    }
}
