/// Resultado de una fila individual al intentar persistirla.
class ImportOutcome {
  final int rowIndex;
  final bool imported;
  final String? reason;

  const ImportOutcome({
    required this.rowIndex,
    required this.imported,
    this.reason,
  });
}

/// Resultado agregado de correr el [ImportEngine] sobre un lote de
/// registros validados.
class ImportResult {
  final int sessionsCreated;
  final int setsCreated;
  final List<ImportOutcome> outcomes;

  const ImportResult({
    required this.sessionsCreated,
    required this.setsCreated,
    required this.outcomes,
  });

  int get skipped => outcomes.where((o) => !o.imported).length;
}
