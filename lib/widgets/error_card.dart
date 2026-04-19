import 'package:flutter/material.dart';

class ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorCard({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: theme.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(Icons.error, color: theme.colorScheme.error),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Nochmal versuchen'),
          ),
        ],
      ],
    );
  }
}
