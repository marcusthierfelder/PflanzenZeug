import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/capture_context_tag.dart';

/// Maximal erlaubte Fotos pro Session.
const int _kMaxPhotos = 10;

/// Lux-Schwellenwerte für den Licht-Indikator (basierend auf relativer Luminanz).
/// Die Luminanz wird aus den Preview-Frames abgeleitet (0–255 Mittelwert).
/// Mapping: avg_luminance → relative Lux-Einschätzung.
const double _kLuminanceGood = 100.0; // > 100 → grün
const double _kLuminanceMedium = 50.0; // 50–100 → orange
// < 50 → rot (schlecht)

enum _LightLevel { good, medium, poor }

/// Ergebnis des BurstCameraScreens: aufgenommene Fotos + optionaler Kontext-Tag.
class BurstCameraResult {
  final List<File> photos;
  final CaptureContextTag? contextTag;

  const BurstCameraResult({required this.photos, this.contextTag});
}

/// Vollbild-Kamera-Screen für Burst-Aufnahmen mit Kontext-Tagging und Licht-Indikator.
///
/// Gibt `null` zurück wenn abgebrochen, sonst ein [BurstCameraResult].
///
/// Aufruf:
/// ```dart
/// final result = await Navigator.of(context).push<BurstCameraResult>(
///   MaterialPageRoute(builder: (_) => const BurstCameraScreen()),
/// );
/// ```
class BurstCameraScreen extends StatefulWidget {
  const BurstCameraScreen({super.key});

  @override
  State<BurstCameraScreen> createState() => _BurstCameraScreenState();
}

