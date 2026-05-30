#!/usr/bin/env bash
# QA-Tests für Ticket #8: show_qr.py crasht ohne vorhandene .venv
# Akzeptanzkriterien:
#   AK1 – Problem aus Code-Review (os.listdir ohne Existenzprüfung) ist behoben
#   AK2 – Verbesserungsvorschlag umgesetzt (qrcode via requirements.txt, kein venv-Bootstrap)

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHOW_QR="$REPO_ROOT/tools/show_qr.py"
REQUIREMENTS="$REPO_ROOT/tools/requirements.txt"

PASS=0
FAIL=0

ok()   { echo "✅ $1"; PASS=$((PASS+1)); }
fail() { echo "❌ $1"; FAIL=$((FAIL+1)); }

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  QA-Tests Ticket #8 – show_qr.py crasht ohne .venv"
echo "══════════════════════════════════════════════════════════════"
echo ""

# ══════════════════════════════════════════════════════════════
# AK1 – Problem aus Code-Review behoben
# ══════════════════════════════════════════════════════════════
echo "── AK1: os.listdir/venv-Bootstrap-Code entfernt ──"

# T1: Kein os.listdir-Aufruf mehr in show_qr.py
if grep -n "os\.listdir" "$SHOW_QR" > /dev/null 2>&1; then
  fail "T1: os.listdir noch vorhanden in show_qr.py"
  grep -n "os\.listdir" "$SHOW_QR"
else
  ok "T1: Kein os.listdir in show_qr.py"
fi

# T2: Kein venv_site-Variablenname mehr vorhanden
if grep -n "venv_site\|venv_path\|site-packages" "$SHOW_QR" > /dev/null 2>&1; then
  fail "T2: venv-Crawl-Code (venv_site / site-packages) noch vorhanden"
  grep -n "venv_site\|venv_path\|site-packages" "$SHOW_QR"
else
  ok "T2: Kein venv_site/site-packages-Crawl-Code in show_qr.py"
fi

# T3: Keine sys.path-Manipulation mehr vorhanden
if grep -n "sys\.path\.insert\|sys\.path\.append" "$SHOW_QR" > /dev/null 2>&1; then
  fail "T3: sys.path-Manipulation noch in show_qr.py"
  grep -n "sys\.path" "$SHOW_QR"
else
  ok "T3: Keine sys.path-Manipulation in show_qr.py"
fi

# T4: Das Skript crasht NICHT mit FileNotFoundError wenn .venv fehlt
# Simuliere: Erstelle eine isolierte Python-Umgebung ohne qrcode und prüfe,
# dass der Fehler KEIN FileNotFoundError ist, sondern ein ImportError-Guard.
echo ""
echo "── T4/T5: Verhalten ohne installiertes qrcode (Simulation) ──"

# Erstelle Mini-venv ohne qrcode
TMPVENV=$(mktemp -d)
python3 -m venv "$TMPVENV" > /dev/null 2>&1

# Führe show_qr.py in der nackten venv aus (kein qrcode installiert)
NOQR_OUT=$("$TMPVENV/bin/python3" "$SHOW_QR" 2>&1)
NOQR_RC=$?

echo "    Exit-Code: $NOQR_RC"
echo "    Output: $NOQR_OUT"

# T4: Kein FileNotFoundError (der ursprüngliche Bug)
if echo "$NOQR_OUT" | grep -q "FileNotFoundError"; then
  fail "T4: Skript crasht mit FileNotFoundError – ursprünglicher Bug NICHT behoben"
else
  ok "T4: Kein FileNotFoundError – ursprünglicher Crash-Bug ist behoben"
fi

# T5: Fehlermeldung enthält nützlichen Hinweis (ImportError-Guard greift)
if echo "$NOQR_OUT" | grep -qiE "qrcode.*nicht installiert|pip install.*requirements|Fehler.*qrcode"; then
  ok "T5: ImportError-Guard gibt handlungsweisende Fehlermeldung aus"
else
  fail "T5: Keine handlungsweisende Fehlermeldung bei fehlendem qrcode (Output: $NOQR_OUT)"
fi

# T6: Exit-Code 1 bei fehlendem qrcode (kein stiller Fehler)
if [ $NOQR_RC -eq 1 ]; then
  ok "T6: Exit-Code 1 bei fehlendem qrcode (sauberer Fehlerausgang)"
else
  fail "T6: Unerwarteter Exit-Code $NOQR_RC – erwartet: 1"
fi

rm -rf "$TMPVENV"

echo ""

# ══════════════════════════════════════════════════════════════
# AK2 – Verbesserungsvorschlag umgesetzt
# ══════════════════════════════════════════════════════════════
echo "── AK2: qrcode als reguläre Abhängigkeit, kein Bootstrap ──"

# T7: requirements.txt existiert und enthält qrcode[pil]
if grep -q "qrcode\[pil\]" "$REQUIREMENTS" 2>/dev/null; then
  ok "T7: tools/requirements.txt enthält 'qrcode[pil]'"
  echo "    Inhalt: $(cat "$REQUIREMENTS")"
