import SwiftUI

struct DriveDetailPage: View {
    @Environment(DriveStore.self) private var store
    @Environment(AppState.self) private var app
    let drive: Drive
    @Environment(\.compactLayout) private var compact
    @State private var name = ""
    @State private var nameError: String?
    @FocusState private var nameFocused: Bool
    /// The user's own Google key, read again whenever a dialog closes.
    @State private var clientID: String?

    var body: some View {
        let actions = DriveActions(store: store, app: app)
        PageScroll {
            VStack(alignment: .leading, spacing: 0) {
                stats
                SectionTitle(text: L("Général"))
                SettingsGroup {
                    SettingsRow(L("Nom du volume"), hint: L("Nom affiché dans le Finder. S'il est monté, le volume est remonté.")) {
                        VStack(alignment: .leading, spacing: 0) {
                            FieldBox(text: $name, height: 26, invalid: nameError != nil, onSubmit: commitName)
                                .frame(width: 240)
                                .focused($nameFocused)
                                .onChange(of: name) { nameError = nil }
                                .onChange(of: nameFocused) { _, focused in
                                    if !focused, name.trimmingCharacters(in: .whitespaces) != drive.name { commitName() }
                                }
                                .onExitCommand {
                                    name = drive.name
                                    nameError = nil
                                    nameFocused = false
                                }
                                .accessibilityLabel(L("Nom du volume"))
                            if let nameError { FieldError(message: nameError) }
                        }
                    }
                    SettingsRow(L("Emplacement"), hint: L("Dossier où le lecteur apparaît.")) {
                        PopupMenu(title: drive.displayPath, widest: [drive.displayPath, "~/Cloud/\(drive.name)", L("Autre dossier…")]) {
                            Toggle("~/Cloud/\(drive.name)", isOn: Binding(get: { drive.settings.parentFolder == nil }, set: { if $0 { store.move(drive, to: nil) } }))
                            if drive.settings.parentFolder != nil {
                                Toggle(drive.displayPath, isOn: .constant(true))
                            }
                            Divider()
                            Button(L("Autre dossier…"), action: chooseFolder)
                        }
                    }
                }
                SectionTitle(text: L("Connexion"))
                SettingsGroup {
                    SettingsRow(drive.account, hint: "\(drive.provider.name) · \(drive.provider.connectionHint)") {
                        HStack(spacing: 6) {
                            Button(compact ? L("Modifier…") : L("Modifier la connexion…")) { actions.run(.edit, drive) }
                            if drive.provider.kind == .oauth {
                                Button(L("Reconnecter"), action: reconnect)
                            }
                        }
                        .buttonStyle(PushButtonStyle())
                    }
                    if drive.provider.type == "drive" {
                        SettingsRow(L("Clé Google"), hint: clientID.map { L("Votre propre clé (\($0.prefix(12))…), avec son propre quota chez Google.") }
                                        ?? L("Clé partagée de rclone, que Google limite souvent. Votre propre clé a son propre quota.")) {
                            Button(clientID == nil ? L("Utiliser ma clé…") : L("Modifier…")) { app.overlay = .googleKey(drive: drive.id) }
                                .buttonStyle(PushButtonStyle())
                        }
                    }
                }
                SectionTitle(text: L("Performance"))
                SettingsGroup {
                    SettingsRow(L("Profil"), hint: drive.settings.profile.hint) {
                        SegmentedControl(selection: setting(\.profile, remount: true), options: Profile.allCases) { $0.title }
                    }
                    SettingsRow(L("Taille maximale du cache"),
                                hint: MountOptions.readsBypassCache(drive.settings) ? L("Fichiers en attente d'envoi uniquement : avec macFUSE, les lectures ne passent pas par le disque.") : nil) {
                        PopupButton(selection: setting(\.cacheMaxGB, remount: true), options: [5, 20, 50, 200, 500]) { L("\($0) Go") }
                    }
                    SettingsRow(L("Limite de débit"), hint: L("Téléchargement et envoi, appliquée tout de suite.")) {
                        HStack(spacing: 6) {
                            PopupButton(selection: setting(\.limitDown), options: [0, 100, 50, 10]) { "↓ \(limitTitle($0))" }
                            PopupButton(selection: setting(\.limitUp), options: [0, 100, 50, 10]) { "↑ \(limitTitle($0))" }
                        }
                    }
                    SettingsRow(L("Options rclone"), hint: Text(MountOptions.summary(drive.settings)).font(.system(size: 11, design: .monospaced))) {
                        Button(L("Modifier…")) { app.overlay = .options(drive: drive.id) }
                            .buttonStyle(PushButtonStyle())
                    }
                }
                SectionTitle(text: L("Montage"))
                SettingsGroup {
                    SettingsRow(L("Méthode"), hint: drive.settings.method.hint) {
                        PopupButton(selection: setting(\.method, remount: true), options: MountMethod.allCases, title: \.title, isEnabled: \.isAvailable)
                    }
                    SettingsRow(L("Monter à l'ouverture de session"), hint: nil as String?) {
                        SwitchToggle(isOn: setting(\.mountAtLogin), label: L("Monter à l'ouverture de session"))
                    }
                    SettingsRow(L("Reconnecter automatiquement"), hint: L("Remonte le lecteur si rclone s'arrête de façon inattendue.")) {
                        SwitchToggle(isOn: setting(\.autoReconnect), label: L("Reconnecter automatiquement"))
                    }
                    SettingsRow(L("Lecture seule"), hint: drive.settings.readOnly ? L("Rien ne peut être créé, modifié ni supprimé sur ce lecteur.") : nil) {
                        SwitchToggle(isOn: setting(\.readOnly, remount: true), label: L("Lecture seule"))
                    }
                    SettingsRow(L("Bloquer les fichiers macOS"), hint: L("Les .DS_Store et fichiers ._ sont masqués et ne sont pas envoyés dans le cloud.")) {
                        SwitchToggle(isOn: setting(\.hideMacFiles, remount: true), label: L("Bloquer les fichiers macOS"))
                    }
                }
                SectionTitle(text: L("Outils"))
                SettingsGroup {
                    speedRow
                    SettingsRow(L("Actualiser le contenu"), hint: L("Relit la liste des fichiers sur le serveur. Dernière actualisation : \(Format.ago(drive.settings.lastRefresh)).")) {
                        Button(L("Actualiser")) { actions.run(.refresh, drive) }
                            .buttonStyle(PushButtonStyle())
                            .disabled(!drive.isMounted)
                    }
                    SettingsRow(L("Cache local"), hint: L("\(Format.gigabytes(drive.cacheBytes)) sur ce Mac.")) {
                        Button(L("Vider…")) { actions.run(.cache, drive) }
                            .buttonStyle(PushButtonStyle())
                    }
                    SettingsRow(L("Journal"), hint: L("Sortie de rclone pour ce lecteur.")) {
                        Button(L("Afficher")) { actions.run(.log, drive) }
                            .buttonStyle(PushButtonStyle())
                    }
                }
                HStack(spacing: 8) {
                    Button(L("Dupliquer")) { actions.run(.duplicate, drive) }
                        .buttonStyle(PushButtonStyle())
                    Button(L("Supprimer le lecteur…")) { actions.run(.delete, drive) }
                        .buttonStyle(PushButtonStyle(kind: .destructive))
                }
                .padding(.top, 18)
            }
        }
        .onAppear { name = drive.name }
        .onChange(of: drive.name) { _, newName in if !nameFocused { name = newName } }
        .onChange(of: app.nameFieldRequest) { nameFocused = true }
        .task(id: app.overlay == nil) {
            guard drive.provider.type == "drive", app.overlay == nil else { return }
            clientID = await store.storedClient(drive)?.id
        }
    }

