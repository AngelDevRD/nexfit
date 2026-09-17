// Dart puro (sin Flutter): gate de cobertura sobre lcov.info.
// Ver docs/AUDITORIA_2026-09-16_SUPERVISOR.md §15.3 y §16.

class FileCoverage {
  final int linesFound;
  final int linesHit;

  const FileCoverage({required this.linesFound, required this.linesHit});

  double get percent => linesFound == 0 ? 100 : (linesHit / linesFound) * 100;
}

String _normalizeSourcePath(String raw) {
  final normalized = raw.replaceAll('\\', '/');
  if (normalized.startsWith('lib/')) return normalized;
  final idx = normalized.indexOf('/lib/');
  if (idx != -1) return normalized.substring(idx + 1);
  return normalized;
}

/// Cuenta las líneas `DA:` encontradas y cubiertas por archivo (`SF:`...
/// `end_of_record`). Ignora deliberadamente los totales `LF`/`LH` del
/// reporte: no son confiables.
Map<String, FileCoverage> parseLcov(String content) {
  final result = <String, FileCoverage>{};
  String? currentPath;
  var found = 0;
  var hit = 0;

  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.startsWith('SF:')) {
      currentPath = _normalizeSourcePath(line.substring(3).trim());
      found = 0;
      hit = 0;
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length >= 2) {
        found++;
        if (int.tryParse(parts[1].trim()) != 0) hit++;
      }
    } else if (line == 'end_of_record') {
      if (currentPath != null) {
        result[currentPath] = FileCoverage(linesFound: found, linesHit: hit);
      }
      currentPath = null;
    }
  }
  return result;
}

/// Lee excepciones aprobadas (una ruta por línea), ignorando vacías y
/// comentarios `#`, y normalizando barras invertidas.
Set<String> parseCoverageExceptions(String content) {
  final result = <String>{};
  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    result.add(line.replaceAll('\\', '/'));
  }
  return result;
}

enum CoverageViolationKind { belowMinimum, missingFromReport }

class CoverageViolation {
  final String path;
  final CoverageViolationKind kind;
  final double percent;

  const CoverageViolation({
    required this.path,
    required this.kind,
    required this.percent,
  });
}

bool _isCoverageTracked(String path) {
  return path.startsWith('lib/') &&
      path.endsWith('.dart') &&
      !path.endsWith('.g.dart');
}

/// Evalúa solo los archivos `lib/**.dart` (excepto `*.g.dart`) tocados por
/// la tarea. El límite mínimo es inclusivo.
List<CoverageViolation> evaluateCoverage({
  required Map<String, FileCoverage> report,
  required Iterable<String> touchedFiles,
  double minPercent = 80,
  Set<String> exceptions = const {},
}) {
  final violations = <CoverageViolation>[];
  for (final rawPath in touchedFiles) {
    final path = rawPath.replaceAll('\\', '/');
    if (!_isCoverageTracked(path)) continue;
    if (exceptions.contains(path)) continue;

    final coverage = report[path];
    if (coverage == null) {
      violations.add(
        CoverageViolation(
          path: path,
          kind: CoverageViolationKind.missingFromReport,
          percent: 0,
        ),
      );
      continue;
    }
    if (coverage.percent < minPercent) {
      violations.add(
        CoverageViolation(
          path: path,
          kind: CoverageViolationKind.belowMinimum,
          percent: coverage.percent,
        ),
      );
    }
  }
  return violations;
}
