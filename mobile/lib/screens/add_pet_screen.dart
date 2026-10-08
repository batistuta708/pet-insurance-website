import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/models.dart';
import '../state/session.dart';
import '../widgets/common.dart';

const petTypes = ['Dog', 'Cat', 'Other'];

/// Adds a new pet, or edits [pet] when given (name, type and age; the premium is recalculated).
class AddPetScreen extends StatefulWidget {
  const AddPetScreen({super.key, this.pet});

  final Pet? pet;

  @override
  State<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  String _type = petTypes.first;

  Quote? _quote;
  bool _quoting = false;
  bool _saving = false;
  Timer? _debounce;

  bool get _editing => widget.pet != null;

  @override
  void initState() {
    super.initState();
    final pet = widget.pet;
    if (pet != null) {
      _name.text = pet.name;
      _age.text = '${pet.age}';
      _type = petTypes.contains(pet.type) ? pet.type : 'Other';
      // Show the current price straight away.
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshQuote());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  int? get _parsedAge {
    final age = int.tryParse(_age.text.trim());
    return (age != null && age >= 0 && age <= 30) ? age : null;
  }

  /// Fetches a live price preview shortly after the user stops typing.
  void _refreshQuote() {
    _debounce?.cancel();
    final age = _parsedAge;
    if (age == null) {
      setState(() => _quote = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _quoting = true);
      try {
        final quote = await SessionScope.read(context).api.quote(_type, age);
        // Ignore stale answers if the inputs changed in the meantime.
        if (mounted && quote.type == _type && quote.age == _parsedAge) {
          setState(() => _quote = quote);
        }
      } catch (_) {
        // The price preview is optional; the server re-checks on save.
      } finally {
        if (mounted) setState(() => _quoting = false);
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final api = SessionScope.read(context).api;
      final existing = widget.pet;
      final pet = existing == null
          ? await api.addPet(name: _name.text.trim(), type: _type, age: _parsedAge!)
          : await api.updatePet(existing.id, name: _name.text.trim(), type: _type, age: _parsedAge!);
      if (!mounted) return;
      final premium = pet.policy?.monthlyPremium;
      final String message;
      if (existing != null) {
        message = premium == null
            ? '${pet.name} updated.'
            : '${pet.name} updated: now ${formatMoney(premium)}/month.';
      } else {
        message = premium == null
            ? '${pet.name} added.'
            : '${pet.name} is covered for ${formatMoney(premium)}/month.';
      }
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit ${widget.pet!.name}' : 'Add a pet')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: "Pet's name",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 8),
              Text('Type', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Dog', label: Text('Dog'), icon: Icon(Icons.pets)),
                  ButtonSegment(value: 'Cat', label: Text('Cat'), icon: Icon(Icons.cruelty_free)),
                  ButtonSegment(value: 'Other', label: Text('Other'), icon: Icon(Icons.emoji_nature)),
                ],
                selected: {_type},
                onSelectionChanged: (s) {
                  setState(() => _type = s.first);
                  _refreshQuote();
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _age,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Age in years',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _refreshQuote(),
                validator: (_) => _parsedAge == null ? 'Enter an age between 0 and 30' : null,
              ),
              const SizedBox(height: 24),
              _QuoteCard(quote: _quote, loading: _quoting),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_editing ? 'Save changes' : 'Add pet and start cover'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote, required this.loading});

  final Quote? quote;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = quote;
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.request_quote_outlined, color: theme.colorScheme.onSecondaryContainer),
            const SizedBox(width: 16),
            Expanded(
              child: q == null
                  ? Text(loading ? 'Calculating…' : 'Enter the age to see your price.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${formatMoney(q.monthlyPremium)} / month',
                            style: theme.textTheme.headlineSmall),
                        Text('Covered up to ${formatMoney(q.coverageAmount)}'),
                      ],
                    ),
            ),
            if (loading && q != null)
              const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}
