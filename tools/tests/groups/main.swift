import Foundation

// Order and groups of the drives page: moves, groups made, renamed, folded and deleted, and nothing lost while the
// groups are hidden. No catalog: the store keeps it all in memory.
var failures = 0
@MainActor func check(_ got: String, _ expected: String, _ what: String) {
    print(got == expected ? "ok    \(what)" : "ÉCHEC \(what) : \(got) ≠ \(expected)")
    if got != expected { failures += 1 }
}

MainActor.assumeIsolated {
    let defaults = UserDefaults(suiteName: "docklume.groups.test")!
    defaults.removePersistentDomain(forName: "docklume.groups.test")
    let preferences = Preferences(defaults: defaults, openAtLogin: false)
    let drives = ["A", "B", "C", "D"].map { Drive(record: DriveRecord(remote: $0.lowercased(), name: $0, provider: "webdav")) }
    let store = DriveStore(showing: drives, preferences: preferences, engineVersion: "test")
    let (a, b, c, d) = (drives[0], drives[1], drives[2], drives[3])
    @MainActor func order() -> String { store.orderedDrives.map { $0.name }.joined() }
    @MainActor func sections() -> String {
        store.sections.map { section in "\(section.group?.name ?? "-"):\(section.drives.map { $0.name }.joined())" }.joined(separator: " ")
    }

    store.move(d, to: a, after: false)
    check(order(), "DABC", "glissé avant le premier")
    store.move(d, to: c, after: true)
    check(order(), "ABCD", "glissé après le dernier")

    preferences.showGroups = true
    let media = store.addGroup(with: c)
    check(media.name, "Nouveau groupe", "nom d'un nouveau groupe")
    check(store.addGroup().name, "Nouveau groupe 2", "deuxième nouveau groupe")
    check(store.renameGroup(store.groups[1].id, to: "nouveau GROUPE") ?? "", "Un groupe porte déjà ce nom.", "nom déjà pris refusé")
    check(store.renameGroup(media.id, to: "  Médias ") ?? "accepté", "accepté", "renommé")
    let work = store.groups[1]
    store.renameGroup(work.id, to: "Travail")
    check(sections(), "Médias:C Travail: -:ABD", "lecteur placé dans un nouveau groupe")

    store.move(a, to: c, after: true)
    check(sections(), "Médias:CA Travail: -:BD", "glissé dans le groupe d'un autre lecteur")
    store.move(d, toGroup: work.id)
    store.move(b, toGroup: work.id)
    check(sections(), "Médias:CA Travail:DB -:", "déposé sur un groupe, en dernier")
    store.moveGroup(work.id, to: media.id, after: false)
    check(sections(), "Travail:DB Médias:CA -:", "groupe déplacé")
    store.setCollapsed(work.id, true)
    check("\(store.groups[0].collapsed)", "true", "groupe replié")

    preferences.showGroups = false
    check(order(), "CADB", "groupes masqués : l'ordre de la liste")
    store.move(b, to: c, after: false)
    check(b.record.group ?? "", work.id, "groupes masqués : un lecteur glissé garde son groupe")
    preferences.showGroups = true
    check(sections(), "Travail:BD Médias:CA -:", "groupes réaffichés, avec l'ordre changé entre-temps")

    store.deleteGroup(media.id)
    check(sections(), "Travail:BD -:CA", "groupe supprimé, ses lecteurs restent")
    check(store.orderedDrives.map { $0.name }.joined(), "BDCA", "panneau dans l'ordre de la page")

    // A drives.json written before the groups has no "group" key, as a drive without one is written now.
    let old = try! JSONEncoder().encode(DriveRecord(remote: "r", name: "N", provider: "webdav"))
    let decoded = try? JSONDecoder().decode(DriveRecord.self, from: old)
    check("\(!String(decoding: old, as: UTF8.self).contains("group")) \(decoded != nil) \(decoded?.group == nil)", "true true true",
          "drives.json sans groupe lu")

    defaults.removePersistentDomain(forName: "docklume.groups.test")
    exit(failures == 0 ? 0 : 1)
}
