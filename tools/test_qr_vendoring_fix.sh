#!/usr/bin/env bash
# QA-Tests für Ticket #6: Vendoring-Fix show_qr.py
# Alle Pfade relativ zum Repo-Root

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHOW_QR="$REPO_ROOT/tools/show_qr.py"
REQUIREMENTS="$REPO_ROOT/tools/requirements.txt"
GITIGNORE="$REPO_ROOT/.gitignore"
README="$REPO_ROOT/README.md"

PASS=0
FAIL=0

ok()   { echo "✅ $1"; PASS=$((PASS+1)); }
fail() { echo "❌ $1"; FAIL=$((FAIL+1)); }

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  QA-Tests Ticket #6 – Vendoring-Fix"
echo "═══════════════════════════════════════════════════════"
echo ""

# ── AK1: sys.path-Manipulation entfernt ─────────────────────
echo "── Akzeptanzkriterium 1: sys.path-Manipulation entfernt ──"

# T1: Kein sys.path.insert in show_qr.py
if grep -n "sys\.path\.insert\|sys\.path\.append" "$SHOW_QR" > /dev/null 2>&1; then
  fail "T1: sys.path-Manipulation noch vorhanden in show_qr.py"
  grep -n "sys\.path\.insert\|sys\.path\.append" "$SHOW_QR"
else
  ok "T1: Keine sys.path-Manipulation in show_qr.py"
fi

# T2: Kein os.listdir(venv_site) / venv-Crawl-Block
if grep -n "venv_site\|os\.listdir.*venv\|site-packages" "$SHOW_QR" > /dev/null 2>&1; then
  fail "T2: venv-Crawl-Code noch vorhanden in show_qr.py"
  grep -n "venv_site\|os\.listdir.*venv\|site-packages" "$SHOW_QR"
else
  ok "T2: Kein venv-Crawl-Code in show_qr.py"
fi

# T3: import qrcode ist direkter Top-Level-Import
if grep -n "^import qrcode$" "$SHOW_QR" > /dev/null 2>&1; then
  ok "T3: 'import qrcode' ist sauberer Top-Level-Import"
else
  fail "T3: 'import qrcode' als direkter Import nicht gefunden"
fi

# T4: Python-Syntax ist valide
SYNTAX_OUT=$(python3 -m py_compile "$SHOW_QR" 2>&1)
SYNTAX_RC=$?
if [ $SYNTAX_RC -eq 0 ]; then
  ok "T4: show_qr.py hat valide Python-Syntax"
else
  fail "T4: show_qr.py hat Syntaxfehler: $SYNTAX_OUT"
fi

echo ""

# ── AK2: Verbesserungsvorschlag umgesetzt ───────────────────
echo "── Akzeptanzkriterium 2: Verbesserungsvorschlag umgesetzt ──"

# T5: requirements.txt existiert
if [ -f "$REQUIREMENTS" ]; then
  ok "T5: tools/requirements.txt existiert"
else
  fail "T5: tools/requirements.txt fehlt"
fi

# T6: requirements.txt enthält qrcode[pil]
if grep -q "qrcode\[pil\]" "$REQUIREMENTS" 2>/dev/null; then
  ok "T6: requirements.txt enthält 'qrcode[pil]'"
  echo "    Inhalt: $(cat "$REQUIREMENTS")"
else
  fail "T6: requirements.txt enthält kein 'qrcode[pil]'"
fi

# T7: .gitignore enthält .venv-Pattern
if grep -qE "tools/\.venv/|\*\*/\.venv/" "$GITIGNORE" 2>/dev/null; then
  ok "T7: .gitignore enthält venv-Pattern"
  grep "\.venv" "$GITIGNORE" | sed 's/^/    /'
else
  fail "T7: .gitignore ignoriert .venv/ nicht"
fi

# T8: .gitignore enthält __pycache__
if grep -q "__pycache__" "$GITIGNORE" 2>/dev/null; then
  ok "T8: .gitignore enthält __pycache__/"
