import 'package:flutter/material.dart';

import '../core/theme.dart';

/// TabBar con indicador tipo "pill" flotando dentro de un contenedor
/// redondeado, en vez del subrayado plano por defecto de Material (que se
/// veía como pestañas de carpeta/navegador -- ver feedback de audio
/// 2026-08-28). Reemplaza visualmente al `TabBar` de M3 sin cambiar su
/// comportamiento: mismo `TabController`, mismas pestañas.
class PillTabBar extends StatelessWidget implements PreferredSizeWidget {
  const PillTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.isScrollable = false,
  });

  final List<Widget> tabs;
  final TabController? controller;
  final bool isScrollable;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: isScrollable,
        tabAlignment: isScrollable ? TabAlignment.start : TabAlignment.fill,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(AppRadius.full),
        indicator: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        labelColor: AppColors.onPrimaryContainer,
        unselectedLabelColor: AppColors.onSurfaceVariant,
        labelStyle: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        tabs: tabs,
      ),
    );
  }
}
