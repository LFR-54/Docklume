"""Checks Docklume/Model/English.swift against the texts of the app.

Usage: python3 -I tools/l10n/check.py [--keys]
Reports the French texts without an English version, the English entries no text uses any more, entries written
twice (a crash at launch) and English texts whose values do not match. --keys prints every key the code uses.
"""

import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from swiftstrings import parse, scan  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TABLE = os.path.join(ROOT, "Docklume/Model/English.swift")
# Keys that reach L() at run time, from a stored value.
DYNAMIC = {"Tout", "Avertissements", "Erreurs"}


def code_keys():
    keys = {}
    for path in sorted(glob.glob(os.path.join(ROOT, "Docklume/**/*.swift"), recursive=True)):
        if path == TABLE:
            continue
        source = open(path, encoding="utf-8").read()
        where = os.path.relpath(path, ROOT)
        for literal in scan(source):
            before = source[max(0, literal.start - 200):literal.start]
            if literal.wrapped:
                keys.setdefault(literal.key, where)
            elif re.search(r"Text\(composing: (\w+ > 1 \? \"[^\"]*\" : )?$", before) or re.search(r"Text\(composing: \w+ > 1 \? $", before):
                keys.setdefault(literal.key.replace("%%", "%"), where)
        # The words of Format.plural, often inside the values of another text.
        for word in re.findall(r'Format\.plural\([^"]*?, "([^"]+)"\)', source):
            keys.setdefault(word, where)
    for key in DYNAMIC:
        keys.setdefault(key, "dynamic")
    return keys


def table_entries():
    source = open(TABLE, encoding="utf-8").read()
    start = source.index("table: [String: String] = [")
    body = source[start:source.index("\n    ]\n", start)]
    entries = []
    i = 0
    while True:
        i = body.find('"', i)
        if i < 0:
            return entries
        end, key = parse(body, i)
        colon = body.index(":", end)
        start = body.index('"', colon)
        stop, value = parse(body, start)
        # A table literal is the key itself, where a percent sign is already written %%.
        entries.append((key.replace("%%", "%"), value.replace("%%", "%")))
        i = stop


def placeholders(text):
    return len(re.findall(r"%(?:\d+\$)?@", text))


def main():
    keys = code_keys()
    if "--keys" in sys.argv:
        for key, where in sorted(keys.items(), key=lambda item: (item[1], item[0])):
            print(f"{where}\t{key}")
        return 0
    entries = table_entries()
    seen, problems = set(), 0
    for key, value in entries:
        if key in seen:
            print(f"en double : {key}")
            problems += 1
        seen.add(key)
        if placeholders(key) != placeholders(value):
            print(f"valeurs différentes : {key!r} → {value!r}")
            problems += 1
    for key, where in sorted(keys.items(), key=lambda item: item[1]):
        if key not in seen:
            print(f"sans anglais ({where}) : {key}")
            problems += 1
    for key in sorted(seen - set(keys)):
        print(f"plus utilisé : {key}")
    print(f"{len(keys)} textes, {len(entries)} traductions, {problems} problème(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
