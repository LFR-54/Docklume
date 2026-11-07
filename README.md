<p align="center">
  <img src="docs/images/icon.png" width="128" height="128" alt="">
</p>

<h1 align="center">Docklume</h1>

<p align="center">
  <b>Vos stockages en ligne, montés comme des disques dans le Finder.</b>
</p>

<p align="center">
  <a href="https://github.com/LFR-54/Docklume/releases/latest"><img alt="Dernière version" src="https://img.shields.io/github/v/release/LFR-54/Docklume?label=version&color=0A84FF"></a>
  <img alt="macOS 15 ou plus récent, Apple Silicon" src="https://img.shields.io/badge/macOS-15%2B%20·%20Apple%20Silicon-111?logo=apple&logoColor=white">
  <a href="LICENSE"><img alt="Licence MIT" src="https://img.shields.io/badge/licence-MIT-2EA44F"></a>
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/drives-dark.png">
    <img src="docs/images/drives-light.png" width="920" alt="Fenêtre principale de Docklume : cinq lecteurs, dont une médiathèque Dropbox lue à 104 Mo/s">
  </picture>
</p>

Docklume transforme chaque compte en ligne en un lecteur du Finder, comme RaiDrive sous Windows. L'app est native et embarque une version optimisée de [rclone](https://rclone.org).

## Points forts

- **Rapide.** 60 Mo/s sur un seul fichier Dropbox, et la ligne saturée dès que plusieurs fichiers sont lus.
- **Simple à monter.** Avec macFUSE, ou avec le client NFS intégré à macOS, sans rien installer.
- **Discret.** Docklume démarre avec la session et reste dans la barre des menus, avec le débit en direct.
- **Sûr.** Les fichiers pas encore envoyés ne sont jamais effacés, et une grosse copie ralentit au lieu de remplir le disque.
- **Solide.** Après une coupure d'Internet, les lectures repartent seules, et un serveur qui ne répond pas ne bloque pas le Finder.
- **Privé.** Aucun serveur, aucune télémétrie : vos identifiants restent dans `rclone.conf`, sur votre Mac.

**Services :** Dropbox, Google Drive, OneDrive, Box, MEGA, Proton Drive, kDrive, compatibles S3, WebDAV, SFTP, FTP, SMB, Synology, QNAP, Nextcloud.

## En images

<table>
  <tr>
    <td width="50%" align="center" valign="top">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/detail-dark.png">
  <img src="docs/images/detail-light.png" alt="Fiche d'un lecteur">
</picture>
      <p align="center"><b>Fiche du lecteur</b><br><sub>Profil, cache, limite de débit et méthode de montage, lecteur par lecteur</sub></p>
    </td>
    <td width="50%" align="center" valign="top">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/activity-dark.png">
  <img src="docs/images/activity-light.png" alt="Page Activité">
</picture>
      <p align="center"><b>Activité</b><br><sub>Le débit des 60 dernières secondes et les envois en cours</sub></p>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center" valign="top">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/add-dark.png">
  <img src="docs/images/add-light.png" alt="Ajout d'un lecteur">
</picture>
      <p align="center"><b>Ajout d'un lecteur</b><br><sub>Choisissez le service, connectez-vous dans le navigateur</sub></p>
    </td>
    <td width="50%" align="center" valign="top">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/panel-dark.png">
  <img src="docs/images/panel-light.png" width="300" alt="Panneau de la barre des menus">
</picture>
      <p align="center"><b>Barre des menus</b><br><sub>Débit, lecteurs et envois, sans ouvrir la fenêtre</sub></p>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center" valign="top">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/settings-dark.png">
  <img src="docs/images/settings-light.png" alt="Paramètres">
</picture>
      <p align="center"><b>Paramètres</b><br><sub>Ouverture de session, notifications, cache et moteur</sub></p>
    </td>
    <td width="50%" align="center" valign="top">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/notes-dark.png">
  <img src="docs/images/notes-light.png" alt="Notes de version">
</picture>
      <p align="center"><b>Notes de version</b><br><sub>Les nouveautés de chaque version, dans l'app</sub></p>
    </td>
  </tr>
</table>

## Installer

1. Téléchargez `Docklume-0.1.zip` depuis la [dernière version](https://github.com/LFR-54/Docklume/releases/latest), ouvrez-le et glissez Docklume dans Applications.
2. Au premier lancement, macOS bloque l'app, qui n'est pas encore notariée par Apple. Ouvrez **Réglages Système › Confidentialité et sécurité**, puis cliquez sur **Ouvrir quand même**.
3. Pour monter avec macFUSE, installez [macFUSE](https://macfuse.github.io) et autorisez son extension (sur Apple Silicon, macOS demande de passer en sécurité réduite). Sans macFUSE, choisissez **NFS intégré** dans la fiche du lecteur.

Il faut macOS 15 ou plus récent, sur un Mac Apple Silicon.

> **Google Drive** : la clé partagée de rclone est souvent limitée par Google. Créez votre propre clé, gratuite, en suivant le [guide de rclone](https://rclone.org/drive/#making-your-own-client-id), puis ajoutez-la dans la fiche du lecteur, **Clé Google › Utiliser ma clé…**

## Compiler

Il faut Xcode 26 ou plus récent, [Go](https://go.dev/dl/) 1.26 et macFUSE 5.

```bash
git clone https://github.com/LFR-54/Docklume.git && cd Docklume
scripts/build-rclone.sh
xcodebuild -project Docklume.xcodeproj -scheme Docklume -configuration Release -derivedDataPath build/DerivedData build
```

`build-rclone.sh` télécharge rclone 1.75.2 et lui applique les correctifs de [`rclone-patches/`](rclone-patches). L'app se trouve ensuite dans `build/DerivedData/Build/Products/Release`.

## Licence

Docklume est sous [licence MIT](LICENSE), comme rclone et ses correctifs. macFUSE n'est pas inclus. [Règles de confidentialité](https://lfr-54.github.io/Docklume/confidentialite.html).

Les logos des services appartiennent à leurs propriétaires et servent seulement à les reconnaître. Ils viennent de [Wikimedia Commons](https://commons.wikimedia.org) : celui de Nextcloud vient d'openDesk (Apache 2.0), les autres sont dans le domaine public. L'icône de kDrive est © Infomaniak, redessinée d'après [ios-kDrive](https://github.com/Infomaniak/ios-kDrive) (GPL-3.0).
