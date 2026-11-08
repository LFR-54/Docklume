import SwiftUI
import UniformTypeIdentifiers

struct SettingsPage: View {
    @Environment(DriveStore.self) private var store
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var preferences = store.preferences
        PageScroll {
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle(text: L("Général"), top: 4)
                SettingsGroup {
                    SettingsRow(L("Langue"), hint: preferences.language == .system ? L("Comme macOS : \(AppLanguage.systemChoice.title).") : nil) {
                        SegmentedControl(selection: $preferences.language, options: AppLanguage.allCases, title: \.label)
                    }
                    SettingsRow(L("Ouvrir Docklume à l'ouverture de session"),
                                hint: preferences.loginItemProblem ?? (preferences.showMenuBarExtra ? L("Fenêtre fermée, dans la barre des menus.") : nil)) {
                        SwitchToggle(isOn: $preferences.openAtLogin, label: L("Ouvrir à l'ouverture de session"))
                    }
                    SettingsRow(L("Afficher dans la barre des menus"),
                                hint: preferences.showMenuBarExtra ? L("Docklume y reste quand la fenêtre est fermée.") : L("Fermer la fenêtre quitte Docklume.")) {
                        SwitchToggle(isOn: $preferences.showMenuBarExtra, label: L("Afficher dans la barre des menus"))
                    }
                    SettingsRow(L("Afficher le débit dans la barre des menus"), hint: nil as String?) {
                        SwitchToggle(isOn: $preferences.showSpeedInMenuBar, label: L("Afficher le débit"))
                    }
                    SettingsRow(L("Thème de Noël"), hint: preferences.christmas == .automatic ? L("Du 1er décembre au 6 janvier.") : nil) {
                        PopupButton(selection: $preferences.christmas, options: ChristmasTheme.allCases, title: \.title)
                    }
                }
                SectionTitle(text: L("Notifications"))
                SettingsGroup {
                    SettingsRow(L("Échec de montage"), hint: nil as String?) {
                        SwitchToggle(isOn: $preferences.notifyMountFailure, label: L("Notifier les échecs de montage"))
                    }
                    SettingsRow(L("Session expirée"), hint: L("Quand un service demande de se reconnecter.")) {
                        SwitchToggle(isOn: $preferences.notifySessionExpired, label: L("Notifier les sessions expirées"))
                    }
                    SettingsRow(L("Espace presque plein"), hint: L("À partir de 90 % d'occupation.")) {
                        SwitchToggle(isOn: $preferences.notifyNearlyFull, label: L("Notifier l'espace presque plein"))
                    }
                }
                SectionTitle(text: L("Nouveaux lecteurs"))
                SettingsGroup {
                    SettingsRow(L("Méthode par défaut"), hint: MacFUSE.version.map { L("macFUSE \($0) détecté.") } ?? L("macFUSE n'est pas installé : les lecteurs passent par le client NFS de macOS.")) {
                        PopupButton(selection: $preferences.defaultMethod, options: MountMethod.allCases, title: \.title, isEnabled: \.isAvailable)
                    }
                    SettingsRow(L("Profil par défaut"), hint: nil as String?) {
                        PopupButton(selection: $preferences.defaultProfile, options: Profile.allCases, title: \.title)
                    }
                }
                SectionTitle(text: L("Cache"))
                SettingsGroup {
                    SettingsRow(L("Emplacement"), hint: Text(Drive.abbreviate(preferences.cacheBase.path(percentEncoded: false))).font(.system(size: 11, design: .monospaced))) {
                        Button(L("Modifier…"), action: chooseCacheFolder)
                            .buttonStyle(PushButtonStyle())
                    }
                    SettingsRow(L("Espace utilisé"), hint: L("\(Format.gigabytes(store.totalCacheBytes)) pour \(Format.plural(store.drives.count, "lecteur"))")) {
                        Button(L("Vider tout le cache…"), action: clearAll)
                            .buttonStyle(PushButtonStyle())
                    }
                }
                SectionTitle(text: L("Configuration"))
                SettingsGroup {
                    SettingsRow(L("Importer depuis rclone"), hint: importHint) {
                        Button(L("Importer…"), action: importRemotes)
                            .buttonStyle(PushButtonStyle())
                            .disabled(store.importableRemotes.isEmpty)
                    }
                    SettingsRow(L("Exporter les lecteurs"), hint: L("Noms, remotes et réglages, sans les mots de passe ni les jetons qui restent dans rclone.conf.")) {
                        Button(L("Exporter…"), action: export)
                            .buttonStyle(PushButtonStyle())
                    }
                }
                SectionTitle(text: L("Moteur"))
                SettingsGroup {
                    SettingsRow(L("rclone \(store.engineRelease ?? "…")"), hint: engineHint) {
                        Button(L("Rechercher une mise à jour"), action: checkUpdate)
                            .buttonStyle(PushButtonStyle())
                    }
                }
            }
        }
    }

    private var configPath: String { Drive.abbreviate(store.configPath ?? "~/.config/rclone/rclone.conf") }

    private var importHint: Text {
        let count = store.importableRemotes.count
        let path = Text(configPath).font(.system(size: 11, design: .monospaced))
        return count == 0
            ? Text(composing: "Tous les remotes de %@ sont des lecteurs.", path)
            : Text(composing: count > 1 ? "%@ remotes à importer dans %@" : "%@ remote à importer dans %@", Text(verbatim: "\(count)"), path)
    }

    private var engineHint: String {
        guard let rclone = Rclone.locate() else { return L("Introuvable") }
        return rclone.isBundled ? L("Inclus avec Docklume : 16 connexions partagées entre les fichiers lus.") : L("Installé dans \(Drive.abbreviate(rclone.executable.deletingLastPathComponent().path(percentEncoded: false)))")
    }

    private func chooseCacheFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = L("Choisir")
        panel.message = L("Les caches y sont déplacés, avec les fichiers pas encore envoyés. Les lecteurs montés sont remontés.")
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let remounts = store.hasActiveMounts
        Task {
            await store.moveCaches(to: folder)
            app.show(remounts ? L("Emplacement du cache modifié, lecteurs remontés") : L("Emplacement du cache modifié"))
        }
    }

    private func clearAll() {
        let interrupted = store.hasActiveMounts ? L(" Les volumes montés sont remontés : les lectures en cours s'interrompent.") : ""
        app.confirm(L("Vider tout le cache ?"),
                    message: L("Les fichiers lus seront retéléchargés à la prochaine lecture. Ceux qui n'ont pas encore été envoyés sont conservés.\(interrupted)"),
                    confirm: L("Vider")) {
            let before = store.totalCacheBytes
            Task {
                let kept = await store.clearAllCaches()
                let freed = Format.gigabytes(max(0, before - store.totalCacheBytes))
                app.show(kept.files == 0 ? L("\(freed) libérés")
                             : kept.files > 1 ? L("\(freed) libérés, \(kept.files) fichiers en attente d'envoi conservés")
                             : L("\(freed) libérés, \(kept.files) fichier en attente d'envoi conservé"))
            }
        }
    }

    private func importRemotes() {
        let count = store.importableRemotes.count
        app.confirm(L("Importer \(Format.plural(count, "remote")) ?"),
                    message: L("Ils apparaissent comme lecteurs non montés. Le fichier rclone.conf n'est pas modifié."),
                    confirm: L("Importer")) {
            Task {
                let imported = await store.importRemotes()
                app.show(imported > 1 ? L("\(imported) lecteurs importés depuis rclone.conf") : L("\(imported) lecteur importé depuis rclone.conf"))
            }
        }
    }

    private func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = L("Docklume lecteurs.json")
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.export(to: url)
            app.show(L("Lecteurs exportés sans les mots de passe"))
        } catch {
            app.show(error.localizedDescription, warning: true)
        }
    }

    private func checkUpdate() {
        Task {
            do {
                app.show(try await store.checkEngineUpdate())
            } catch {
                app.show(error.localizedDescription, warning: true)
            }
        }
    }
}
