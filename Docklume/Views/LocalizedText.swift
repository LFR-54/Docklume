import SwiftUI

extension Text {
    /// A text that holds other texts, such as a path in a monospaced font: `key` is the French text with `%@` for
    /// each of them, in order, and `%%` for a percent sign.
    init(composing key: String, _ parts: Text...) {
        let segments = Lang.template(key).components(separatedBy: "%@").map { $0.replacingOccurrences(of: "%%", with: "%") }
        var text = Text(verbatim: segments[0])
        for (index, segment) in segments.dropFirst().enumerated() {
            let part = index < parts.count ? parts[index] : Text(verbatim: "")
            text = Text("\(text)\(part)\(Text(verbatim: segment))")
        }
        self = text
    }
}
