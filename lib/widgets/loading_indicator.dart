import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  final String message;
  final String? subtitle;

  const LoadingIndicator({super.key, required this.message, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
