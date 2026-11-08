import Foundation
import Synchronization

/// The language of the app: macOS's choice by default, French or English otherwise.
///
/// The app is written in French; `L` gives the English text from `English.table` when English is in use. Every text
/// is looked up when it is drawn, so changing the language redraws the windows at once, without a relaunch that
/// would unmount the drives. The menus macOS draws itself follow at the next launch.
enum AppLanguage: String, CaseIterable, Sendable {
    case system
    case french = "fr"
    case english = "en"

    /// French when macOS puts it before English among the user's languages, English otherwise.
    static var systemChoice: AppLanguage {
        for identifier in Locale.preferredLanguages {
            switch Locale(identifier: identifier).language.languageCode?.identifier {
            case "fr": return .french
            case "en": return .english
            default: continue
            }
        }
        return .english
    }

    /// The language actually used: never `.system`.
    var resolved: AppLanguage { self == .system ? Self.systemChoice : self }

    /// The name with its flag, as the choice in Paramètres shows it.
    var label: String {
        switch self {
        case .system: title
        case .french: "🇫🇷 " + title
        case .english: "🇬🇧 " + title
        }
    }

    /// The name of each language in itself, so that anyone finds theirs.
    var title: String {
        switch self {
        case .system: L("Système")
        case .french: "Français"
        case .english: "English"
        }
    }
}

enum Lang {
    private static let current = Mutex(AppLanguage.systemChoice)

    static var language: AppLanguage { current.withLock { $0 } }
    static var isEnglish: Bool { language == .english }
    static var locale: Locale { Locale(identifier: isEnglish ? "en_US" : "fr_FR") }

    static func use(_ choice: AppLanguage) {
        current.withLock { $0 = choice.resolved }
    }

    /// The text for `key`, a French text with `%@` for each value and `%%` for a percent sign.
    static func template(_ key: String) -> String {
        isEnglish ? English.table[key] ?? key : key
    }
}

/// A French text, with the values put into it kept apart: its key replaces each value with `%@`, so that the
/// English text is found whatever the values, which then go back in, in the order that text gives.
struct Localized: ExpressibleByStringInterpolation, Sendable {
    var key: String
    var values: [String]

    init(stringLiteral value: String) {
        key = value.replacingOccurrences(of: "%", with: "%%")
        values = []
    }

    init(stringInterpolation: StringInterpolation) {
        key = stringInterpolation.key
        values = stringInterpolation.values
    }

    /// A text known only at run time, such as a release note.
    init(dynamic text: String) {
        self.init(stringLiteral: text)
    }

    struct StringInterpolation: StringInterpolationProtocol {
        var key = ""
        var values: [String] = []

        init(literalCapacity: Int, interpolationCount: Int) {}

        mutating func appendLiteral(_ literal: String) {
            key += literal.replacingOccurrences(of: "%", with: "%%")
        }

        mutating func appendInterpolation(_ value: some CustomStringConvertible) {
            key += "%@"
            values.append(value.description)
        }
    }

    /// Puts the values into a template: `%@` takes the next one, `%2$@` the second, `%%` is a percent sign.
    static func fill(_ template: String, with values: [String]) -> String {
        var result = ""
        var next = 0
        var rest = Substring(template)
        while let percent = rest.firstIndex(of: "%") {
            result += rest[..<percent]
            let after = rest[rest.index(after: percent)...]
            if after.hasPrefix("%") {
                result += "%"
                rest = after.dropFirst()
            } else if after.hasPrefix("@") {
                if next < values.count { result += values[next] }
                next += 1
                rest = after.dropFirst()
            } else if let dollar = after.firstIndex(of: "$"), let position = Int(after[..<dollar]),
                      after[after.index(after: dollar)...].hasPrefix("@") {
                if position >= 1, position <= values.count { result += values[position - 1] }
                rest = after[after.index(dollar, offsetBy: 2)...]
            } else {
                result += "%"
                rest = after
            }
        }
        return result + rest
    }
}

/// The text in the app's language.
func L(_ text: Localized) -> String {
    Localized.fill(Lang.template(text.key), with: text.values)
}
