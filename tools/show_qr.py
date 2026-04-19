#!/usr/bin/env python3
"""Zeigt einen QR-Code für den übergebenen API-Key an.

Usage: ./tools/show_qr.py <api-key>

Öffnet den QR-Code als Bild in Preview.
"""

import os
import subprocess
import sys
import tempfile

# Activate the bundled venv so qrcode is importable regardless of how the script is called
venv_site = os.path.join(os.path.dirname(__file__), ".venv", "lib")
for d in os.listdir(venv_site):
    sp = os.path.join(venv_site, d, "site-packages")
    if os.path.isdir(sp):
        sys.path.insert(0, sp)
        break

import qrcode


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 show_qr.py <api-key>")
        sys.exit(1)

    key = sys.argv[1]

    img = qrcode.make(key)

    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        img.save(f, "PNG")
        subprocess.run(["open", f.name])


if __name__ == "__main__":
    main()
