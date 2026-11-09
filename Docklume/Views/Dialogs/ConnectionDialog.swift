import SwiftUI

/// Add a drive, or edit the connection of one: services on the left, the form on the right.
struct ConnectionDialog: View {
    private enum TestState: Equatable {
        case idle, running, succeeded(String), failed(String)
    }

    @Environment(DriveStore.self) private var store
    @Environment(AppState.self) private var app
    let editing: Drive?
    @State private var draft: ConnectionDraft
    /// The connection being edited as it was opened.
    @State private var original: ConnectionDraft?
    @State private var errors: [ConnectionDraft.Field: String] = [:]
    @AppStorage("connectionAdvancedOpen") private var advancedOpen = true
    @State private var signIn: Task<Void, Never>?
    @State private var test = TestState.idle
    @State private var saving = false
    @FocusState private var focus: ConnectionDraft.Field?
    @Environment(\.dialogSpace) private var space

    init(provider: Provider, editing: Drive?) {
        self.editing = editing
        _draft = State(initialValue: ConnectionDraft(provider: provider, name: ""))
    }

    private var provider: Provider { draft.provider }

    var body: some View {
        ModalSurface(width: 880) {
            VStack(spacing: 0) {
                ModalHead(title: editing.map { L("Modifier « \($0.name) »") } ?? L("Ajouter un nouveau lecteur"),
                          subtitle: editing == nil ? L("Montez un stockage cloud, un NAS ou un serveur comme un disque dans le Finder.")
                                                   : L("Les changements s'appliquent à l'enregistrement : un volume monté est remonté."),
                          close: close)
                HStack(alignment: .top, spacing: 14) {
                    providerList
                        .frame(width: space.width < 900 ? 230 : 270)
                    form
                }
                .frame(height: min(560, max(300, space.height - 200)))
                .padding(.horizontal, 18)
                footer
            }
        }
        .task(load)
        .onChange(of: draft) { test = .idle }
        .onChange(of: draft.client) {
            // A token obtained with another key would not refresh.
            draft.token = nil
            draft.authorizedAccount = nil
            errors[.client] = nil
        }
        .onDisappear { signIn?.cancel() }
    }

    // MARK: Services

