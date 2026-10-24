#!/usr/bin/env python3
"""Reconstitute the exact uploaded phone-upload project from a SHA-checked baseline."""
from pathlib import Path
from zipfile import ZipFile
import base64
import hashlib
import lzma

BASE = Path("JevJarvis-Ultimate-source.zip")
EXPECTED_BASE = "23b57e8d6866b153418406f86e81c615a50f2022866ee6b30b2c091f24b56960"
EXPECTED_PATCH = "dd674b59369a92dfb6a5ac536bea34cd9f4c3d59041b900ac6c283029c2163b0"
assert BASE.is_file(), "Original source ZIP missing"
assert hashlib.sha256(BASE.read_bytes()).hexdigest() == EXPECTED_BASE, "Wrong source baseline"
parts = sorted(Path(".build-input").glob("v2-part-*.txt"))
assert len(parts) == 14, f"Expected 14 overlay parts, found {len(parts)}"
packed = base64.b64decode("".join(p.read_text() for p in parts))
assert hashlib.sha256(packed).hexdigest() == EXPECTED_PATCH, "Overlay checksum mismatch"
payload = lzma.decompress(packed)
assert payload.startswith(b"JEVV2\x00"), "Wrong overlay format"
pos = 6

def num():
    global pos
    n = shift = 0
    while True:
        c = payload[pos]
        pos += 1
        n |= (c & 127) << shift
        if c < 128:
            return n
        shift += 7
        assert shift < 64

def blob():
    global pos
    length = num()
    v = payload[pos:pos + length]
    assert len(v) == length
    pos += length
    return v

with ZipFile(BASE) as archive:
    old = {name.partition("/")[2] if name.startswith("JevJarvis-Ultimate/") else name: archive.read(name)
           for name in archive.namelist() if not name.endswith("/")}

root = Path("JevJarvis-Ultimate")
count = num()
assert count == 76, f"Unexpected number of project files: {count}"
for index in range(count):
    name = blob().decode("utf-8")
    relative = Path(name)
    assert not relative.is_absolute() and ".." not in relative.parts and name
    expected_hash = payload[pos:pos + 32]
    pos += 32
    mode = payload[pos]
    pos += 1
    if mode == 0:
        contents = old[name]
    elif mode == 1:
        contents = blob()
    elif mode == 2:
        source_lines = old[name].splitlines(keepends=True)
        pieces = []
        for _ in range(num()):
            command = payload[pos]
            pos += 1
            if command == 0:
                start, length = num(), num()
                assert start + length <= len(source_lines)
                pieces.extend(source_lines[start:start+length])
            elif command == 1:
                pieces.append(blob())
            else:
                raise ValueError(f"Invalid delta instruction: {command}")
        contents = b"".join(pieces)
    else:
        raise ValueError(f"Invalid delta mode: {mode}")
    assert hashlib.sha256(contents).digest() == expected_hash, f"Wrong content: {name}"
    dest = root / relative
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(contents)
assert pos == len(payload), "Extra bytes in delta"
for needed in ("project.yml", "Keyboard/GoutouSkill.md", "Broadcast/Sources/LiveBroadcastHandler.swift", "Shared/JevLive.swift"):
    assert (root/needed).is_file(), f"Missing: {needed}"
print(f"Reconstructed {count} verified files from the user's uploaded 2026-10-24 ZIP.")
