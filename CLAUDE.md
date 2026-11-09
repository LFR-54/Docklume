# Docklume

App macOS native (SwiftUI, macOS 15+, Apple Silicon) qui monte des stockages cloud comme disques dans le Finder, à la
manière de RaiDrive sous Windows, avec un rclone patché inclus. Priorité au débit, puis à une interface native.
S'appelait CloudShelf au début : le nom était une marque déposée par d'autres. La numérotation est repartie à 0.1 avec
la première release GitHub ; l'historique d'avant n'est plus dans les notes de version.

## Règles de travail

- Tout ce que lit l'utilisateur est en français : messages, récapitulatifs, questions, boutons, étapes de tâches.
  Le code, ses commentaires et les messages de commit restent en anglais.
- Pas de remplissage : réponses denses et factuelles, commentaires seulement quand l'intention n'est pas évidente,
  textes d'interface courts, ton Apple.
- Committer ou pousser seulement à la demande.
- Interface : garder la disposition de `design/maquette.html` (barre latérale de navigation, liste de cartes de
  lecteurs, fenêtre d'ajout en deux colonnes), à l'échelle 1 px CSS = 1 pt. La variante qui listait les lecteurs dans
  la barre latérale (`maquette-v2.html`) a été refusée. Le panneau de la barre des menus ouvre ou monte un lecteur,
  sans jamais le démonter. Les notes de version suivent la frise de raidrive.com/release-notes. Logo officiel :
  `design/logo-docklume-2048.png`.
- Quitter, recompiler ou relancer l'app de l'utilisateur démonte ses lecteurs : vérifier, puis demander avant.
  - Envois en attente : `grep -rlE '"Dirty": ?true' ~/Library/Caches/Docklume/*/vfsMeta` (rclone écrit
    `"Dirty": true` avec une espace). Fichiers ouverts : `lsof -n | grep ~/Cloud/`, jamais `lsof +D`, qui parcourt
    tout le lecteur par le réseau.
  - Relance : `osascript -e 'tell application id "fr.docklume.Docklume" to quit'`, le build Xcode ci-dessous, puis
    `open build/DerivedData/Build/Products/Debug/Docklume.app`. L'ouverture de session pointe sur cette app :
    ne pas supprimer `build/`.
- Ne jamais monter en macFUSE un serveur qui ne répond pas, même pour un test : le montage ne finit jamais, et
  `mount`, `diskutil`, `diskarbitrationd` et le Finder restent bloqués une quinzaine de minutes. Tester un serveur
  muet sous le montage (`Reachability`, `rclone about` à délais courts, `tools/tests/reach`). Lister les montages
  par getfsstat MNT_NOWAIT plutôt que `/sbin/mount`, qui attend un montage bloqué.
- Rien ne s'anime en continu : la moindre animation fait redessiner la fenêtre par le serveur graphique, 25 % d'un
  cœur à 72 Hz et encore 10 % à 30 images par seconde. Les décors se dessinent une fois.
- Écrire dans le cloud de l'utilisateur seulement avec son accord, dans un dossier de test, purgé ensuite vers la
  corbeille du service.
- Captures publiées (README, site) : comptes de démo uniquement, jamais de vrais e-mails ni identifiants.
- Ne jamais afficher ni committer `rclone.conf` (jetons, clé Google).
- Benchmarks et montages de test : délai dur (`perl -e 'alarm 120; exec @ARGV' …`), un point de montage par essai.

## Compiler

1. Moteur : `scripts/build-rclone.sh` (Go dans `~/.local/go` ou le PATH, macFUSE installé). Clone rclone v1.75.2
   dans `rclone/`, applique `rclone-patches/`, produit `build/rclone/rclone` en version `v1.75.2-docklume.N`
   (docklume.9 aujourd'hui). Incrémenter `BUILD` quand un patch change. Un patch se fait dans `rclone/`, se teste
   avec `go test` sur son paquet, puis s'enregistre par `git diff` (`git add -N` pour les fichiers nouveaux) avant
   de relancer le script, qui remet `rclone/` à zéro.
2. App : `xcodebuild -project Docklume.xcodeproj -scheme Docklume -configuration Debug -derivedDataPath build/DerivedData build`.
   La phase « Embed rclone » copie le moteur dans `Contents/MacOS` (supprimer puis copier : macOS tue un binaire signé
   réécrit sur place).
3. Vérification rapide sans Xcode : `swiftc -Onone` sur les sources, comme dans `tools/` (environ 15 s).

`build/` et `rclone/` sont ignorés par git. L'app est signée ad hoc (`CODE_SIGN_IDENTITY "-"`) : chaque build est une
nouvelle app pour macOS, qui redemande l'accès aux volumes réseau. Signature Apple Development et notarisation : pas
encore faites.

## Organisation

- `App/` : `DocklumeApp` (l'AppDelegate possède DriveStore et AppState, gère Dock, barre des menus et ouverture de
  session), `FormerName` (reprise unique des données de CloudShelf).
- `Engine/` : `Rclone` (trouve le moteur, inclus d'abord), `MountSession` (un process `rclone mount` ou `nfsmount` par
  lecteur, rc sur 127.0.0.1 avec identifiants par variables d'environnement, arrêt, reprise des orphelins),
  `RemoteControl`, `CacheFolder` (purge et déplacement qui gardent les fichiers pas encore envoyés et `finderMeta`),
  `DiskSpace`, `SpeedProbe`, `TagShortcuts`, `Accounts`, `NetworkWatch` (changements de réseau de macOS),
  `Reachability` (le serveur d'un lecteur répond-il, avant de lancer rclone).
- `Model/` : `Drive` (état, et `MountOptions` : tous les drapeaux rclone avec leurs mesures en commentaire),
  `DriveStore` (catalogue, montages, protection du disque), `Provider`, `Preferences`, `ConnectionDraft`,
  `OAuthClient`, `Releases` (notes de version affichées dans l'app).
- `Views/` : `Theme` (jetons), `Controls` (contrôles maison), `MainWindow`, `Pages/`, `Dialogs/`, `MenuBarPanel`,
  `Christmas` (thème de Noël).
- Données : `~/Library/Application Support/Docklume/drives.json`, `~/Library/Caches/Docklume/<id>` (cache VFS et
  `finderMeta`), `~/Library/Logs/Docklume/<id>.log`. Montages dans `~/Cloud/<nom>`. Au premier lancement, les remotes
  de `rclone.conf` sont importés en lecture seule ; ceux créés par l'app y sont écrits et supprimés avec leur dernier
  lecteur.
- Ordre et groupes : l'ordre de `drives.json` est celui de la page, changé par glisser-déposer des cartes. Les groupes
  (nom, ordre, replié) sont dans `groups.json` à côté, et chaque lecteur garde l'ID du sien (`DriveRecord.group`).
  Le réglage `showGroups` (Paramètres, menu Présentation) ne fait que les afficher ou non : désactivé, rien ne se
  perd, et un lecteur glissé garde son groupe. Le panneau et Activité suivent l'ordre de la page (`orderedDrives`).
  `tools/tests/run.sh` vérifie ces déplacements (test `groups`).

## Langues

- L'app est écrite en français et traduite en anglais. Tout texte affiché passe par `L("…")` (`Model/Language.swift`),
  qui donne l'anglais de `Model/English.swift` ; la clé est le texte français avec `%@` pour chaque valeur et `%%`
  pour un signe pour cent. Un texte qui contient un `Text` mis en forme passe par `Text(composing:)`.
- Réglage `language` des Paramètres (Système, 🇫🇷 Français, 🇬🇧 English) : la fenêtre et le panneau se redessinent
  aussitôt (`.id` sur la langue), sans relance ni démontage. Il est aussi écrit en `AppleLanguages` de l'app, pour
  les menus de macOS au lancement suivant ; Système le retire.
- Pas d'accord par interpolation (`\(n > 1 ? "s" : "")`) : une phrase au singulier et une au pluriel, ou
  `Format.plural`. Les valeurs enregistrées (`Profile`, `MountMethod`, `AppTheme`) gardent leur `rawValue`
  français et s'affichent par `title`. Unités : Mo/Go/To en français, MB/GB/TB en anglais (`Format.unit`).
  L'espace du cloud se compte en puissances de 1024 comme les services (`Format.capacity` : un forfait de 2 To =
  2 × 1024⁴ octets), les fichiers du Mac en puissances de 1000 comme le Finder (`Format.fileSize`, `Format.gigabytes`).
- Après un texte ajouté ou changé : `python3 -I tools/l10n/check.py` liste les textes sans anglais, les entrées en
  double (plantage au lancement) et les valeurs qui ne correspondent pas.
- GitHub : `README.md` en anglais, `README.fr.md` en français ; site en anglais dans `docs/`, en français dans
  `docs/fr/` ; `confidentialite.html` reste à cette adresse (écran de consentement Google), `privacy.html` en anglais.

## Patches rclone (`rclone-patches/`)

| Patch | Rôle |
|---|---|
| 0001 | `--vfs-read-chunk-streams-total` : 16 flux partagés entre les fichiers lus (Dropbox refuse plus d'environ 16 téléchargements simultanés par compte) |
| 0002 | rc `core/downloaded` : octets réellement reçus, pour le débit en lecture (`core/stats` ne bouge que quand l'app lit) |
| 0003 | macFUSE : attributs étendus acceptés au lieu de ENOSYS, sinon copier un fichier téléchargé ou tagué échoue (EPERM) |
| 0004 | NFS : `._*` et `.DS_Store` gardés en mémoire, jamais envoyés |
| 0005 | macFUSE : idem, et `noappledouble` retiré (erreur Finder -8062 sur la copie d'un dossier) |
| 0006 | VFS : une écriture attend quand le disque est bas et que des envois sont en attente (sinon disque plein, erreur -36) |
| 0007 | VFS : fermer un fichier avant la fin n'est plus une erreur (« stream abandoned ») |
| 0008 | macFUSE : tags, FinderInfo et commentaires du Finder gardés dans `<cache>/finderMeta` |
| 0009 | Réseau : une connexion muette est lâchée en 25 s au lieu de 5 min (contrôle de vie 10 s, 3 essais à 5 s) ; après une coupure, la première connexion qui réussit coupe celles restées muettes ; rc `core/reconnect` fait de même à la demande |

## Choix mesurés

Les valeurs et leurs mesures sont en commentaire dans `MountOptions` (`Model/Drive.swift`). Ne pas les changer sans
remesurer. L'essentiel :

- Dropbox : blocs de 8 Mo ou moins → `too_many_requests` ; 64M × 4 a figé un montage macFUSE. Lecture en 32M sur
  macFUSE, 16M sur NFS, 16 flux partagés avec le moteur inclus.
- NFS a besoin du cache `full` (sans cache, chaque lecture NFS rouvre le fichier). macFUSE lit sans disque, en
  `--vfs-cache-mode writes`.
- Envois : Dropbox en blocs de 128M sur 16 transferts, Google Drive en 64M sur 8.
- rclone ne libère pas un fichier en cours de lecture en NFS : sous 3 Go libres (`DiskSpace.floor`), l'app remonte le
  lecteur avec un cache vidé, sauf si des envois sont en attente ou des fichiers modifiés attendent sur le disque.
  L'espace libre lu est celui du disque du cache.
- Cache sur un disque externe (Paramètres › Cache › Emplacement) : il va dans `<dossier choisi>/Docklume.noindex`,
  pour que « Vider tout le cache » ne touche rien d'autre et que Spotlight ne l'indexe pas (il indexe les disques
  externes, pas `~/Library/Caches`). Disque absent : les lecteurs l'attendent (« En attente du disque… ») et se
  montent à son arrivée ; supprimer un lecteur ou déplacer le cache est refusé tant qu'il manque.
- La clé Google partagée de rclone est limitée et en fin de vie : l'app accepte une clé Google personnelle
  (`GoogleKeyDialog`).

## Coupures de réseau

- Une coupure d'Internet derrière la box (noms qui ne se résolvent plus) ne change rien pour macOS : seul le moteur
  la voit, par ses connexions qui échouent puis réussissent de nouveau (patch 0009).
- `NetworkWatch` (NWPathMonitor) signale les vrais changements, interface perdue ou retrouvée : l'app appelle alors
  `core/reconnect` sur chaque lecteur monté et monte tout de suite les lecteurs en attente.
- Avant chaque montage, `DriveStore` ouvre une connexion TCP vers le serveur du lecteur (`Reachability.endpoint`,
  8 s au plus). S'il ne répond pas, rclone n'est pas lancé : « kDrive ne répond pas, nouvelle tentative dans … s »,
  puis de nouveaux essais au plus toutes les 30 s, sans limite. Une erreur réseau au montage fait de même.
- La lecture de l'espace (`Rclone.about`, toutes les 5 min) a des délais courts ; quand le serveur est muet, la carte
  affiche « <service> ne répond pas ».
- `tools/outage/run.sh` simule une coupure : un relais laisse mourir les connexions ouvertes et laisse passer les
  nouvelles, comme une box après une coupure.

## Thème de Noël

- Réglage Thème des Paramètres (`theme`) : Automatique (Noël du 1er décembre au 6 janvier), Standard, Noël ; prêt
  pour d'autres thèmes (`AppTheme`). L'ancien réglage `christmas` (Activé, Désactivé) est repris au lancement.
- Contenu : ciel d'hiver derrière la fenêtre, neige posée en haut de chaque carte de lecteur, de la barre latérale,
  des surfaces du haut d'une page et de la carte du panneau, bonnet sur le logo. Tout est statique.
- La neige (`snowCap`) est Equatable, donc une carte redessinée chaque seconde pour son débit ne la redessine pas ;
  elle reste figée pendant le redimensionnement (`liveResize`, signalé par `WindowChrome`) et se refait à la fin.
- Sa bosse la plus haute vaut exactement `depth` (10 pt sur une carte de lecteur, puis 14 pt d'air sous la carte du
  dessus, l'écart entre les cartes sans le thème), elle suit l'arrondi des coins et s'y amincit jusqu'à rien, et son contour est lissé : un trait clair au
  bout de la neige et des marches sur le contour se voyaient à 1x sur fond sombre.
- Le thème ne déplace rien : la place de la neige au-dessus de la première carte d'une page (`pageSnowRoom`) est
  prise sur la marge basse de l'en-tête. Le bonnet est posé sur le dessus du logo, pompon à droite, sous les
  boutons de la fenêtre ; au coin gauche il frôlait ces boutons, au coin droit il touchait le titre.
- Essayé puis refusé par l'utilisateur, à ne pas reproposer : neige qui tombe, guirlandes (ampoules, sapin, perles,
  décorations suspendues), sapin décoré, houx, congère ou neige en bas de la fenêtre, flocons immobiles dans le fond,
  gouttes sous la neige.
- Les captures du README forcent le thème désactivé ; `DOCKLUME_CHRISTMAS=1 tools/screenshots/render.sh <dossier>`
  rend le thème pour le regarder, et `DOCKLUME_SCALE=1` comme sur les écrans 1x de l'utilisateur.

## Comportements macOS à connaître

- Arrêt macFUSE : `/sbin/umount`, puis `umount -f`, SIGINT en dernier recours (SIGINT seul laissait rclone bloqué
  10 à 15 min). NFS : SIGINT. Un point de montage resté occupé se règle par rmdir puis mkdir.
- Une éjection depuis le Finder fait sortir rclone avec le code 0 : pas de remontage automatique.
- Un process lancé par l'app lui survit quand elle quitte. Les rclone ponctuels passent par `ChildProcesses`, arrêtés
  à la sortie : un `rclone authorize` resté en attente gardait le port 53682 et faisait échouer les connexions suivantes.
- Au lancement, l'app reprend les rclone orphelins (ppid 1) dont `--cache-dir` correspond à un lecteur.
- NFS : `--option locallocks` est obligatoire (le serveur rclone n'a pas de NLM). NFS ne garde pas les tags.
- Spotlight n'indexe pas macFUSE, donc la liste Tags du Finder ne montre rien : l'app tient `~/Cloud/Tags/<tag>/`,
  des alias marqués par l'attribut `fr.docklume.target`, et ne supprime que les siens.
- App de fond : `LSUIElement = true`, car des utilitaires comme Vorssaint quittent les apps du Dock restées sans
  fenêtre. Politique `.regular` au lancement, `.accessory` à la fermeture de la fenêtre. Revenir dans le Dock en étant
  active demande `deactivate` puis `activate` en différé.
- kDrive en WebDAV : `https://<ID>.connect.kdrive.infomaniak.com`, avec l'ID qui suit `/drive/` dans l'adresse web
  (le premier nombre est l'organisation).

## Vérifier

- `tools/tests/run.sh` : reprise des données de CloudShelf et des alias de tags, sur de faux dossiers personnels.
- `tools/tests/reach/run.sh` : vrai `DriveStore` face à un serveur muet (pas de rclone, message, nouvel essai) et à un
  serveur local (montage en 2 s). Sans catalogue, il ne touche pas à `~/Cloud/Tags`.
- `tools/outage/run.sh reconnect|wait` : coupure simulée sur un montage macFUSE local ; la lecture repart en environ
  1,5 s avec `core/reconnect`, reste figée sans.
- `tools/screenshots/render.sh` : refait `docs/images` (README et site) avec des comptes de démo et liste les images
  qui ont changé. Copier ensuite les images voulues dans `docs/images`, en anglais (`DOCKLUME_LANG=en`, par défaut),
  et dans `docs/images/fr` (`DOCKLUME_LANG=fr`) ; `DOCKLUME_ONLY=settings,notes` ne rend que ces écrans. La version affichée vient de l'app rendue :
  `DOCKLUME_APP=<Release.app>` rend depuis la Release, sans recompiler l'app Debug en service. La hauteur de fenêtre
  sort parfois 34 pt plus grande : le script garde le bon tirage, et le relancer suffit si une image change de taille.
  Un rendu hors écran ne doit pas fixer la hauteur de `MainWindow` par `.frame` : le bas de la fenêtre sort alors du
  cadre.
- Une vraie fenêtre de test se capture par `screencapture -l <numéro>` ; écran verrouillé, la capture échoue et le
  serveur graphique ne dessine plus rien, donc pas de mesure possible.
- Tests sans toucher aux lecteurs de l'utilisateur : `RCLONE_CONFIG` vers un fichier temporaire avec un remote
  `local`, `rclone serve webdav` ou `serve http --bwlimit 30M` pour simuler un serveur, RAM disk
  (`hdiutil attach -nomount ram://N` puis `diskutil erasevolume`) pour le disque plein.
- Copie Finder : `osascript -e 'tell application "Finder" to duplicate (POSIX file A as alias) to (POSIX file B as alias) with replacing'`
  renvoie le code d'erreur du Finder.
- Les nouvelles tentatives de rclone sur un quota Google ne sont journalisées qu'en DEBUG.

## Publier

- Dépôt public `LFR-54/Docklume` (MIT). Site GitHub Pages dans `docs/` (lfr-54.github.io/Docklume), dont
  `confidentialite.html` pour l'écran de consentement Google.
- Nouvelle version : `MARKETING_VERSION` et `CURRENT_PROJECT_VERSION` dans le projet, `Model/Releases.swift` (la
  dernière avec `latest: true`), nom du zip dans le README, captures refaites depuis la Release.
- Release GitHub : build `-configuration Release`, puis
  `ditto -c -k --keepParent --sequesterRsrc build/DerivedData/Build/Products/Release/Docklume.app build/release/Docklume-<version>.zip`
  et `gh release create v<version> <zip> --title "Docklume <version>" --notes-file …`. L'app est signée ad hoc, non
  notariée : le README explique l'ouverture par Réglages Système › Confidentialité et sécurité.
- Logos : `brand-*.imageset` en PDF vectoriel tirés de Wikimedia Commons (OneDrive en PNG), crédités dans le README.
  L'icône kDrive est redessinée depuis les calques de Infomaniak/ios-kDrive (GPL-3.0).
