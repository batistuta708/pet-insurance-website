import 'package:flutter/material.dart';

import '../config.dart';
import '../state/session.dart';
import '../widgets/common.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  /// Website root, derived from the API URL (…/api/v1 → …).
  static String get _siteUrl => apiBaseUrl.replaceFirst(RegExp(r'/api/v\d+/?$'), '');

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your account, your pets, their policies and all claims. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SessionScope.read(context).deleteAccount();
      messenger.showSnackBar(const SnackBar(content: Text('Your account has been deleted.')));
    } catch (e) {
      if (context.mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final theme = Theme.of(context);
    return ListView(
      children: [
        const SizedBox(height: 24),
        CircleAvatar(
          radius: 36,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.person, size: 36, color: theme.colorScheme.onPrimaryContainer),
        ),
        const SizedBox(height: 12),
        Text(
          session.user?.email ?? '',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy policy'),
          subtitle: Text('$_siteUrl/privacy'),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Log out'),
          onTap: () => session.logout(),
        ),
        ListTile(
          leading: Icon(Icons.delete_forever, color: theme.colorScheme.error),
          title: Text('Delete account', style: TextStyle(color: theme.colorScheme.error)),
          onTap: () => _confirmDelete(context),
        ),
      ],
    );
  }
}
