import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../api/models.dart';
import '../state/session.dart';
import '../widgets/common.dart';

class NewClaimScreen extends StatefulWidget {
  const NewClaimScreen({super.key});

  @override
  State<NewClaimScreen> createState() => _NewClaimScreenState();
}

class _NewClaimScreenState extends State<NewClaimScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _amount = TextEditingController();

  List<Policy>? _policies;
  String? _error;
  int? _policyId;
  bool _saving = false;

  // Optional photo, e.g. of the vet bill. Resized/compressed before upload.
  Uint8List? _photo;
  String _photoName = 'photo.jpg';

  @override
  void initState() {
    super.initState();
    _loadPolicies();
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _loadPolicies() async {
    setState(() => _error = null);
    try {
      final policies = await SessionScope.read(context).api.policies();
      if (!mounted) return;
      setState(() {
        _policies = policies;
        _policyId = policies.isNotEmpty ? policies.first.id : null;
      });
    } catch (e) {
      if (!mounted) return;
      showApiError(context, e);
      setState(() => _error = e.toString());
    }
  }

  Policy? get _selectedPolicy {
    for (final p in _policies ?? const <Policy>[]) {
      if (p.id == _policyId) return p;
    }
    return null;
  }

  double? get _parsedAmount => double.tryParse(_amount.text.trim().replaceAll(',', '.'));

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (file == null) return; // cancelled
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = bytes;
        _photoName = file.name;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the camera or gallery.')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final api = SessionScope.read(context).api;
    try {
      final claim = await api.submitClaim(
        policyId: _policyId!,
        description: _description.text.trim(),
        amount: _parsedAmount!,
      );
      String message = 'Claim submitted. We will review it shortly.';
      final photo = _photo;
      if (photo != null) {
        try {
          await api.uploadClaimPhoto(claim.id, photo, filename: _photoName);
        } catch (e) {
          message = 'Claim submitted, but the photo could not be uploaded: $e';
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final policies = _policies;
    Widget body;
    if (policies == null && _error != null) {
      body = ErrorRetry(message: _error!, onRetry: _loadPolicies);
    } else if (policies == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (policies.isEmpty) {
      body = const EmptyState(
        icon: Icons.pets,
        title: 'No policies yet',
        message: 'Add a pet on the Pets tab first, then you can claim for it here.',
      );
    } else {
      body = _buildForm(policies);
    }
    return Scaffold(appBar: AppBar(title: const Text('New claim')), body: SafeArea(child: body));
  }

  Widget _buildForm(List<Policy> policies) {
    final coverage = _selectedPolicy?.coverageAmount;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<int>(
            value: _policyId,
            decoration: const InputDecoration(labelText: 'Pet', border: OutlineInputBorder()),
            items: [
              for (final p in policies)
                DropdownMenuItem(value: p.id, child: Text(p.petName ?? 'Policy #${p.id}')),
            ],
            onChanged: (id) => setState(() => _policyId = id),
            validator: (id) => id == null ? 'Choose a pet' : null,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '\$ ',
              helperText: coverage == null ? null : 'Up to ${formatMoney(coverage)}',
              border: const OutlineInputBorder(),
            ),
            validator: (_) {
              final amount = _parsedAmount;
              if (amount == null || amount <= 0) return 'Enter the amount you paid';
              if (coverage != null && amount > coverage) {
                return 'The maximum is ${formatMoney(coverage)}';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _description,
            minLines: 4,
            maxLines: 8,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What happened?',
              hintText: 'E.g. vet visit for an ear infection on 3 October',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.trim().length < 10)
                ? 'Please describe it in at least 10 characters'
                : null,
          ),
          const SizedBox(height: 8),
          _PhotoPicker(
            photo: _photo,
            onPick: _saving ? null : _pickPhoto,
            onRemove: _saving ? null : () => setState(() => _photo = null),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _submit,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit claim'),
          ),
        ],
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.photo, required this.onPick, required this.onRemove});

  final Uint8List? photo;
  final void Function(ImageSource source)? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = photo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photo of the vet bill (optional)', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        if (image != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(image, height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: IconButton.filled(
                  tooltip: 'Remove photo',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPick == null ? null : () => onPick!(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Take photo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPick == null ? null : () => onPick!(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
