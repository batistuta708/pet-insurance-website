import 'package:flutter/material.dart';

import '../api/models.dart';
import '../state/session.dart';
import '../widgets/common.dart';
import 'add_pet_screen.dart';

class PetsScreen extends StatefulWidget {
  const PetsScreen({super.key});

  @override
  State<PetsScreen> createState() => _PetsScreenState();
}

class _PetsScreenState extends State<PetsScreen> {
  List<Pet>? _pets;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = SessionScope.read(context).api;
    try {
      final pets = await api.pets();
      if (!mounted) return;
      setState(() {
        _pets = pets;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      showApiError(context, e);
      setState(() => _error = e.toString());
    }
  }

  Future<void> _addPet() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddPetScreen()),
    );
    if (added == true) _load();
  }

  Future<void> _editPet(Pet pet) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddPetScreen(pet: pet)),
    );
    if (saved == true) _load();
  }

  Future<void> _deletePet(Pet pet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${pet.name}?'),
        content: const Text('This cancels the policy and deletes its claims. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await SessionScope.read(context).api.deletePet(pet.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${pet.name} removed.')));
      _load();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pets = _pets;
    Widget body;
    if (pets == null && _error != null) {
      body = ErrorRetry(message: _error!, onRetry: _load);
    } else if (pets == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (pets.isEmpty) {
      body = RefreshIndicator(
        onRefresh: _load,
        child: EmptyState(
          icon: Icons.pets,
          title: 'No pets yet',
          message: 'Add your pet to get an instant quote and start their cover.',
          action: FilledButton.icon(
            onPressed: _addPet,
            icon: const Icon(Icons.add),
            label: const Text('Add a pet'),
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          itemCount: pets.length,
          itemBuilder: (context, i) => _PetCard(
            pet: pets[i],
            onEdit: () => _editPet(pets[i]),
            onDelete: () => _deletePet(pets[i]),
          ),
        ),
      );
    }

    return Scaffold(
      body: body,
      floatingActionButton: (pets?.isNotEmpty ?? false)
          ? FloatingActionButton.extended(
              onPressed: _addPet,
              icon: const Icon(Icons.add),
              label: const Text('Add pet'),
            )
          : null,
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({required this.pet, required this.onEdit, required this.onDelete});

  final Pet pet;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  IconData get _icon => switch (pet.type) {
        'Dog' => Icons.pets,
        'Cat' => Icons.cruelty_free,
        _ => Icons.emoji_nature,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final policy = pet.policy;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(_icon, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pet.name, style: theme.textTheme.titleMedium),
                  Text('${pet.type} · ${pet.age} ${pet.age == 1 ? 'year' : 'years'} old'),
                  const SizedBox(height: 6),
                  Text(
                    policy == null
                        ? 'No active policy'
                        : '${formatMoney(policy.monthlyPremium)}/month · covered up to ${formatMoney(policy.coverageAmount)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit ${pet.name}',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Remove ${pet.name}',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
        ),
      ),
    );
  }
}