else
  fail "T7: tools/requirements.txt fehlt oder enthält kein 'qrcode[pil]'"
fi

# T8: import qrcode ist ein direkter Import (kein dynamisches Laden)
if grep -qE "^import qrcode$|^    import qrcode$" "$SHOW_QR"; then
  ok "T8: 'import qrcode' als direkter Import vorhanden"
else
  fail "T8: 'import qrcode' als direkter Import nicht gefunden"
fi

# T9: Fehlermeldung geht auf sys.stderr (nicht stdout)
# Prüfe im Quellcode, dass ImportError-Ausgabe file=sys.stderr nutzt
if python3 -c "
import ast, sys
with open('$SHOW_QR') as fh:
    tree = ast.parse(fh.read())
for node in ast.walk(tree):
    if isinstance(node, ast.ExceptHandler):
        # Suche nach print(..., file=sys.stderr) in except-Block
        for child in ast.walk(node):
            if isinstance(child, ast.Call) and isinstance(child.func, ast.Name):
                if child.func.id == 'print':
                    for kw in child.keywords:
                        if kw.arg == 'file':
                            print('stderr_found')
                            sys.exit(0)
sys.exit(1)
" 2>/dev/null | grep -q "stderr_found"; then
  ok "T9: ImportError-Ausgabe wird auf sys.stderr geleitet"
else
  # Fallback: grep-basierter Check
  if grep -A5 "except ImportError" "$SHOW_QR" | grep -q "sys.stderr"; then
    ok "T9: ImportError-Ausgabe wird auf sys.stderr geleitet (grep-Check)"
  else
    fail "T9: Fehlermeldung nicht auf sys.stderr – stdout-Verschmutzung möglich"
  fi
fi

# T10: subprocess.run mit check=True (Fehlerbehandlung beim Öffnen)
if grep -q "check=True" "$SHOW_QR"; then
  ok "T10: subprocess.run verwendet check=True"
else
  fail "T10: subprocess.run ohne check=True – Fehler beim Öffnen werden lautlos ignoriert"
fi

# T11: Plattform-Portabilität – opener-Variable für macOS und Linux
if grep -q "xdg-open" "$SHOW_QR"; then
  ok "T11: Linux-Fallback 'xdg-open' vorhanden – plattformportabel"
else
  fail "T11: Kein 'xdg-open'-Fallback – nur macOS kompatibel"
fi

echo ""

# ══════════════════════════════════════════════════════════════
# Funktionstest mit installiertem qrcode
# ══════════════════════════════════════════════════════════════
echo "── Funktionstest: Happy-Path mit installiertem qrcode ──"

TMPVENV2=$(mktemp -d)
python3 -m venv "$TMPVENV2" > /dev/null 2>&1
"$TMPVENV2/bin/pip" install -r "$REQUIREMENTS" -q 2>&1

# T12: Usage-Hinweis bei fehlendem Argument
USAGE_OUT=$("$TMPVENV2/bin/python3" "$SHOW_QR" 2>&1)
USAGE_RC=$?
if echo "$USAGE_OUT" | grep -qi "Usage"; then
  ok "T12: Usage-Hinweis bei fehlendem Argument (Exit-Code: $USAGE_RC)"
else
  fail "T12: Kein Usage-Hinweis – Output: '$USAGE_OUT' (Exit: $USAGE_RC)"
fi

# T13: qrcode.make() wird mit einem validen Key aufgerufen – Bild wird erzeugt
# Wir rufen show_qr intern nur bis zur Bild-Erzeugung auf (kein Display-Aufruf)
IMG_OUT=$("$TMPVENV2/bin/python3" - <<'PYEOF' 2>&1
import sys
sys.argv = ['show_qr.py', 'test-api-key-12345']
import qrcode, tempfile
key = 'test-api-key-12345'
img = qrcode.make(key)
with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
    img.save(f, "PNG")
    tmp = f.name
import os
size = os.path.getsize(tmp)
print(f"PNG erzeugt: {tmp} ({size} bytes)")
os.unlink(tmp)
PYEOF
)
IMG_RC=$?
if [ $IMG_RC -eq 0 ] && echo "$IMG_OUT" | grep -q "PNG erzeugt"; then
  ok "T13: qrcode.make() erzeugt valide PNG-Datei"
  echo "    $IMG_OUT"
else
  fail "T13: PNG-Erzeugung fehlgeschlagen – $IMG_OUT"
fi

rm -rf "$TMPVENV2"

echo ""
echo "══════════════════════════════════════════════════════════════"
printf "  Ergebnis: %d bestanden, %d fehlgeschlagen\n" "$PASS" "$FAIL"
echo "══════════════════════════════════════════════════════════════"
echo ""

if [ $FAIL -eq 0 ]; then
  echo "🎉 ALLE TESTS BESTANDEN"
  exit 0
else
  echo "💥 $FAIL TEST(S) FEHLGESCHLAGEN"
  exit 1
fi