else
  fail "T8: .gitignore enthält kein __pycache__/"
fi

# T9: README enthält pip install requirements.txt (Setup-Doku)
if grep -q "requirements.txt" "$README" 2>/dev/null; then
  ok "T9: README enthält Installationsanweisung (requirements.txt)"
else
  fail "T9: README enthält keine Installationsanweisung"
fi

# T10: README enthält python3 -m venv
if grep -q "python3 -m venv" "$README" 2>/dev/null; then
  ok "T10: README empfiehlt virtuelle Umgebung (python3 -m venv)"
else
  fail "T10: README gibt keinen venv-Setup-Hinweis"
fi

echo ""

# ── Sicherheitsprüfung: .venv nicht im Git-Index ────────────
echo "── Sicherheitsprüfung: .venv nicht im Git-Index ──"

# T11: tools/.venv wird von git nicht getrackt
cd "$REPO_ROOT"
if git ls-files tools/.venv --error-unmatch > /dev/null 2>&1; then
  fail "T11: tools/.venv ist im Git-Index – git rm --cached nötig!"
else
  ok "T11: tools/.venv ist nicht im Git-Index"
fi

# T12: git check-ignore bestätigt .venv als ignoriert (wenn Ordner vorhanden)
if [ -d "$REPO_ROOT/tools/.venv" ]; then
  if git check-ignore -q "$REPO_ROOT/tools/.venv" 2>/dev/null; then
    ok "T12: tools/.venv wird von .gitignore korrekt ignoriert"
  else
    fail "T12: tools/.venv existiert aber wird von .gitignore NICHT ignoriert"
  fi
else
  ok "T12: tools/.venv existiert nicht lokal (kein Problem)"
fi

echo ""

# ── Installationstest (funktionale Prüfung) ──────────────────
echo "── Funktionstest: Installation via requirements.txt ──"

# T13: Installiere qrcode[pil] in temp-venv und prüfe Import
TMPVENV=$(mktemp -d)
python3 -m venv "$TMPVENV" > /dev/null 2>&1
"$TMPVENV/bin/pip" install -r "$REQUIREMENTS" -q 2>&1

IMPORT_OUT=$("$TMPVENV/bin/python3" -c "
import qrcode, importlib.metadata
version = importlib.metadata.version('qrcode')
print('qrcode version:', version)
print('qrcode.make callable:', callable(qrcode.make))
from PIL import Image
print('PIL.Image available:', True)
" 2>&1)
IMPORT_RC=$?
if [ $IMPORT_RC -eq 0 ]; then
  ok "T13: qrcode via requirements.txt installierbar und importierbar (inkl. PIL)"
  echo "$IMPORT_OUT" | sed 's/^/    /'
else
  fail "T13: qrcode konnte nicht installiert/importiert werden: $IMPORT_OUT"
fi

# T14: show_qr.py zeigt Usage-Hinweis bei fehlendem Argument
USAGE_OUT=$("$TMPVENV/bin/python3" "$SHOW_QR" 2>&1)
USAGE_RC=$?
if echo "$USAGE_OUT" | grep -q "Usage"; then
  ok "T14: show_qr.py zeigt Usage-Hinweis bei fehlendem Argument (Exit-Code: $USAGE_RC)"
else
  fail "T14: show_qr.py zeigt keinen Usage-Hinweis (Exit-Code: $USAGE_RC, Output: $USAGE_OUT)"
fi

# Cleanup
rm -rf "$TMPVENV"

echo ""
echo "═══════════════════════════════════════════════════════"
printf "  Ergebnis: %d bestanden, %d fehlgeschlagen\n" "$PASS" "$FAIL"
echo "═══════════════════════════════════════════════════════"
echo ""

if [ $FAIL -eq 0 ]; then
  echo "🎉 ALLE TESTS BESTANDEN"
  exit 0
else
  echo "💥 $FAIL TEST(S) FEHLGESCHLAGEN"
  exit 1
fi
