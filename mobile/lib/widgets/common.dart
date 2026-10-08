import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../state/session.dart';

/// Shows an API error. A 401 while signed in means the session expired: sign out and
/// return to login. A 401 while signed out (e.g. wrong password) just shows the message.
void showApiError(BuildContext context, Object error) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final session = SessionScope.read(context);
  if (error is ApiException && error.isUnauthorized && session.isLoggedIn) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    session.logout();
    messenger.showSnackBar(
      const SnackBar(content: Text('Your session expired. Please log in again.')),
    );
    return;
  }
  messenger.showSnackBar(SnackBar(content: Text(error.toString())));
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ListView so pull-to-refresh still works on an empty screen.
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Icon(icon, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (action != null) ...[
          const SizedBox(height: 24),
          Center(child: action!),
        ],
      ],
    );
  }
}

/// Required for Google Play: makes clear no real insurance is provided.
class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Demo app: no real insurance is sold or provided, and no claims are paid out.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
