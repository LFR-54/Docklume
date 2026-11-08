import Foundation

// Texts, plurals, units and dates in both languages, with the values put back in the order of the English text.
var failures = 0
@MainActor func check(_ got: String, _ expected: String) {
    print(got == expected ? "ok    \(got)" : "ÉCHEC \(got) ≠ \(expected)")
    if got != expected { failures += 1 }
}

Lang.use(.french)
check(L("\(3) fichiers n'ont pas fini d'être envoyés. L'envoi reprendra au prochain montage du lecteur."),
      "3 fichiers n'ont pas fini d'être envoyés. L'envoi reprendra au prochain montage du lecteur.")
check(Format.plural(0, "lecteur"), "0 lecteur")
check(Format.plural(2, "lecteur"), "2 lecteurs")
check(Format.speed(64_000_000), "64,0 Mo/s")
check(Format.capacity(1_310_000_000_000), "1,31 To")
check(L("Test en cours… \(42) %"), "Test en cours… 42 %")

Lang.use(.english)
check(L("\(3) fichiers n'ont pas fini d'être envoyés. L'envoi reprendra au prochain montage du lecteur."),
      "3 files have not finished uploading. The upload will resume the next time the drive is mounted.")
check(L("« \("Médiathèque") » monté sur \("~/Cloud/Médiathèque")"), "“Médiathèque” mounted at ~/Cloud/Médiathèque")
check(Format.plural(0, "lecteur"), "0 drives")
check(Format.plural(1, "fichier"), "1 file")
check(Format.speed(64_000_000), "64.0 MB/s")
check(Format.speed(320_000), "320 kB/s")
check(Format.capacity(620_000_000_000), "620 GB")
check(L("Test en cours… \(42) %"), "Testing… 42%")
check(L("À partir de 90 % d'occupation."), "From 90% full.")
check(L("Importer \(Format.plural(3, "remote")) ?"), "Import 3 remotes?")
check(Format.day(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 7, hour: 12))!), "Nov 7, 2026")
check(Localized.fill("%2$@ then %1$@", with: ["a", "b"]), "b then a")

exit(failures == 0 ? 0 : 1)
