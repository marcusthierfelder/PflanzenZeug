"""Tests für tools/show_qr.py

Smoke-Tests für:
  - Argument-Parsing (kein Argument, zu viele Argumente)
  - Erfolgsfall (qrcode.make + subprocess.run werden korrekt aufgerufen)
  - subprocess-Fehler wird propagiert
  - Temporärdatei wird via atexit-Handler aufgeräumt (_register_cleanup)

Ausführen (vom Repo-Root oder tools/):
    python -m pytest tools/tests/test_show_qr.py -v
"""

import os
import subprocess
import sys
import tempfile
from pathlib import Path
from unittest.mock import MagicMock, call, patch

import pytest

# show_qr.py liegt eine Ebene über diesem tests/-Verzeichnis
sys.path.insert(0, str(Path(__file__).parent.parent))

import show_qr  # noqa: E402  (nach sys.path-Manipulation)


# ---------------------------------------------------------------------------
# Hilfsfunktion: Fake-Image-Objekt, das save() unterstützt
# ---------------------------------------------------------------------------

def _make_fake_img() -> MagicMock:
    """Gibt ein Mock zurück, das show_qr.img.save(...) akzeptiert."""
    fake_img = MagicMock()
    fake_img.save = MagicMock()
    return fake_img


# ---------------------------------------------------------------------------
# Argument-Parsing
# ---------------------------------------------------------------------------

class TestArgumentParsing:
    """show_qr.main() soll bei falschem Argument-Count mit Exit-Code 1 abbrechen."""

    def test_no_argument_exits_with_code_1(self, capsys):
        """Kein Argument → sys.exit(1) + Fehlermeldung auf stderr."""
        with patch.object(sys, "argv", ["show_qr.py"]):
            with pytest.raises(SystemExit) as exc_info:
                show_qr.main()
        assert exc_info.value.code == 1
        captured = capsys.readouterr()
        assert "Usage" in captured.err

    def test_too_many_arguments_exits_with_code_1(self, capsys):
        """Zu viele Argumente → sys.exit(1) + Fehlermeldung auf stderr."""
        with patch.object(sys, "argv", ["show_qr.py", "key1", "key2"]):
            with pytest.raises(SystemExit) as exc_info:
                show_qr.main()
        assert exc_info.value.code == 1
        captured = capsys.readouterr()
        assert "Usage" in captured.err


# ---------------------------------------------------------------------------
# Erfolgsfall
# ---------------------------------------------------------------------------

class TestSuccessPath:
    """Im Erfolgsfall sollen qrcode.make und subprocess.run korrekt aufgerufen werden."""

    def test_qrcode_make_called_with_api_key(self):
        """qrcode.make wird mit dem übergebenen API-Key aufgerufen."""
        fake_img = _make_fake_img()
        with patch.object(sys, "argv", ["show_qr.py", "my-secret-key"]), \
             patch("show_qr.qrcode.make", return_value=fake_img) as mock_make, \
             patch("show_qr.subprocess.run"), \
             patch("show_qr.atexit.register"):
            show_qr.main()

        mock_make.assert_called_once_with("my-secret-key")

    def test_subprocess_run_called_with_tmp_png(self):
        """subprocess.run wird mit einer .png-Datei aufgerufen."""
        fake_img = _make_fake_img()
        with patch.object(sys, "argv", ["show_qr.py", "my-secret-key"]), \
             patch("show_qr.qrcode.make", return_value=fake_img), \
             patch("show_qr.subprocess.run") as mock_run, \
             patch("show_qr.atexit.register"):
            show_qr.main()

        assert mock_run.call_count == 1
        args, kwargs = mock_run.call_args
        cmd = args[0]
        assert isinstance(cmd, list)
        assert cmd[-1].endswith(".png"), f"Erwartet .png-Pfad, bekommen: {cmd[-1]}"
        assert kwargs.get("check") is True

    def test_opener_is_platform_appropriate(self):
        """Auf macOS wird 'open', auf Linux 'xdg-open' als Opener verwendet."""
        fake_img = _make_fake_img()

        for platform, expected_opener in [("darwin", "open"), ("linux", "xdg-open")]:
            with patch.object(sys, "argv", ["show_qr.py", "test-key"]), \
                 patch("show_qr.qrcode.make", return_value=fake_img), \
                 patch("show_qr.subprocess.run") as mock_run, \
                 patch("show_qr.atexit.register"), \
                 patch("show_qr.sys.platform", platform):
                show_qr.main()

            cmd = mock_run.call_args[0][0]
            assert cmd[0] == expected_opener, (
                f"Auf '{platform}' erwartet '{expected_opener}', bekommen '{cmd[0]}'"
            )


