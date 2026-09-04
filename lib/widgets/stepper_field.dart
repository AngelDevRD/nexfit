import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// Campo numérico tipo "stepper" (valor grande al centro + botones -/+),
/// usado en el registro de series del entrenamiento activo (export Stitch v2).
/// Reemplaza al `TextField` numérico plano de la v1 sin cambiar el tipo de
/// dato que produce (sigue siendo un `double`/`int` a través de [onChanged]).
///
/// Tocar el número edita EN EL LUGAR (C6) -- antes abría un `AlertDialog`
/// modal para escribir el valor a mano; ahora el mismo espacio se convierte
/// en un `TextField`, sin tapar el resto de la fila ni tener que cerrar nada
/// para volver a usar los botones +/-.
class StepperField extends StatefulWidget {
  const StepperField({
    super.key,
    required this.value,
    required this.onChanged,
    this.step = 1,
    this.decimals = 0,
    this.suffix,
    this.min = 0,
    this.fieldLabel,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double step;
  final int decimals;
  final String? suffix;
  final double min;

  /// D3: nombre del campo para lectores de pantalla ("peso", "repeticiones",
  /// "RPE") -- sin esto, un "+"/"−" sin contexto no dice qué está sumando o
  /// restando. `null` cuando el campo ya es obvio por el resto de la pantalla.
  final String? fieldLabel;

  @override
  State<StepperField> createState() => _StepperFieldState();
}

class _StepperFieldState extends State<StepperField> {
  bool _editing = false;
  TextEditingController? _controller;
  FocusNode? _focusNode;

  String get _label => widget.decimals > 0
      ? widget.value.toStringAsFixed(widget.decimals)
      : widget.value.round().toString();

  void _apply(double next) {
    if (next < widget.min) next = widget.min;
    widget.onChanged(double.parse(next.toStringAsFixed(widget.decimals)));
  }

  void _startEditing() {
    final controller = TextEditingController(text: _label);
    final focusNode = FocusNode();
    // Al perder el foco (tocar afuera, cambiar de fila) se confirma el valor
    // tipeado -- no hace falta un botón "Guardar" aparte.
    focusNode.addListener(() {
      if (!focusNode.hasFocus) _commitEditing(controller.text);
    });
    setState(() {
      _editing = true;
      _controller = controller;
      _focusNode = focusNode;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
    });
  }

  void _commitEditing(String text) {
    if (!_editing) return;
    final parsed = double.tryParse(text.replaceAll(',', '.'));
    if (parsed != null) _apply(parsed);
    _controller?.dispose();
    _focusNode?.dispose();
    setState(() {
      _editing = false;
      _controller = null;
      _focusNode = null;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _focusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // D4: `Flexible` (no un tamaño fijo) para que el botón se achique
          // en vez de desbordar en el caso extremo de 3 StepperField lado a
          // lado en 320dp + texto al 200% -- en cualquier ancho normal sigue
          // ocupando su tamaño natural (más grande, D3), esto solo entra en
          // juego cuando de verdad no entra.
          Flexible(
            child: _StepButton(
              icon: Icons.remove,
              semanticLabel: widget.fieldLabel == null
                  ? 'Restar'
                  : 'Restar ${widget.fieldLabel}',
              onTap: _editing ? null : () => _apply(widget.value - widget.step),
            ),
          ),
          Expanded(
            child: _editing
                ? TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: widget.decimals > 0,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(widget.decimals > 0 ? r'[0-9.,]' : r'[0-9]'),
                      ),
                    ],
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                    onSubmitted: _commitEditing,
                  )
                : Semantics(
                    label: widget.fieldLabel == null
                        ? 'Editar valor, $_label'
                        : 'Editar ${widget.fieldLabel}, $_label',
                    button: true,
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      onTap: _startEditing,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _label,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (widget.suffix != null)
                            Text(
                              widget.suffix!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppColors.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
          Flexible(
            child: _StepButton(
              icon: Icons.add,
              semanticLabel: widget.fieldLabel == null
                  ? 'Sumar'
                  : 'Sumar ${widget.fieldLabel}',
              onTap: _editing ? null : () => _apply(widget.value + widget.step),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    // D3: el target de toque real quedaba en ~26dp (padding xs=4 + ícono
    // 18) -- por debajo del mínimo recomendado. Este stepper vive en una
    // fila de tres campos comprimida a propósito (kg/reps/RPE lado a lado),
    // así que forzar los 48dp completos de Material rompería el layout; se
    // sube a ~34dp (padding sm=8), la mayor mejora real que entra sin
    // reventar la tabla, y se completa con el label de [Semantics] para que
    // el tamaño físico no sea la única forma de saber qué hace el botón.
    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            icon,
            size: 18,
            color: onTap == null
                ? AppColors.onSurfaceVariant.withValues(alpha: 0.3)
                : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