    private var providerList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Provider.all) { item in
                        ProviderItem(provider: item, selected: item.id == provider.id) {
                            if item.id != provider.id { select(item) }
                        }
                        .disabled(editing != nil && item.id != provider.id)
                        .opacity(editing != nil && item.id != provider.id ? 0.38 : 1)
                        .id(item.id)
                    }
                }
                .padding(5)
            }
            .card()
            .onAppear { proxy.scrollTo(provider.id) }
        }
    }

    // MARK: Form

    /// The sign-in button while the browser has the page; clicking it again opens a new one.
    private var waitingForBrowser: some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.small)
            Text(L("En attente du navigateur…"))
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    ProviderTile(provider: provider, size: 54)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(provider.name).font(.system(size: 18, weight: .semibold)).lineBox(18)
                        Text(intro).foregroundStyle(Theme.text2).fixedSize(horizontal: false, vertical: true).lineBox(13)
                    }
                }
                .padding(.bottom, 18)
                row(L("Nom du volume"), error: errors[.name]) {
                    FieldBox(text: $draft.name, invalid: errors[.name] != nil).focused($focus, equals: .name)
                }
                fields
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { advancedOpen.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .rotationEffect(.degrees(advancedOpen ? 0 : -90))
                        Text(L("Options avancées")).fontWeight(.medium)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.bottom, 6)
                if advancedOpen { advanced }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .card()
    }

    @ViewBuilder private var fields: some View {
        switch provider.kind {
        case .oauth:
            if provider.type == "drive" && editing == nil { googleKey }
            row(L("Compte"), error: errors[.signIn]) {
                if draft.token != nil || (editing != nil && draft.authorizedAccount != nil) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.green)
                        Text(draft.authorizedAccount ?? L("Compte \(provider.name)")).lineLimit(1)
                        Button(action: startSignIn) {
                            if signIn != nil { waitingForBrowser } else { Text(L("Changer de compte…")) }
                        }
                        .buttonStyle(PushButtonStyle())
                    }
                    .frame(height: 30)
                } else {
                    Button(action: startSignIn) {
                        if signIn != nil { waitingForBrowser } else { Text(L("Se connecter à \(provider.name)…")) }
                    }
                    .buttonStyle(PushButtonStyle(height: 30))
                }
            }
            if draft.token == nil && editing == nil {
                Text(signIn == nil ? L("Votre navigateur s'ouvre pour autoriser Docklume.") : L("Page fermée ? Cliquez de nouveau pour la rouvrir."))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.text2)
                    .padding(.leading, 142)
                    .padding(.bottom, 10)
            }
        case .login:
            row(L("Adresse e-mail"), error: errors[.email]) {
                FieldBox(text: $draft.email, placeholder: "nom@exemple.fr", invalid: errors[.email] != nil).focused($focus, equals: .email)
            }
            row(L("Mot de passe"), error: errors[.password]) {
                FieldBox(text: $draft.password, placeholder: editing == nil ? L("Mot de passe") : L("Inchangé"), secure: true,
                         invalid: errors[.password] != nil).focused($focus, equals: .password)
            }
            row(L("Code 2FA")) { FieldBox(text: $draft.twoFactor, placeholder: L("Facultatif")) }
        case .s3:
            row(L("Point d'accès"), error: errors[.endpoint]) {
                FieldBox(text: $draft.endpoint, placeholder: "https://s3.eu-central-1.amazonaws.com", invalid: errors[.endpoint] != nil)
                    .focused($focus, equals: .endpoint)
            }
            row("Bucket", error: errors[.bucket]) {
                FieldBox(text: $draft.bucket, placeholder: "mon-bucket", invalid: errors[.bucket] != nil).focused($focus, equals: .bucket)
            }
            row(L("Clé d'accès"), error: errors[.accessKey]) {
                FieldBox(text: $draft.accessKey, placeholder: "AKIA…", invalid: errors[.accessKey] != nil).focused($focus, equals: .accessKey)
            }
            row(L("Clé secrète"), error: errors[.secretKey]) {
                FieldBox(text: $draft.secretKey, placeholder: editing == nil ? L("Clé secrète") : L("Inchangée"), secure: true,
                         invalid: errors[.secretKey] != nil).focused($focus, equals: .secretKey)
            }
        case .server:
            row(L("Adresse"), error: errors[.address]) {
                HStack(spacing: 8) {
                    FieldBox(text: $draft.address, placeholder: provider.hostPlaceholder, invalid: errors[.address] != nil)
                        .focused($focus, equals: .address)
                    Text(":")
                    FieldBox(text: $draft.port).frame(width: 80).accessibilityLabel("Port")
                }
            }
            row(L("Chemin d'accès")) { FieldBox(text: $draft.path, placeholder: L("Chemin distant (facultatif)")) }
            row(L("Compte")) {
                FieldBox(text: $draft.user, placeholder: L("Nom d'utilisateur")).disabled(draft.anonymous)
            }
            row(L("Mot de passe")) {
                FieldBox(text: $draft.password, placeholder: editing == nil ? L("Mot de passe") : L("Inchangé"), secure: true).disabled(draft.anonymous)
            }
            check(L("Anonyme"), $draft.anonymous)
                .padding(.leading, 142)
        }
    }

    /// Before the sign-in, since the token must come from the key the drive keeps.
    @ViewBuilder private var googleKey: some View {
        check(L("Utiliser ma propre clé Google"), Binding { draft.client != nil } set: { draft.client = $0 ? OAuthClient() : nil })
            .padding(.leading, 142)
            .padding(.top, -4)
            .padding(.bottom, draft.client == nil ? 6 : 4)
        if draft.client != nil {
            VStack(alignment: .leading, spacing: 0) {
                GoogleKeyFields(client: Binding { draft.client ?? OAuthClient() } set: { draft.client = $0 },
                                labelWidth: 130, invalid: errors[.client] != nil) { errors[.client] = $0 }
                if let error = errors[.client] {
                    FieldError(message: error).padding(.leading, 142)
                }
            }
            .padding(.bottom, 12)
        }
    }

    private var advanced: some View {
        VStack(alignment: .leading, spacing: 0) {
            row(L("Profil")) {
                SegmentedControl(selection: $draft.profile, options: Profile.allCases, title: \.title)
            }
            row(L("Méthode")) {
                let method = PopupButton(selection: $draft.method, options: MountMethod.allCases, title: \.title, isEnabled: \.isAvailable)
                let timeout = HStack(spacing: 8) {
                    Text(L("Délai d'expiration"))
                    FieldBox(text: $draft.timeout).frame(width: 56).accessibilityLabel(L("Délai d'expiration"))
                    Text(L("secondes"))
                }
                .frame(height: 30)
                // On one line, or the timeout below the method when the dialog is narrow.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        method
                        timeout.padding(.leading, 12)
                    }
                    .frame(height: 30)
                    .fixedSize()
                    VStack(alignment: .leading, spacing: 10) {
                        method.frame(height: 30)
                        timeout.fixedSize()
                    }
                }
            }
            check(L("Monter à l'ouverture de session"), $draft.mountAtLogin)
                .padding(.top, 4.5)
            check(L("Lecture seule"), $draft.readOnly)
            if provider.kind == .server && provider.type != "sftp" {
                check(L("Ignorer les erreurs de certificat"), $draft.skipCertificateCheck)
            }
            if editing == nil {
                check(L("Chiffrer les fichiers avant l'envoi (rclone crypt)"), $draft.encrypt)
                if draft.encrypt {
                    row(L("Phrase secrète"), error: errors[.encryptionPassword]) {
                        FieldBox(text: $draft.encryptionPassword, placeholder: L("Gardez-la en lieu sûr : sans elle, les fichiers sont illisibles"),
                                 secure: true, invalid: errors[.encryptionPassword] != nil)
                            .focused($focus, equals: .encryptionPassword)
                    }
                }
            }
        }
        .padding(.top, 12)
        .overlay(alignment: .top) { Hairline() }
    }

    private func row<Content: View>(_ label: String, error: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .frame(width: 130, height: 30, alignment: .leading)
            VStack(alignment: .leading, spacing: 0) {
                content()
                if let error { FieldError(message: error) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, 10)
    }

    /// Checkbox rows 27 pt apart: the mockup's 9 pt margins collapse between neighbours.
    private func check(_ label: String, _ isOn: Binding<Bool>) -> some View {
        Toggle(label, isOn: isOn)
            .toggleStyle(.checkbox)
            .frame(minHeight: 18)
            .padding(.vertical, 4.5)
    }

    private var intro: String {
        switch provider.kind {
        case .oauth: L("Connectez votre compte \(provider.name) dans le navigateur, puis montez-le comme un disque.")
        case .login: L("Montez votre espace \(provider.name) comme un disque.")
        case .s3: L("Montez un bucket compatible S3 comme un disque.")
        case .server: L("Montez un serveur \(provider.name) comme un disque.")
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Button(L("Tester la connexion"), action: runTest)
                    .buttonStyle(PushButtonStyle.large)
                    .disabled(test == .running || saving)
                Group {
                    switch test {
                    case .idle:
                        EmptyView()
                    case .running:
                        HStack(spacing: 5) {
                            ProgressView().controlSize(.small)
                            Text(L("Test en cours…"))
                        }
                    case .succeeded(let message):
                        Label(message, systemImage: "checkmark.circle").foregroundStyle(Theme.green)
                    case .failed(let message):
                        Text(message).foregroundStyle(Theme.red).lineLimit(2)
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.text2)
            }
            Spacer(minLength: 10)
            Button(L("Annuler"), action: close)
                .buttonStyle(PushButtonStyle.large)
            Button(action: submit) {
                if saving {
                    ProgressView().controlSize(.small).tint(.white)
                } else {
                    Text(editing == nil ? L("Connecter") : L("Enregistrer"))
                }
            }
            .buttonStyle(PushButtonStyle.largePrimary)
            .keyboardShortcut(.defaultAction)
            .disabled(saving)
        }
        .padding(.top, 16)
        .padding(.horizontal, 22)
        .padding(.bottom, 20)
    }

    // MARK: Actions

    @Sendable private func load() async {
        if let editing {
            draft = ConnectionDraft(drive: editing, stored: await store.storedParameters(editing))
            original = draft
        } else {
            startNewDrive()
        }
    }

    /// Another service in the same dialog, so it changes in place instead of closing and opening again.
    private func select(_ item: Provider) {
        signIn?.cancel()
        signIn = nil
        errors = [:]
        focus = nil
        draft = ConnectionDraft(provider: item, name: "")
        startNewDrive()
    }

    /// The name, profile and mount method a new drive of the chosen service starts with.
    private func startNewDrive() {
        draft.name = store.freeName(provider.name)
        draft.profile = provider.type == "dropbox" ? .streaming : store.preferences.defaultProfile
        draft.method = store.preferences.defaultMethod.isAvailable ? store.preferences.defaultMethod : .nfs
        test = .idle
    }

    private func close() {
        signIn?.cancel()
        app.overlay = nil
    }

    private func startSignIn() {
        errors[.signIn] = nil
        if let error = draft.client?.googleError {
            errors[.client] = error
            return
        }
        // Asked again, after the browser page was closed for instance: the sign-in still waiting holds rclone's
        // sign-in port, 127.0.0.1:53682, until its process has ended.
        let previous = signIn
        previous?.cancel()
        signIn = Task {
            await previous?.value
            do {
                let client = if let editing { await store.storedClient(editing) } else { draft.client?.trimmed }
                let (token, account) = try await store.authorize(provider, client: client)
                draft.token = token
                draft.authorizedAccount = account ?? L("Compte \(provider.name)")
            } catch is CancellationError {
            } catch {
                errors[.signIn] = error.localizedDescription
            }
            // A sign-in replaced by another leaves the button to it.
            if !Task.isCancelled { signIn = nil }
        }
    }

    private func validate(includeName: Bool) -> Bool {
        var found = draft.errors(editing: editing != nil)
        if includeName, let error = store.nameError(draft.name, except: editing?.id) { found[.name] = error }
        errors = found
        if found[.encryptionPassword] != nil { advancedOpen = true }
        let order: [ConnectionDraft.Field] = [.name, .email, .password, .endpoint, .bucket, .accessKey, .secretKey, .address, .encryptionPassword]
        focus = order.first { found[$0] != nil }
        return found.isEmpty
    }

    private func runTest() {
        guard validate(includeName: false) else { return }
        test = .running
        let snapshot = draft
        Task {
            do {
                let message = try await store.testConnection(snapshot, editing: editing)
                if draft == snapshot { test = .succeeded(message) }
            } catch {
                if draft == snapshot { test = .failed(error.localizedDescription) }
            }
        }
    }

    private func submit() {
        guard validate(includeName: true) else { return }
        saving = true
        Task {
            do {
                // A connection is tried before it is saved, unless it is unchanged or was just tested: rclone mounts
                // a WebDAV address that leads nowhere as an empty volume.
                let tested = if case .succeeded = test { true } else { false }
                if !tested, editing == nil || draft.parameters != original?.parameters {
                    test = .running
                    test = .succeeded(try await store.testConnection(draft, editing: editing))
                }
                if let editing {
                    try await store.updateConnection(editing, with: draft)
                    app.overlay = nil
                    app.show(L("Modifications de « \(editing.name) » enregistrées"))
                } else {
                    let drive = try await store.addDrive(draft)
                    app.overlay = nil
                    app.query = ""
                    app.page = .drives
                    DriveActions(store: store, app: app).announceMount(drive)
                }
            } catch {
                test = .failed(error.localizedDescription)
            }
            saving = false
        }
    }
}

private struct ProviderItem: View {
    let provider: Provider
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Hovering { hovering in
                HStack(spacing: 12) {
                    ProviderTile(provider: provider, size: 32)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(provider.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(selected ? .white : Theme.text)
                            .lineBox(14)
                        Text(provider.subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(selected ? .white.opacity(0.8) : Theme.text2)
                            .lineBox(12)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(selected ? Theme.accent : hovering ? Theme.hover : .clear,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
