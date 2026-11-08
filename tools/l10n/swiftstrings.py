"""Finds the string literals of Swift sources, interpolations included, for the localization tools."""

import re
from dataclasses import dataclass


@dataclass
class Literal:
    start: int          # index of the opening quote (or of the L( that wraps it)
    end: int            # index just past the closing quote
    text: str           # the literal as written, quotes included
    key: str            # the text with each interpolation as %@ and % doubled, as Localized builds it
    wrapped: bool       # already inside L(...)
    line: int


ESCAPES = {"n": "\n", "t": "\t", '"': '"', "\\": "\\", "'": "'", "0": "\0", "r": "\r"}


def scan(source):
    """Yields the string literals, those inside an interpolation after the one that holds them."""
    i, n = 0, len(source)
    while i < n:
        c = source[i]
        if source.startswith("//", i):
            i = source.find("\n", i)
            if i < 0:
                return
            continue
        if source.startswith("/*", i):
            i = source.find("*/", i) + 2
            continue
        if c == "#" and source.startswith('#"', i):
            end = source.find('"#', i + 2)
            i = end + 2
            continue
        if c == "#" and source.startswith("#/", i):
            end = source.find("/#", i + 2)
            i = end + 2
            continue
        if source.startswith('"""', i):
            end = source.find('"""', i + 3)
            i = end + 3
            continue
        if c == '"':
            nested = []
            end, key = parse(source, i, nested)
            yield literal(source, i, end, key)
            # Literals inside the interpolations, such as an L("…") in another text.
            for inner in nested:
                inner_end, inner_key = parse(source, inner)
                yield literal(source, inner, inner_end, inner_key)
            i = end
            continue
        i += 1


def literal(source, i, end, key):
    wrapped = source[max(0, i - 2):i] == "L("
    start = i - 2 if wrapped else i
    stop = end + 1 if wrapped and end < len(source) and source[end] == ")" else end
    return Literal(start, stop, source[i:end], key, wrapped, source.count("\n", 0, i) + 1)


def parse(source, i, nested=None):
    """Parses the literal opening at i; returns the index past its closing quote and its key. The literals found
    inside its interpolations are added to `nested`."""
    assert source[i] == '"'
    i += 1
    key = []
    while True:
        c = source[i]
        if c == '"':
            return i + 1, "".join(key)
        if c == "\\":
            nxt = source[i + 1]
            if nxt == "(":
                depth, j = 1, i + 2
                while depth:
                    if source[j] == '"':
                        if nested is not None:
                            nested.append(j)
                        j, _ = parse(source, j, nested)
                        continue
                    depth += {"(": 1, ")": -1}.get(source[j], 0)
                    j += 1
                key.append("%@")
                i = j
                continue
            if nxt == "u":
                close = source.index("}", i)
                key.append(chr(int(source[i + 3:close], 16)))
                i = close + 1
                continue
            key.append(ESCAPES.get(nxt, nxt))
            i += 2
            continue
        key.append("%%" if c == "%" else c)
        i += 1


def keys_in(path):
    with open(path, encoding="utf-8") as f:
        source = f.read()
    return [lit for lit in scan(source) if lit.wrapped]


WORD = re.compile(r"[A-Za-zÀ-ÿœŒ]")
