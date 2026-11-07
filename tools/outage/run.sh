#!/bin/zsh
# Reads a 160 MB file through a macFUSE mount of a local server, through a relay that cuts the connections in
# flight 5 s in while new ones still work, as a router does after an outage. With `reconnect`, calls core/reconnect
# (rclone-patches/0009) 10 s later: the read starts again within seconds. With `wait`, it stays stalled until
# rclone's idle timeout. Needs the bundled engine built by scripts/build-rclone.sh.
# Usage: tools/outage/run.sh reconnect|wait
set -u
ROOT=${0:A:h:h:h}
HERE=${0:A:h}
R=$ROOT/build/rclone/rclone
mode=${1:-reconnect}
T=$(mktemp -d)
mkdir -p $T/data $T/mnt
dd if=/dev/urandom of=$T/data/film.bin bs=1m count=160 2>/dev/null
$R serve http $T/data --addr 127.0.0.1:18091 --bwlimit 8M >/dev/null 2>&1 & server=$!
python3 -I $HERE/proxy.py 18092 18091 $T/flag & proxy=$!
sleep 1
$R mount :http: $T/mnt --http-url http://127.0.0.1:18092 --vfs-cache-mode writes --vfs-read-chunk-size 32M \
  --vfs-read-chunk-streams 16 --vfs-read-chunk-streams-total 16 --buffer-size 64M --timeout 300s \
  --rc --rc-addr 127.0.0.1:18093 --rc-no-auth --volname DocklumeTest -v --log-file $T/mount.log & mount=$!
for i in {1..50}; do mount | grep -q "$T/mnt" && break; sleep 0.2; done
python3 -I $HERE/reader.py $T/mnt/film.bin > $T/reader.log 2>&1 & reader=$!
sleep 5; touch $T/flag; echo "connexions coupées à 5 s"
sleep 10
if [[ $mode == reconnect ]]; then
  echo "core/reconnect à 15 s : $(curl -s -X POST http://127.0.0.1:18093/core/reconnect | tr -d '\n\t ')"
fi
for i in {1..40}; do kill -0 $reader 2>/dev/null || break; sleep 1; done
kill $reader 2>/dev/null
umount $T/mnt 2>/dev/null || umount -f $T/mnt
sleep 1; kill $mount $proxy $server 2>/dev/null; wait 2>/dev/null
echo "== lecture ($mode), temps depuis le début"; head -4 $T/reader.log; echo "…"; tail -2 $T/reader.log
echo "Dossier de test : $T"
