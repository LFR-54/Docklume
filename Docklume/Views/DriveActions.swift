import SwiftUI

enum DriveAction {
    case mount, finder, copy, refresh, web, rename, edit, duplicate, test, cache, log, delete
}

/// The drive menu's actions with their confirmations and toasts, shared by the list, the drive page and the menu bar.
@MainActor
struct DriveActions {
    let store: DriveStore
    let app: AppState

    func run(_ action: DriveAction, _ drive: Drive) {
        switch action {
        case .mount:
            if drive.isMounted || drive.state == .mounting {
                let unmount: @MainActor () -> Void = {
                    store.unmount(drive)
                    announce(drive, until: { $0.state == .unmounted }, L("« \(drive.name) » démonté"))
                }
                guard drive.pendingUploads > 0 else { return unmount() }
                app.confirm(L("Démonter « \(drive.name) » ?"),
                            message: DriveStore.unsentMessage(drive.pendingUploads),
                            confirm: L("Démonter"), action: unmount)
            } else {
                store.mount(drive)
                announce(drive, until: { $0.isMounted }, L("« \(drive.name) » monté sur \(drive.displayPath)"))
            }
        case .finder:
            store.showInFinder(drive)
        case .copy:
            store.copyPath(drive)
            app.show(L("Chemin copié : \(drive.displayPath)"))
        case .refresh:
            Task {
                do {
                    try await store.refreshContent(drive)
                    app.show(L("Contenu de « \(drive.name) » actualisé"))
                } catch {
                    app.show(error.localizedDescription, warning: true)
                }
            }
        case .web:
            store.openWeb(drive)
        case .rename:
            if app.page == .drive(drive.id) {
                app.nameFieldRequest += 1
            } else {
                app.page = .drives
                app.renaming = drive.id
            }
        case .edit:
            app.overlay = .edit(drive: drive.id)
        case .duplicate:
            let copy = store.duplicate(drive)
            app.query = ""
            app.page = .drives
            app.renaming = copy.id
        case .test:
            app.page = .drive(drive.id)
            store.startSpeedTest(drive)
        case .cache:
            let interrupted = drive.isMounted ? L(" Le volume est remonté : les lectures en cours s'interrompent.") : ""
            app.confirm(L("Vider le cache de « \(drive.name) » ?"),
                        message: L("Les fichiers lus seront retéléchargés à la prochaine lecture. Ceux qui n'ont pas encore été envoyés sont conservés.\(interrupted)"),
                        confirm: L("Vider")) {
                let before = drive.cacheBytes
                Task {
                    let kept = await store.clearCache(drive)
                    let freed = Format.gigabytes(max(0, before - drive.cacheBytes))
                    app.show(kept.files == 0 ? L("\(freed) libérés")
                             : kept.files > 1 ? L("\(freed) libérés, \(kept.files) fichiers en attente d'envoi conservés")
                             : L("\(freed) libérés, \(kept.files) fichier en attente d'envoi conservé"))
                }
            }
        case .log:
            app.overlay = .log(drive: drive.id)
        case .delete:
            let pending = store.pendingUploads(drive)
            guard pending.files == 0 else { return app.show(DriveStore.pendingMessage(drive, pending), warning: true) }
            app.confirm(L("Supprimer « \(drive.name) » ?"), message: store.deletionMessage(drive), confirm: L("Supprimer"), destructive: true) {
                let name = drive.name
                Task {
                    do {
                        try await store.delete(drive)
                        if app.page == .drive(drive.id) { app.page = .drives }
                        app.show(L("« \(name) » supprimé"))
                    } catch {
                        app.show(error.localizedDescription, warning: true)
                    }
                }
            }
        }
    }

    /// Shows "mounted on…" once a new drive's first mount has gone through.
    func announceMount(_ drive: Drive) {
        announce(drive, until: { $0.isMounted }, L("« \(drive.name) » monté sur \(drive.displayPath)"))
    }

    /// Shows the toast once the mount or unmount has gone through.
    private func announce(_ drive: Drive, until done: @escaping @MainActor (Drive) -> Bool, _ message: String) {
        Task {
            for _ in 0..<150 where !done(drive) {
                if case .failed = drive.state { return }
                try? await Task.sleep(for: .milliseconds(200))
            }
            if done(drive) { app.show(message) }
        }
    }
}

/// The drive menu of the mockup, as a native menu.
struct DriveMenuItems: View {
    let drive: Drive
    let actions: DriveActions

    var body: some View {
        Button(drive.isMounted || drive.state == .mounting ? L("Démonter") : L("Monter"), systemImage: "eject") { actions.run(.mount, drive) }
            .disabled(drive.state == .unmounting)
        Button(L("Afficher dans le Finder"), systemImage: "folder") { actions.run(.finder, drive) }
        Button(L("Copier le chemin"), systemImage: "doc.on.doc") { actions.run(.copy, drive) }
        Button(L("Actualiser le contenu"), systemImage: "arrow.clockwise") { actions.run(.refresh, drive) }
            .disabled(!drive.isMounted)
        if drive.provider.web != nil {
            Button(L("Ouvrir sur le web"), systemImage: "arrow.up.forward.square") { actions.run(.web, drive) }
        }
        Divider()
        Button(L("Renommer"), systemImage: "character.cursor.ibeam") { actions.run(.rename, drive) }
        Button(L("Modifier la connexion…"), systemImage: "pencil") { actions.run(.edit, drive) }
        Button(L("Dupliquer"), systemImage: "plus.square.on.square") { actions.run(.duplicate, drive) }
        Divider()
        Button(L("Tester le débit"), systemImage: "gauge.with.dots.needle.67percent") { actions.run(.test, drive) }
        Button(L("Vider le cache…"), systemImage: "eraser") { actions.run(.cache, drive) }
        Button(L("Afficher le journal"), systemImage: "doc.text") { actions.run(.log, drive) }
        Divider()
        Button(L("Supprimer…"), systemImage: "trash", role: .destructive) { actions.run(.delete, drive) }
    }
}
