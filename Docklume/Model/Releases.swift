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
            case .new: "Nouveautés"
            case .improved: "Améliorations"
            case .fixed: "Corrections de bogues"
            }
        }

        var filter: String {
            switch self {
            case .new: "Nouveautés"
            case .improved: "Améliorations"
            case .fixed: "Corrections"
            }
        }
    }

    var id: String { version }
    let version: String
    let date: String
    let year: Int
    var latest = false
    var security = false
    let engine: String
    let notes: [Category: [Note]]

    static let all: [Release] = [
        Release(version: "0.1", date: "7 nov. 2026", year: 2026, latest: true, engine: "rclone 1.75.2", notes: [
            .new: [
                Note(text: "Vos stockages en ligne montés comme des disques dans le Finder, avec macFUSE ou le client NFS intégré à macOS", bold: true),
                Note(text: "Moteur rclone inclus et optimisé : 16 connexions partagées entre les fichiers lus, 60 Mo/s sur un seul fichier Dropbox", bold: true),
                Note(text: "Dropbox, Google Drive, OneDrive, Box, MEGA, Proton Drive, kDrive, S3, WebDAV, SFTP, FTP, SMB, Synology, QNAP et Nextcloud"),
                Note(text: "Profils Streaming, Documents et Sauvegarde, réglés pour chaque service"),
                Note(text: "Débit en direct dans la barre des menus, page Activité et test de débit par lecteur"),
                Note(text: "Démarrage avec la session : les lecteurs se montent et l'app reste dans la barre des menus, fenêtre fermée"),
                Note(text: "Fichiers pas encore envoyés protégés : jamais effacés du cache, et une grosse copie ralentit au lieu de remplir le disque du Mac"),
                Note(text: "Reprise après une coupure d'Internet : les lectures repartent dès le retour du réseau, et un serveur qui ne répond pas ne bloque pas le Finder", bold: true),
                Note(text: "Tags et couleurs du Finder conservés sur les lecteurs macFUSE, et rassemblés dans ~/Cloud/Tags"),
                Note(text: "Google Drive avec votre propre clé Google, saisie ou importée depuis son fichier JSON"),
                Note(text: "Thème de Noël, du 1er décembre au 6 janvier ou à la demande dans Paramètres")
            ]
        ])
    ]
}
