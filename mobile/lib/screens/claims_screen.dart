import 'package:flutter/material.dart';

import '../api/models.dart';
import '../state/session.dart';
import '../widgets/common.dart';
import 'new_claim_screen.dart';

class ClaimsScreen extends StatefulWidget {
  const ClaimsScreen({super.key});

  @override
  State<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends State<ClaimsScreen> {
  List<Claim>? _claims;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = SessionScope.read(context).api;
    try {
      final claims = await api.claims();
      if (!mounted) return;
      setState(() {
        _claims = claims;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      showApiError(context, e);
      setState(() => _error = e.toString());
    }
  }

  Future<void> _newClaim() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NewClaimScreen()),
    );
    if (submitted == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final claims = _claims;
    Widget body;
    if (claims == null && _error != null) {
      body = ErrorRetry(message: _error!, onRetry: _load);
    } else if (claims == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (claims.isEmpty) {
      body = RefreshIndicator(
        onRefresh: _load,
        child: const EmptyState(
          icon: Icons.receipt_long,
          title: 'No claims yet',
          message: 'When your pet needs the vet, submit a claim here and track its status.',
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          itemCount: claims.length,
          itemBuilder: (context, i) => _ClaimCard(claim: claims[i]),
        ),
      );
    }

    return Scaffold(
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newClaim,
        icon: const Icon(Icons.add),
        label: const Text('New claim'),
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.claim});

  final Claim claim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color bg, Color fg) = switch (claim.status.toLowerCase()) {
      'approved' => (Colors.green.shade100, Colors.green.shade900),
      'rejected' => (theme.colorScheme.errorContainer, theme.colorScheme.onErrorContainer),
      _ => (theme.colorScheme.tertiaryContainer, theme.colorScheme.onTertiaryContainer),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${claim.petName ?? 'Pet'} · ${formatMoney(claim.amount)}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                  child: Text(claim.status, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(claim.description),
            if (claim.hasPhoto) ...[
              const SizedBox(height: 12),
              _ClaimPhoto(claimId: claim.id),
            ],
            const SizedBox(height: 4),
            Text('Claim #${claim.id}', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Thumbnail of a claim's photo; tap to view it full screen.
class _ClaimPhoto extends StatelessWidget {
  const _ClaimPhoto({required this.claimId});

  final int claimId;

  @override
  Widget build(BuildContext context) {
    final api = SessionScope.read(context).api;
    final url = api.claimPhotoUrl(claimId);
    final headers = api.authHeaders;

    Widget image({BoxFit fit = BoxFit.cover, double? height}) => Image.network(
          url,
          headers: headers,
          height: height,
          width: double.infinity,
          fit: fit,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : SizedBox(height: height ?? 200, child: const Center(child: CircularProgressIndicator())),
          errorBuilder: (context, error, stack) => SizedBox(
            height: height ?? 200,
            child: const Center(child: Text('Photo could not be loaded')),
          ),
        );

    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(child: InteractiveViewer(child: image(fit: BoxFit.contain))),
              Positioned(
                top: 8,
                right: 8,
                child: SafeArea(
                  child: IconButton.filled(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: image(height: 140),
      ),
    );
  }
}
