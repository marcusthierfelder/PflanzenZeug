import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_key_provider.dart';
import 'qr_scanner_screen.dart';

class ApiKeySettingsScreen extends ConsumerStatefulWidget {
  const ApiKeySettingsScreen({super.key});

  @override
  ConsumerState<ApiKeySettingsScreen> createState() =>
      _ApiKeySettingsScreenState();
}

class _ApiKeySettingsScreenState extends ConsumerState<ApiKeySettingsScreen> {
  final _controller = TextEditingController();
  bool _obscureText = true;
  bool _showManualInput = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final apiKey = ref.watch(apiKeyProvider);
    final currentKey = apiKey.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('API Key')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    currentKey != null ? Icons.check_circle : Icons.cancel,
                    color: currentKey != null ? Colors.green : theme.colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      currentKey != null
                          ? 'Key gesetzt: ${_maskKey(currentKey)}'
                          : 'Kein API Key hinterlegt',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Key ändern', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          if (Platform.isIOS || Platform.isAndroid) ...[
            FilledButton.icon(
              onPressed: _pasteFromClipboard,
              icon: const Icon(Icons.content_paste),
              label: const Text('Aus Zwischenablage einfügen'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _scanQrCode,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('QR-Code scannen'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _showManualInput = !_showManualInput),
              child: Text(_showManualInput ? 'Manuell verbergen' : 'Manuell eingeben'),
            ),
          ],
          if (_showManualInput || !(Platform.isIOS || Platform.isAndroid)) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              obscureText: _obscureText,
              decoration: InputDecoration(
                hintText: 'sk-ant-...',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.key),
                suffixIcon: IconButton(
                  icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saveManual,
              icon: const Icon(Icons.check),
              label: const Text('Speichern'),
            ),
          ],
          if (currentKey != null) ...[
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _deleteKey,
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              label: Text('Key löschen', style: TextStyle(color: theme.colorScheme.error)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _maskKey(String key) {
    if (key.length <= 12) return '••••••••';
    return '${key.substring(0, 8)}••••${key.substring(key.length - 4)}';
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zwischenablage ist leer')),
        );
      }
      return;
    }
    await ref.read(apiKeyProvider.notifier).setApiKey(text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Key gespeichert')),
      );
    }
  }

  Future<void> _scanQrCode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (result != null && mounted) {
      await ref.read(apiKeyProvider.notifier).setApiKey(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API Key gespeichert')),
        );
      }
    }
  }

  Future<void> _saveManual() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen Key eingeben')),
      );
      return;
    }
    await ref.read(apiKeyProvider.notifier).setApiKey(key);
    _controller.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Key gespeichert')),
      );
    }
  }

  Future<void> _deleteKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Key löschen?'),
        content: const Text('Die App kann dann keine Pflanzen mehr analysieren.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(apiKeyProvider.notifier).clearApiKey();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API Key gelöscht')),
        );
      }
    }
  }
}
