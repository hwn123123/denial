#!/usr/bin/env python3
"""Fetch/check pinned release inputs; verify Denial's detached signatures."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import urllib.request

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("directory", type=Path)
parser.add_argument("--download", action="store_true")
args = parser.parse_args()
lock = json.loads((Path(__file__).resolve().parents[1] / "inputs.lock.json").read_text())
args.directory.mkdir(parents=True, exist_ok=True)
for entry in lock["files"]:
    destination = args.directory / entry["name"]
    if not destination.exists() and args.download:
        request = urllib.request.Request(entry["url"], headers={"User-Agent": "shennong-denial-builder"})
        temporary = destination.with_suffix(destination.suffix + ".download")
        try:
            with urllib.request.urlopen(request, timeout=60) as source, temporary.open("wb") as target:
                while chunk := source.read(1024 * 1024):
                    target.write(chunk)
            temporary.replace(destination)
        finally:
            temporary.unlink(missing_ok=True)
    digest = hashlib.sha256()
    with destination.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
    if digest.hexdigest() != entry["sha256"]:
        raise SystemExit(f"Checksum mismatch: {destination}")
    print(f"SHA256 OK: {destination.name}")

with tempfile.TemporaryDirectory(prefix="shennong-denial-key-") as keyring:
    os.chmod(keyring, 0o700)
    command = ["gpg", "--homedir", keyring, "--batch"]
    subprocess.run(command + ["--import", str(args.directory / "denial-repo-key.asc")], check=True)
    listing = subprocess.check_output(command + ["--with-colons", "--fingerprint"], text=True)
    fingerprints = [line.split(":")[9] for line in listing.splitlines() if line.startswith("fpr:")]
    if not fingerprints or fingerprints[0] != lock["signing_fingerprint"]:
        raise SystemExit("Release signing key fingerprint mismatch")
    for entry in lock["files"]:
        if entry["name"].endswith(".deb"):
            package = args.directory / entry["name"]
            subprocess.run(command + ["--verify", str(package) + ".sig", str(package)], check=True)