class _BurstCameraScreenState extends State<BurstCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitializing = true;
  bool _isTakingPhoto = false;
  bool _showFlash = false;
  String? _errorMessage;

  final List<File> _capturedPhotos = [];

  // Kontext-Tagging
  CaptureContextTag? _activeTag;

  // Licht-Indikator
  _LightLevel _lightLevel = _LightLevel.good;
  double _lastLuminance = 255.0;
  int _frameSkipCounter = 0;
  static const int _kFrameSkip = 15; // Alle N Frames auswerten

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller?.stopImageStream().catchError((_) {});
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (state == AppLifecycleState.inactive) {
      if (ctrl != null && ctrl.value.isInitialized) {
        ctrl.stopImageStream().catchError((_) {});
        ctrl.dispose();
        if (mounted) setState(() => _controller = null);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (ctrl == null || !ctrl.value.isInitialized) {
        _initCamera();
      }
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _errorMessage = 'Keine Kamera gefunden.';
          _isInitializing = false;
        });
        return;
      }

      final camera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final ctrl = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }

      // Live-Stream für Licht-Indikator starten
      await ctrl.startImageStream(_onCameraFrame);

      setState(() {
        _controller = ctrl;
        _isInitializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Kamera konnte nicht geöffnet werden:\n$e';
        _isInitializing = false;
      });
    }
  }

  /// Verarbeitet jeden N-ten Frame und berechnet mittlere Luminanz (Y-Kanal YUV420).
  void _onCameraFrame(CameraImage image) {
    _frameSkipCounter++;
    if (_frameSkipCounter < _kFrameSkip) return;
    _frameSkipCounter = 0;

    try {
      // Y-Plane (Luma) aus YUV420 auslesen
      final yPlane = image.planes.first;
      final bytes = yPlane.bytes;

      // Stichproben-Sampling (jeder 32. Pixel) für Performance
      double sum = 0;
      int count = 0;
      for (int i = 0; i < bytes.length; i += 32) {
        sum += bytes[i];
        count++;
      }
      final avg = count > 0 ? sum / count : 128.0;

      final level = avg > _kLuminanceGood
          ? _LightLevel.good
          : avg > _kLuminanceMedium
              ? _LightLevel.medium
              : _LightLevel.poor;

      if (level != _lightLevel || (avg - _lastLuminance).abs() > 5) {
        _lastLuminance = avg;
        if (mounted) {
          setState(() => _lightLevel = level);
        }
      }
    } catch (_) {
      // Frame-Verarbeitung ist best-effort
    }
  }

  Future<void> _takePhoto() async {
    final ctrl = _controller;
    if (ctrl == null ||
        !ctrl.value.isInitialized ||
        _isTakingPhoto ||
        _capturedPhotos.length >= _kMaxPhotos) {
      return;
    }

    setState(() => _isTakingPhoto = true);
    _triggerFlash();

    try {
      // Stream kurz pausieren für Foto
      await ctrl.stopImageStream();
      final xfile = await ctrl.takePicture();
      // Stream wieder starten
      await ctrl.startImageStream(_onCameraFrame);

      if (!mounted) return;
      setState(() {
        _capturedPhotos.add(File(xfile.path));
      });

      // Post-Capture Licht-Warnung bei schlechtem Score
      if (_lightLevel == _LightLevel.poor && mounted) {
        final retry = await _showLightWarningDialog();
        if (retry == true && mounted) {
          // Letztes Foto entfernen und neu versuchen
          setState(() => _capturedPhotos.removeLast());
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aufnahme fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _isTakingPhoto = false);
    }
  }

  Future<bool?> _showLightWarningDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.wb_sunny_outlined, color: Colors.orange, size: 32),
        title: const Text('Zu wenig Licht'),
        content: const Text(
          'Das Foto könnte durch schlechte Beleuchtung unscharf oder zu dunkel sein.\n\n'
          'Tipp: Geh näher ans Fenster oder schalte eine Lampe ein.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Trotzdem analysieren'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            onPressed: () => Navigator.of(ctx).pop(true),
            label: const Text('Wiederholen'),
          ),
        ],
      ),
    );
  }

  void _triggerFlash() {
    setState(() => _showFlash = true);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _showFlash = false);
    });
  }

  void _removePhoto(int index) {
    setState(() => _capturedPhotos.removeAt(index));
  }

  void _finish() {
    final result = _capturedPhotos.isEmpty
        ? null
        : BurstCameraResult(
            photos: List<File>.from(_capturedPhotos),
            contextTag: _activeTag,
          );
    Navigator.of(context).pop(result);
  }

  void _cancel() {
    Navigator.of(context).pop(null);
  }

  void _selectTag(CaptureContextTag tag) {
    setState(() {
      // Tap auf aktiven Tag → deselektieren
      if (_activeTag?.key == tag.key &&
          !(tag.key == CaptureTagKey.custom)) {
        _activeTag = null;
      } else {
        _activeTag = tag;
      }
    });
  }

  Future<void> _openCustomTagInput() async {
    final currentText = _activeTag?.key == CaptureTagKey.custom
        ? _activeTag?.customText ?? ''
        : '';

    final controller = TextEditingController(text: currentText);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag-Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              '✏️ Eigener Kontext',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Beschreibe kurz, was du fotografierst (max. 60 Zeichen)',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 60,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'z. B. Stamm, Stecklinge, Knollen …',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                counterStyle: const TextStyle(color: Colors.white54),
              ),
              onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    style: TextButton.styleFrom(foregroundColor: Colors.white60),
                    child: const Text('Abbrechen'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.of(ctx).pop(controller.text.trim()),
                    child: const Text('Übernehmen'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (result.isEmpty) {
          // Leerer Text → Tag entfernen
          if (_activeTag?.key == CaptureTagKey.custom) _activeTag = null;
        } else {
          _activeTag = CaptureContextTag(
            key: CaptureTagKey.custom,
            customText: result,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Kamera-Vorschau ──────────────────────────────────────
          if (_isInitializing)
            const Center(
                child: CircularProgressIndicator(color: Colors.white))
          else if (_errorMessage != null)
            _buildError()
          else
            _buildCameraPreview(),

          // ── Weißblitz-Overlay ────────────────────────────────────
          if (_showFlash) const ColoredBox(color: Colors.white),

          // ── Licht-Indikator (oben rechts im Viewfinder) ──────────
          if (!_isInitializing && _errorMessage == null)
            _buildLightIndicator(),

          // ── Top-Bar ──────────────────────────────────────────────
          _buildTopBar(),

          // ── Bottom-Bereich ───────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final ctrl = _controller!;
    return GestureDetector(
      onTapDown: (details) => _onTapToFocus(details, context),
      child: CameraPreview(ctrl),
    );
  }

  Future<void> _onTapToFocus(
      TapDownDetails details, BuildContext context) async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final size = MediaQuery.of(context).size;
    final x = details.globalPosition.dx / size.width;
    final y = details.globalPosition.dy / size.height;
    try {
      await ctrl.setFocusPoint(Offset(x, y));
      await ctrl.setExposurePoint(Offset(x, y));
    } catch (_) {}
  }

  // ── Licht-Indikator ──────────────────────────────────────────────────────

  Widget _buildLightIndicator() {
    final color = switch (_lightLevel) {
      _LightLevel.good => const Color(0xFF4CAF50),
      _LightLevel.medium => const Color(0xFFFF9800),
      _LightLevel.poor => const Color(0xFFF44336),
    };
    final icon = switch (_lightLevel) {
      _LightLevel.good => Icons.wb_sunny,
      _LightLevel.medium => Icons.wb_sunny_outlined,
      _LightLevel.poor => Icons.wb_cloudy_outlined,
    };
    final label = switch (_lightLevel) {
      _LightLevel.good => 'Gutes Licht',
      _LightLevel.medium => 'Mittleres Licht',
      _LightLevel.poor => 'Zu dunkel',
    };

    return Positioned(
      top: MediaQuery.of(context).padding.top + 56,
      right: 12,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top-Bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              _CircleIconButton(
                icon: Icons.close,
                onPressed: _cancel,
                tooltip: 'Abbrechen',
              ),
              const Spacer(),
              if (_capturedPhotos.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_capturedPhotos.length}/$_kMaxPhotos',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom-Controls ──────────────────────────────────────────────────────

  Widget _buildBottomControls() {
    final reachedMax = _capturedPhotos.length >= _kMaxPhotos;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
          stops: [0.0, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Tag-Chip-Leiste ──────────────────────────────────
            _buildTagChipRow(),

            // ── Wurzeln-Hinweis-Banner ───────────────────────────
            if (_activeTag?.showRootBanner == true)
              _buildRootBanner(),

            const SizedBox(height: 8),

            // ── Vorschau-Strip ───────────────────────────────────
            if (_capturedPhotos.isNotEmpty) _buildPhotoStrip(),

            const SizedBox(height: 16),

            // ── Auslöser + Fertig ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 72),

                  // Auslöser
                  GestureDetector(
                    onTap: reachedMax ? null : _takePhoto,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isTakingPhoto
                            ? Colors.white60
                            : reachedMax
                                ? Colors.white24
                                : Colors.white,
                        border: Border.all(color: Colors.white54, width: 4),
                      ),
                      child: reachedMax
                          ? const Icon(Icons.block,
                              color: Colors.white54, size: 28)
                          : null,
                    ),
                  ),

                  // Fertig-Button
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _capturedPhotos.isNotEmpty
                        ? SizedBox(
                            width: 72,
                            child: FilledButton(
                              key: const ValueKey('fertig'),
                              onPressed: _finish,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 12),
                              ),
                              child: const Text(
                                'Fertig',
                                style:
                                    TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          )
                        : const SizedBox(
                            width: 72, key: ValueKey('empty')),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (reachedMax)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Maximum $_kMaxPhotos Fotos erreicht',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Tag-Chip-Leiste ──────────────────────────────────────────────────────

  Widget _buildTagChipRow() {
    final tags = [
      CaptureContextTag(key: CaptureTagKey.leaf),
      CaptureContextTag(key: CaptureTagKey.root),
      CaptureContextTag(key: CaptureTagKey.flower),
    ];

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          ...tags.map((tag) => _buildTagChip(tag)),
          _buildCustomTagChip(),
        ],
      ),
    );
  }

  Widget _buildTagChip(CaptureContextTag tag) {
    final isActive = _activeTag?.key == tag.key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: _TagChip(
        label: tag.chipLabel,
        isActive: isActive,
        onTap: () => _selectTag(tag),
      ),
    );
  }

  Widget _buildCustomTagChip() {
    final isActive = _activeTag?.key == CaptureTagKey.custom;
    final customText = isActive ? _activeTag?.customText : null;
    final label = customText?.isNotEmpty == true
        ? '✏️ $customText'
        : '+ Eigenes';
    return _TagChip(
      label: label,
      isActive: isActive,
      onTap: _openCustomTagInput,
      isDashed: !isActive,
    );
  }

  // ── Wurzeln-Banner ───────────────────────────────────────────────────────

  Widget _buildRootBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Text('💡', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Luftwurzeln? Braun = normal bei Monstera & Philodendron',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Photo-Strip ──────────────────────────────────────────────────────────

  Widget _buildPhotoStrip() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: _capturedPhotos.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _PhotoStripItem(
              file: _capturedPhotos[index],
              onRemove: () => _removePhoto(index),
            ),
          );
        },
      ),
    );
  }

  // ── Error-State ──────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined,
                size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _initCamera,
              icon: const Icon(Icons.refresh),
              label: const Text('Erneut versuchen'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tag-Chip Widget
// ─────────────────────────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDashed;

  const _TagChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isDashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.95)
              : Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isActive
                ? Colors.white
                : isDashed
                    ? Colors.white38
                    : Colors.white54,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive) ...[
              const Icon(Icons.check, size: 14, color: Colors.black87),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.black87 : Colors.white,
                fontSize: 13,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Photo-Strip Item
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoStripItem extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;

  const _PhotoStripItem({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              file,
              width: 64,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black87,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Circle Icon Button
// ─────────────────────────────────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black54,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}


