import Foundation

/// Number formats of the mockup, in the app's language: "64,0 Mo/s" in French, "64.0 MB/s" in English.
enum Format {
    /// Below 1 kB/s a drive counts as idle.
    static let idleThreshold = 1_000.0

    /// "182 Mo/s", "64,0 Mo/s", "320 Ko/s", or "—" when nothing moves.
    static func speed(_ bytesPerSecond: Double) -> String {
        let megabytes = bytesPerSecond / 1_000_000
        if bytesPerSecond < idleThreshold { return "—" }
        if megabytes >= 100 { return "\(Int(megabytes.rounded())) \(unit("Mo/s"))" }
        if megabytes >= 1 { return "\(decimal(megabytes, 1)) \(unit("Mo/s"))" }
        return "\(Int((bytesPerSecond / 1_000).rounded())) \(unit("Ko/s"))"
    }

    /// Space in the cloud, in powers of 1024 as the services count it: Dropbox's 10 To plan, 10 × 1024⁴ bytes,
    /// reads "10,00 To" here and on its site, where the Finder shows 11 To.
    static func capacity(_ bytes: Int64) -> String { scaled(Double(bytes), base: 1024) }

    /// Files on this Mac, in powers of 1000 as the Finder counts them: "1,31 To", "620 Go", "85 Mo".
    static func fileSize(_ bytes: Int64) -> String { scaled(Double(bytes), base: 1000) }

    private static func scaled(_ value: Double, base: Double) -> String {
        let mega = base * base, giga = mega * base, tera = giga * base
        if value >= tera { return "\(decimal(value / tera, 2)) \(unit("To"))" }
        if value >= giga { return "\(Int((value / giga).rounded())) \(unit("Go"))" }
        return "\(Int((value / mega).rounded())) \(unit("Mo"))"
    }

    /// Cache sizes: "48 Go", "1,4 Go".
    static func gigabytes(_ bytes: Int64) -> String {
        let value = Double(bytes) / 1e9
        return value >= 10 || value == 0 ? "\(Int(value.rounded())) \(unit("Go"))" : "\(decimal(value, 1)) \(unit("Go"))"
    }

    /// Chart scale labels: "120 Mo/s", "7,5 Mo/s".
    static func tick(_ bytesPerSecond: Double) -> String {
        let megabytes = bytesPerSecond / 1_000_000
        return megabytes == megabytes.rounded() ? "\(Int(megabytes)) \(unit("Mo/s"))" : "\(decimal(megabytes, 1)) \(unit("Mo/s"))"
    }

    /// Octets in French, bytes in English: "Mo/s" becomes "MB/s".
    static func unit(_ french: String) -> String {
        guard Lang.isEnglish else { return french }
        return french.replacingOccurrences(of: "Ko", with: "kB").replacingOccurrences(of: "o", with: "B")
    }

    static func decimal(_ value: Double, _ digits: Int) -> String {
        let text = String(format: "%.\(digits)f", value)
        return Lang.isEnglish ? text : text.replacingOccurrences(of: ".", with: ",")
    }

    /// "3 lecteurs", "1 lecteur", "0 lecteur"; "3 drives", "1 drive", "0 drives". `word` is the French singular,
    /// whose English singular and plural are in `English.table` and `English.plurals`.
    static func plural(_ count: Int, _ word: String) -> String {
        guard Lang.isEnglish else { return "\(count) \(word)\(count > 1 ? "s" : "")" }
        let singular = English.table[word] ?? word
        return "\(count) \(count == 1 ? singular : English.plurals[singular] ?? singular + "s")"
    }

    /// "à l'instant", "il y a 6 min", "il y a 2 h", "jamais".
    static func ago(_ date: Date?, now: Date = .now) -> String {
        guard let date else { return L("jamais") }
        let minutes = Int(now.timeIntervalSince(date) / 60)
        if minutes < 1 { return L("à l'instant") }
        if minutes < 60 { return L("il y a \(minutes) min") }
        if minutes < 48 * 60 { return L("il y a \(minutes / 60) h") }
        return L("le \(date.formatted(.dateTime.day().month(.abbreviated).locale(Lang.locale)))")
    }

    /// A day as the release notes show it: "7 nov. 2026", "Nov 7, 2026".
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year().locale(Lang.locale))
    }
}