# ---------------------------------------------------------------------------
# Fehlerfall: subprocess wirft CalledProcessError
# ---------------------------------------------------------------------------

class TestSubprocessError:
    """Wenn subprocess.run fehlschlägt, soll die Exception nicht verschluckt werden."""

    def test_subprocess_error_propagates(self):
        """CalledProcessError von subprocess.run wird nach oben weitergegeben."""
        fake_img = _make_fake_img()
        error = subprocess.CalledProcessError(returncode=1, cmd=["open", "/tmp/x.png"])

        with patch.object(sys, "argv", ["show_qr.py", "some-key"]), \
             patch("show_qr.qrcode.make", return_value=fake_img), \
             patch("show_qr.subprocess.run", side_effect=error), \
             patch("show_qr.atexit.register"):
            with pytest.raises(subprocess.CalledProcessError):
                show_qr.main()


# ---------------------------------------------------------------------------
# Cleanup-Verhalten: _register_cleanup und atexit-Handler
# ---------------------------------------------------------------------------

class TestCleanup:
    """Stellt sicher, dass die Temporärdatei korrekt aufgeräumt wird."""

    def test_atexit_register_called_with_cleanup_fn(self):
        """Nach dem Öffnen des QR-Codes muss atexit.register mit einer Funktion
        aufgerufen worden sein, die den tmp-Pfad enthält."""
        fake_img = _make_fake_img()
        registered_fns = []

        def capture_register(fn):
            registered_fns.append(fn)

        with patch.object(sys, "argv", ["show_qr.py", "cleanup-key"]), \
             patch("show_qr.qrcode.make", return_value=fake_img), \
             patch("show_qr.subprocess.run"), \
             patch("show_qr.atexit.register", side_effect=capture_register):
            show_qr.main()

        assert len(registered_fns) == 1, "Genau eine atexit-Funktion erwartet"

    def test_cleanup_deletes_file(self, tmp_path):
        """Der _cleanup-Closure löscht die angegebene Datei."""
        dummy = tmp_path / "qr_test.png"
        dummy.write_bytes(b"fake")
        assert dummy.exists()

        show_qr._register_cleanup(str(dummy))

        # Direkt über atexit registrierte Funktion ist schwer zu isolieren,
        # daher testen wir _register_cleanup indirekt: Wir rufen den internen
        # Cleanup direkt über ein echtes atexit-Registrar-Capture auf.
        registered = []
        with patch("show_qr.atexit.register", side_effect=lambda fn: registered.append(fn)):
            show_qr._register_cleanup(str(dummy))

        assert len(registered) == 1
        registered[0]()  # Cleanup-Funktion ausführen
        assert not dummy.exists(), "Temporärdatei wurde nicht gelöscht"

    def test_cleanup_ignores_missing_file(self, tmp_path):
        """Der atexit-Handler darf nicht crashen, wenn die Datei schon fehlt."""
        missing = str(tmp_path / "already_gone.png")

        registered = []
        with patch("show_qr.atexit.register", side_effect=lambda fn: registered.append(fn)):
            show_qr._register_cleanup(missing)

        # Kein Fehler erwartet
        registered[0]()
