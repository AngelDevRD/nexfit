import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'muscle_analysis_tab.dart';
import 'progress_tab.dart';
import 'strength_profile_tab.dart';
import 'strength_standards_tab.dart';
import 'tonnage_tab.dart';

const _sections = ['Músculos', 'Fuerza', 'Progreso', 'Tonelaje', 'Estándares'];

/// N1: antes montaba su propio `TabBar`/`TabBarView` -- un segundo nivel de
/// navegación horizontal DENTRO del `PillTabBar` de [ProgresoHubScreen], con
/// estilo distinto (subrayado plano de Material) y un `TabBarView` peleándose
/// el gesto de swipe con el de afuera. Acá no hay ningún `TabBar`: un selector
/// de chips (mismo lenguaje visual que los filtros del resto de la app, no
/// una segunda fila de pestañas) más un `IndexedStack` -- cada sección ya es
/// una pantalla scrolleable/con gráfico propio, así que apilarlas en un solo
/// scroll largo (la otra opción que planteaba la auditoría) las rompería.
class StatsHubScreen extends StatefulWidget {
  const StatsHubScreen({super.key});

  @override
  State<StatsHubScreen> createState() => _StatsHubScreenState();
}

class _StatsHubScreenState extends State<StatsHubScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionSelector(
          index: _index,
          onChanged: (i) => setState(() => _index = i),
        ),
        Expanded(
          child: IndexedStack(
            index: _index,
            children: const [
              MuscleAnalysisTab(),
              StrengthProfileTab(),
              ProgressTab(),
              TonnageTab(),
              StrengthStandardsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionSelector extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _SectionSelector({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: _sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) {
          final selected = i == index;
          return Material(
            color: selected
                ? AppColors.primaryContainer.withValues(alpha: 0.15)
                : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.full),
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : AppColors.outlineVariant,
                  ),
                ),
                child: Text(
                  _sections[i],
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