    private var stats: some View {
        TileRow(spacing: 10) {
            StatTile(label: L("Lecture"), value: Format.speed(drive.readSpeed)) {
                Sparkline(values: drive.history)
                    .frame(height: 24)
                    .padding(.top, 4)
            }
            StatTile(label: L("Écriture"), value: Format.speed(drive.writeSpeed)) {
                StatSub(text: drive.uploads.isEmpty ? L("Aucun envoi en attente") : L("\(Format.plural(drive.uploads.count, "fichier")) en cours"))
            }
            StatTile(label: L("Cache"), value: Format.gigabytes(drive.cacheBytes)) {
                LevelBar(fraction: Double(drive.cacheBytes) / (Double(drive.settings.cacheMaxGB) * 1e9))
                    .padding(.top, 8)
                StatSub(text: L("sur \(drive.settings.cacheMaxGB) Go"))
            }
            let level = SpaceLevel(drive.space)
            StatTile(label: L("Espace libre"), value: level.free.map(Format.capacity) ?? "—") {
                SpaceBar(space: drive.space)
                    .padding(.top, 8)
                if let total = level.total {
                    if level.isNearlyFull {
                        Text("\(L("sur \(Format.capacity(total))")) · \(Text(L("Presque plein")).foregroundStyle(Theme.red).fontWeight(.medium))")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.text3)
                            .lineBox(11)
                    } else {
                        StatSub(text: L("sur \(Format.capacity(total))"))
                    }
                } else {
                    StatSub(text: drive.serverSilent ? L("Injoignable") : drive.spaceError != nil ? L("Illisible") : drive.space == nil ? L("Lecture en cours…") : L("Non communiqué"))
                        .help(drive.spaceError ?? "")
                }
            }
        }
    }

    private var speedRow: some View {
        let test = drive.speedTest
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 1) {
                Text(L("Tester le débit"))
                Group {
                    if let test, let speed = test.speed, let latency = test.latency {
                        Text(L("\(Format.speed(speed)) en lecture · latence \(latency) ms"))
                    } else if let error = test?.error {
                        Text(error).foregroundStyle(Theme.red)
                    } else if let test {
                        HStack(spacing: 5) {
                            ProgressView().controlSize(.mini)
                            Text(L("Test en cours… \(Int(test.progress * 100)) %")).monospacedDigit()
                        }
                    } else {
                        Text(drive.isMounted ? L("Lit 1 Go d'un fichier existant à travers le volume monté.") : L("Lit 1 Go d'un fichier existant pour mesurer le débit réel."))
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(Theme.text2)
                if let test, test.isRunning {
                    LevelBar(fraction: test.progress)
                        .frame(width: 220)
                        .padding(.top, 5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(test == nil ? L("Lancer le test") : test!.isRunning ? L("Annuler") : L("Relancer")) {
                if test?.isRunning == true { store.cancelSpeedTest(drive) } else { store.startSpeedTest(drive) }
            }
            .buttonStyle(PushButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(minHeight: 40)
    }

    /// A binding to one setting; a mounted drive is remounted right away for those rclone only reads at mount time.
    private func setting<Value: Equatable>(_ keyPath: WritableKeyPath<DriveSettings, Value>, remount: Bool = false) -> Binding<Value> {
        Binding {
            drive.settings[keyPath: keyPath]
        } set: { value in
            guard value != drive.settings[keyPath: keyPath] else { return }
            store.update(drive) { $0[keyPath: keyPath] = value }
            if remount, store.appliesLater(drive) {
                Task {
                    await store.remount(drive)
                    app.show(L("« \(drive.name) » remonté avec le nouveau réglage"))
                }
            }
        }
    }

    private func limitTitle(_ megabytes: Int) -> String {
        megabytes == 0 ? L("Illimité") : L("\(megabytes) Mo/s")
    }

    private func commitName() {
        if let error = store.rename(drive, to: name) {
            nameError = error
        } else {
            nameError = nil
            nameFocused = false
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = L("Choisir")
        panel.message = L("Le lecteur apparaîtra dans ce dossier, sous le nom « \(drive.name) ».")
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        store.move(drive, to: folder)
    }

    private func reconnect() {
        Task {
            do {
                let account = try await store.reconnect(drive)
                app.show(L("Autorisation renouvelée pour \(account)"))
            } catch is CancellationError {
            } catch {
                app.show(error.localizedDescription, warning: true)
            }
        }
    }
}
