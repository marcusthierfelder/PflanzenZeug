#!/usr/bin/env python3
"""Zeigt einen QR-Code für den übergebenen API-Key an.

Usage: python3 tools/show_qr.py <api-key>

Öffnet den QR-Code als Bild in Preview (macOS) bzw. dem Standard-Bildbetrachter.

Voraussetzung: Abhängigkeiten installieren (einmalig):
    pip install -r tools/requirements.txt
"""

import subprocess
import sys
import tempfile

try:
    import qrcode
except ImportError:
    print(
        "Fehler: Das Paket 'qrcode' ist nicht installiert.\n"
        "Bitte ausführen: pip install -r tools/requirements.txt",
        file=sys.stderr,
    )
    sys.exit(1)


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: python3 show_qr.py <api-key>", file=sys.stderr)
        sys.exit(1)

    key = sys.argv[1]

    img = qrcode.make(key)

    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        img.save(f, "PNG")
        tmp_path = f.name

    # 'open' funktioniert auf macOS; auf Linux wäre 'xdg-open' die Alternative
    opener = "open" if sys.platform == "darwin" else "xdg-open"
    subprocess.run([opener, tmp_path], check=True)


if __name__ == "__main__":
    main()
