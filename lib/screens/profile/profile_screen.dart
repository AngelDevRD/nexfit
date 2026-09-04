import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/weight_unit_provider.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  String? _sex;
  String? _goal;
  String? _experience;
  bool _saving = false;
  bool _initialized = false;

  void _initFromUser(AppUser user, WeightUnit weightUnit) {
    if (_initialized) return;
    _initialized = true;
    _ageController.text = user.age?.toString() ?? '';
    _heightController.text = user.heightCm?.toString() ?? '';
    _weightController.text = user.weightKg == null
        ? ''
        : kgToDisplay(user.weightKg!, weightUnit).toStringAsFixed(1);
    _bodyFatController.text = user.bodyFatPct?.toString() ?? '';
    _sex = user.sex;
    _goal = user.goal;
    _experience = user.experienceLevel;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    final weightUnit = context.read<WeightUnitProvider>().unit;
    final enteredWeight = double.tryParse(_weightController.text);
    final fields = <String, dynamic>{
      if (_ageController.text.isNotEmpty)
        'age': int.tryParse(_ageController.text),
      if (_sex != null) 'sex': _sex,
      if (_heightController.text.isNotEmpty)
        'height_cm': double.tryParse(_heightController.text),
      // El almacenamiento siempre es en kg -- se vuelve a convertir desde la
      // unidad elegida antes de guardar (U1).
      if (enteredWeight != null)
        'weight_kg': displayToKg(enteredWeight, weightUnit),
      if (_bodyFatController.text.isNotEmpty)
        'body_fat_pct': double.tryParse(_bodyFatController.text),
      if (_goal != null) 'goal': _goal,
      if (_experience != null) 'experience_level': _experience,
    };
    final ok = await auth.updateProfile(fields);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Perfil actualizado' : (auth.error ?? 'Error al guardar'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _bodyFatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final weightUnit = context.watch<WeightUnitProvider>().unit;
    if (user != null) _initFromUser(user, weightUnit);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: user == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Perfil',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.settings_outlined,
                            color: AppColors.onSurfaceVariant,
                          ),
                          tooltip: 'Ajustes',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.logout,
                            color: AppColors.onSurfaceVariant,
                          ),
                          tooltip: 'Cerrar sesión',
                          onPressed: () =>
                              context.read<AuthProvider>().logout(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.primaryContainer,
                              child: Text(
                                user.name.isNotEmpty
                                    ? user.name[0].toUpperCase()
                                    : '?',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: AppColors.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: Theme.of(context).textTheme.titleLarge,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  user.email,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ProfileSectionTitle(
                      icon: Icons.badge_outlined,
                      title: 'Datos físicos',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _ageController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Edad',
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _sex,
                                  decoration: const InputDecoration(
                                    labelText: 'Sexo',
                                  ),
                                  items: sexOptions.entries
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e.key,
                                          child: Text(e.value),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(() => _sex = v),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _heightController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Altura (cm)',
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: TextField(
                                  controller: _weightController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: 'Peso (${weightUnit.label})',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _bodyFatController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: '% Grasa corporal (opcional)',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ProfileSectionTitle(
                      icon: Icons.flag_outlined,
                      title: 'Objetivo y experiencia',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _goal,
                            decoration: const InputDecoration(
                              labelText: 'Objetivo',
                            ),
                            items: goalOptions.entries
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _goal = v),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          DropdownButtonFormField<String>(
                            initialValue: _experience,
                            decoration: const InputDecoration(
                              labelText: 'Nivel de experiencia',
                            ),
                            items: experienceOptions.entries
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _experience = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Guardar cambios'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ProfileSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ProfileSectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: AppColors.primary),
        ),
      ],
    );
  }
}
