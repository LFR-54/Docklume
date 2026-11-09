import Foundation

struct Release: Identifiable {
    struct Note {
        let text: String
        var bold = false
        var security = false
    }

    enum Category: String, CaseIterable {
        case new, improved, fixed

        var title: String {
            switch self {
            case .new: L("Nouveautés")
            case .improved: L("Améliorations")
            case .fixed: L("Corrections de bogues")
            }
        }

        var filter: String {
            switch self {
            case .new: L("Nouveautés")
            case .improved: L("Améliorations")
            case .fixed: L("Corrections")
            }
        }
    }

    var id: String { version }
    let version: String
    let day: Date
    var year: Int { Calendar(identifier: .gregorian).component(.year, from: day) }
    var date: String { Format.day(day) }
    var latest = false
    var security = false
    let engine: String
    let notes: [Category: [Note]]

    /// Built when asked for, in the app's language.
    static var all: [Release] { [
        Release(version: "0.1.1", day: day(2026, 11, 9), latest: true, engine: "rclone 1.75.2", notes: [
            .new: [
                Note(text: L("Lecteurs rangés par glisser-déposer, dans des groupes repliables à activer dans Paramètres"), bold: true),
                Note(text: L("Groupes gardés quand l'option est désactivée, retrouvés tels quels en la réactivant")),
                Note(text: L("Cache sur un disque externe : les lecteurs attendent qu'il soit branché, puis se montent d'eux-mêmes")),
                Note(text: L("Réglage Thème : Automatique, Standard ou Noël"))
            ],
            .improved: [
                Note(text: L("Espace en ligne affiché comme le compte chaque service, avec 1 To pour 1 024 Go")),
                Note(text: L("Cartes de lecteurs plus espacées, et le thème de Noël ne décale plus aucune page")),
                Note(text: L("Bonnet de Noël posé sur le dessus du logo"))
            ],
            .fixed: [
                Note(text: L("Se connecter à un service fonctionne de nouveau après avoir fermé la page du navigateur")),
                Note(text: L("Quitter Docklume pendant une connexion ou un test de débit ne laisse plus rclone tourner en arrière-plan")),
                Note(text: L("« Vider tout le cache » ne touche plus qu'aux caches des lecteurs, même dans un dossier partagé")),
                Note(text: L("Champ de renommage lisible quand le nom est sélectionné"))
            ]
        ]),
        Release(version: "0.1", day: day(2026, 11, 7), engine: "rclone 1.75.2", notes: [
            .new: [
                Note(text: L("Vos stockages en ligne montés comme des disques dans le Finder, avec macFUSE ou le client NFS intégré à macOS"), bold: true),
                Note(text: L("Moteur rclone inclus et optimisé : 16 connexions partagées entre les fichiers lus, 60 Mo/s sur un seul fichier Dropbox"), bold: true),
                Note(text: L("Dropbox, Google Drive, OneDrive, Box, MEGA, Proton Drive, kDrive, S3, WebDAV, SFTP, FTP, SMB, Synology, QNAP et Nextcloud")),
                Note(text: L("Profils Streaming, Documents et Sauvegarde, réglés pour chaque service")),
                Note(text: L("Débit en direct dans la barre des menus, page Activité et test de débit par lecteur")),
                Note(text: L("Démarrage avec la session : les lecteurs se montent et l'app reste dans la barre des menus, fenêtre fermée")),
                Note(text: L("Fichiers pas encore envoyés protégés : jamais effacés du cache, et une grosse copie ralentit au lieu de remplir le disque du Mac")),
                Note(text: L("Reprise après une coupure d'Internet : les lectures repartent dès le retour du réseau, et un serveur qui ne répond pas ne bloque pas le Finder"), bold: true),
                Note(text: L("Tags et couleurs du Finder conservés sur les lecteurs macFUSE, et rassemblés dans ~/Cloud/Tags")),
                Note(text: L("Google Drive avec votre propre clé Google, saisie ou importée depuis son fichier JSON")),
                Note(text: L("Français et anglais, selon la langue de macOS ou au choix dans Paramètres")),
                Note(text: L("Thème de Noël, du 1er décembre au 6 janvier ou à la demande dans Paramètres"))
            ]
        ])
    ] }

    private static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
}
