import Foundation
import ServiceManagement

/// App-wide settings from the Paramètres page, kept in the user defaults.
@MainActor @Observable
final class Preferences {
    @ObservationIgnored private let defaults: UserDefaults

    var showMenuBarExtra: Bool { didSet { defaults.set(showMenuBarExtra, forKey: "showMenuBarExtra") } }
    var showSpeedInMenuBar: Bool { didSet { defaults.set(showSpeedInMenuBar, forKey: "showSpeedInMenuBar") } }
    var notifyMountFailure: Bool { didSet { defaults.set(notifyMountFailure, forKey: "notifyMountFailure") } }
    var notifySessionExpired: Bool { didSet { defaults.set(notifySessionExpired, forKey: "notifySessionExpired") } }
    var notifyNearlyFull: Bool { didSet { defaults.set(notifyNearlyFull, forKey: "notifyNearlyFull") } }
    var defaultMethod: MountMethod { didSet { defaults.set(defaultMethod.rawValue, forKey: "defaultMethod") } }
    var defaultProfile: Profile { didSet { defaults.set(defaultProfile.rawValue, forKey: "defaultProfile") } }
    var cacheBase: URL { didSet { defaults.set(cacheBase.path, forKey: "cacheBase") } }
    var showNotesAfterUpdate: Bool { didSet { defaults.set(showNotesAfterUpdate, forKey: "showNotesAfterUpdate") } }
    /// The last version whose notes were opened, which clears the dot on the notes button.
    var notesSeenVersion: String? { didSet { defaults.set(notesSeenVersion, forKey: "notesSeenVersion") } }
    var theme: AppTheme { didSet { defaults.set(theme.rawValue, forKey: "theme") } }
    /// The drives page shows the groups; turned off, each drive keeps its group for when they come back.
    var showGroups: Bool { didSet { defaults.set(showGroups, forKey: "showGroups") } }

    /// Whether the windows wear the Christmas theme today.
    var isChristmas: Bool { theme.isChristmas(Date()) }

    /// Mirrors the login item; turning it on asks macOS to open Docklume at login.
    var openAtLogin: Bool {
        didSet {
            let service = SMAppService.mainApp
            guard openAtLogin != (service.status == .enabled) else { return }
            loginItemProblem = nil
            do {
                try openAtLogin ? service.register() : service.unregister()
            } catch {
                loginItemProblem = error.localizedDescription
            }
            if openAtLogin, service.status == .requiresApproval {
                loginItemProblem = L("En attente de votre accord dans Réglages Système.")
                SMAppService.openSystemSettingsLoginItems()
            }
            openAtLogin = service.status == .enabled
        }
    }
    /// The app's language; the windows change at once. Also saved as the app's own AppleLanguages, so that the menus
    /// macOS draws follow at the next launch; the system language removes it, leaving macOS's choice, including the
    /// one made for Docklume in Réglages Système › Général › Langue et région.
    var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: "language")
            if language == .system {
                defaults.removeObject(forKey: "AppleLanguages")
            } else {
                defaults.set([language.rawValue], forKey: "AppleLanguages")
            }
            Lang.use(language)
        }
    }
    /// Why the login item is off although it was turned on.
    private(set) var loginItemProblem: String?

    /// `openAtLogin` stands in for the login item's state, for screenshots that must not register one.
    init(defaults: UserDefaults = .standard, openAtLogin: Bool? = nil) {
        self.defaults = defaults
        defaults.register(defaults: [
            "showMenuBarExtra": true, "showSpeedInMenuBar": true,
            "notifyMountFailure": true, "notifySessionExpired": true, "notifyNearlyFull": true,
            "showNotesAfterUpdate": true
        ])
        showMenuBarExtra = defaults.bool(forKey: "showMenuBarExtra")
        showSpeedInMenuBar = defaults.bool(forKey: "showSpeedInMenuBar")
        notifyMountFailure = defaults.bool(forKey: "notifyMountFailure")
        notifySessionExpired = defaults.bool(forKey: "notifySessionExpired")
        notifyNearlyFull = defaults.bool(forKey: "notifyNearlyFull")
        defaultMethod = defaults.string(forKey: "defaultMethod").flatMap(MountMethod.init) ?? .nfs
        defaultProfile = defaults.string(forKey: "defaultProfile").flatMap(Profile.init) ?? .documents
        cacheBase = defaults.string(forKey: "cacheBase").map { URL(filePath: $0, directoryHint: .isDirectory) } ?? MountOptions.defaultCacheBase
        showNotesAfterUpdate = defaults.bool(forKey: "showNotesAfterUpdate")
        notesSeenVersion = defaults.string(forKey: "notesSeenVersion")
        theme = defaults.string(forKey: "theme").flatMap(AppTheme.init) ?? AppTheme(christmasSetting: defaults.string(forKey: "christmas"))
        showGroups = defaults.bool(forKey: "showGroups")
        let language = defaults.string(forKey: "language").flatMap(AppLanguage.init) ?? .system
        self.language = language
        Lang.use(language)
        self.openAtLogin = openAtLogin ?? (SMAppService.mainApp.status == .enabled)
    }

    /// Turns the login item on at the first launch that offers it, as Docklume keeps the drives mounted from the
    /// menu bar. Only once, so that turning it off, here or in Réglages Système, lasts.
    func enableOpenAtLoginOnce() {
        guard !defaults.bool(forKey: "openAtLoginOffered") else { return }
        defaults.set(true, forKey: "openAtLoginOffered")
        let service = SMAppService.mainApp
        guard service.status == .notRegistered || service.status == .notFound else { return }
        try? service.register()
        openAtLogin = service.status == .enabled
    }

    static let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
    static let appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
}

/// The look of the window: standard, or a seasonal theme all year; Automatique wears each theme in its season.
/// A new theme is a case here, with its season in `isChristmas`'s like.
enum AppTheme: String, CaseIterable {
    case automatic = "Automatique"
    case standard = "Standard"
    case christmas = "Noël"

    /// The raw value is stored in the settings; this is what the app shows.
    var title: String {
        switch self {
        case .automatic: L("Automatique")
        case .standard: L("Standard")
        case .christmas: L("Noël")
        }
    }

    /// One for every choice, so that the settings row keeps its height.
    var hint: String {
        switch self {
        case .automatic: L("Noël du 1er décembre au 6 janvier, standard le reste de l'année.")
        case .standard: L("Sans décor, toute l'année.")
        case .christmas: L("Ciel d'hiver, neige et bonnet, toute l'année.")
        }
    }

    /// Christmas runs from the 1st of December to Epiphany.
    func isChristmas(_ date: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .christmas: return true
        case .standard: return false
        case .automatic:
            let day = calendar.dateComponents([.month, .day], from: date)
            return day.month == 12 || (day.month == 1 && (day.day ?? 0) <= 6)
        }
    }

    /// The setting before the themes, "christmas": Activé, Désactivé or Automatique.
    init(christmasSetting: String?) {
        switch christmasSetting {
        case "Activé": self = .christmas
        case "Désactivé": self = .standard
        default: self = .automatic
        }
    }
}
