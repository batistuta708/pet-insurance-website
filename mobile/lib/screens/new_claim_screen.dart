import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await SessionScope.read(context).api.submitClaim(
            policyId: _policyId!,
            description: _description.text.trim(),
            amount: _parsedAmount!,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Claim submitted. We will review it shortly.')),
      );
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
