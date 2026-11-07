#!/bin/zsh
# Mounts two WebDAV drives through the real DriveStore: one whose server never answers, which must wait without
# starting rclone and say so, and one served locally, which must mount. No catalog, so the store leaves
# ~/Cloud/Tags alone; settings, caches and mount points stay in a temporary folder, and the logs are moved there.
# Needs a Debug build in build/DerivedData and the bundled engine.
set -euo pipefail
ROOT=${0:A:h:h:h:h}
HERE=${0:A:h}
APP=$ROOT/build/DerivedData/Build/Products/Debug/Docklume.app
[[ -d $APP ]] || { echo "Pas de build Debug dans build/DerivedData : compilez Docklume d'abord." >&2; exit 1; }
T=$(mktemp -d)
mkdir -p $T/data $T/mnt $T/cache $T/Test.app/Contents/MacOS
echo bonjour > $T/data/lisez-moi.txt
cat > $T/rclone.conf <<CONF
[muet]
type = webdav
url = https://10.255.255.1/
vendor = other

[local]
type = webdav
url = http://127.0.0.1:18101/
vendor = other
CONF
cp -R $APP/Contents/Info.plist $APP/Contents/Resources $T/Test.app/Contents/
ln -s $ROOT/build/rclone/rclone $T/Test.app/Contents/MacOS/rclone
swiftc -swift-version 6 -O -suppress-warnings -module-name Docklume -target arm64-apple-macos15.0 \
  $ROOT/Docklume/{Engine,Model,Views}/**/*.swift $HERE/../../Stubs.swift $HERE/main.swift -o $T/Test.app/Contents/MacOS/Docklume
$ROOT/build/rclone/rclone serve webdav $T/data --addr 127.0.0.1:18101 >/dev/null 2>&1 &
server=$!
trap 'kill $server 2>/dev/null' EXIT
RCLONE_CONFIG=$T/rclone.conf perl -e 'alarm 90; exec @ARGV' $T/Test.app/Contents/MacOS/Docklume $T 2>&1 | grep -v sandbox_extension | tee $T/run.log
for log in $(sed -n 's/^journaux : //p' $T/run.log); do [[ -f $log ]] && mv $log $T/; done
echo "Dossier de test : $T"
