// Q1 -- Tests escritos por el SUPERVISOR (Opus) ANTES de la implementación.
// Contrato de `tools/qa/coverage_gate.dart`. No modificar sin aprobación
// registrada en docs/qa/TEST_CHANGES.md.
import 'package:flutter_test/flutter_test.dart';

import '../../tools/qa/coverage_gate.dart';

String _lcov(String sf, List<int> hits) {
  final buffer = StringBuffer('SF:$sf\n');
  for (var i = 0; i < hits.length; i++) {
    buffer.writeln('DA:${i + 1},${hits[i]}');
  }
  // LF/LH deliberadamente FALSOS: la herramienta debe contar las líneas DA,
  // no confiar en los totales declarados.
  buffer.writeln('LF:999');
  buffer.writeln('LH:999');
  buffer.writeln('end_of_record');
  return buffer.toString();
}

void main() {
  group('parseLcov', () {
    test('cuenta líneas DA encontradas y cubiertas', () {
      final report = parseLcov(_lcov('lib/a.dart', [1, 0, 3, 0]));
      expect(report['lib/a.dart']!.linesFound, 4);
      expect(report['lib/a.dart']!.linesHit, 2);
      expect(report['lib/a.dart']!.percent, 50);
    });

    test('normaliza rutas absolutas de Windows y Linux a lib/...', () {
      final report = parseLcov(
        _lcov(r'C:\Users\x\Proyectos Moviles\nexfit\lib\core\a.dart', [1]) +
            _lcov('/home/runner/work/nexfit/nexfit/lib/core/b.dart', [0]),
      );
      expect(report.keys.toSet(), {'lib/core/a.dart', 'lib/core/b.dart'});
    });

    test('archivo sin líneas ejecutables cuenta como 100 %', () {
      final report = parseLcov('SF:lib/vacio.dart\nend_of_record\n');
      expect(report['lib/vacio.dart']!.percent, 100);
    });

    test('contenido vacío -> reporte vacío, sin lanzar', () {
      expect(parseLcov(''), isEmpty);
    });
  });

  group('parseCoverageExceptions', () {
    test('ignora vacías y comentarios, normaliza barras', () {
      final exceptions = parseCoverageExceptions(
        '# excepciones aprobadas por Opus\n'
        '\n'
        r'lib\core\local\database.dart'
        '\n'
        '  lib/main.dart  \n',
      );
      expect(exceptions, {'lib/core/local/database.dart', 'lib/main.dart'});
    });
  });

  group('evaluateCoverage', () {
    final report = parseLcov(
      _lcov('lib/alto.dart', [1, 1, 1, 1, 0]) + // 80 %
          _lcov('lib/bajo.dart', [1, 0, 0, 0, 0]) + // 20 %
          _lcov('lib/core/local/database.g.dart', [0, 0]),
    );

    test('archivo tocado con >= 80 % pasa (el límite es inclusivo)', () {
      expect(
        evaluateCoverage(report: report, touchedFiles: ['lib/alto.dart']),
        isEmpty,
      );
    });

    test('archivo tocado con < 80 % -> belowMinimum con su porcentaje', () {
      final violations = evaluateCoverage(
        report: report,
        touchedFiles: ['lib/bajo.dart'],
      );
      expect(violations, hasLength(1));
      expect(violations.single.path, 'lib/bajo.dart');
      expect(violations.single.kind, CoverageViolationKind.belowMinimum);
      expect(violations.single.percent, 20);
    });

    test('archivo NO tocado con baja cobertura no bloquea', () {
      expect(
        evaluateCoverage(report: report, touchedFiles: ['lib/alto.dart']),
        isEmpty,
      );
    });

    test(
      'archivo de lib/ tocado que no aparece en el reporte -> missingFromReport',
      () {
        final violations = evaluateCoverage(
          report: report,
          touchedFiles: ['lib/nuevo_sin_tests.dart'],
        );
        expect(
          violations.single.kind,
          CoverageViolationKind.missingFromReport,
        );
        expect(violations.single.percent, 0);
      },
    );

    test('ignora *.g.dart, archivos fuera de lib/ y no-Dart', () {
      expect(
        evaluateCoverage(
          report: report,
          touchedFiles: [
            'lib/core/local/database.g.dart',
            'test/a_test.dart',
            'tools/qa/coverage_gate.dart',
            'pubspec.yaml',
            'lib/assets/data.json',
          ],
        ),
        isEmpty,
      );
    });

    test('rutas tocadas con barra invertida se normalizan', () {
      final violations = evaluateCoverage(
        report: report,
        touchedFiles: [r'lib\bajo.dart'],
      );
      expect(violations.single.path, 'lib/bajo.dart');
    });

    test('excepción aprobada exime al archivo', () {
      expect(
        evaluateCoverage(
          report: report,
          touchedFiles: ['lib/bajo.dart'],
          exceptions: {'lib/bajo.dart'},
        ),
        isEmpty,
      );
    });

    test('minPercent configurable', () {
      expect(
        evaluateCoverage(
          report: report,
          touchedFiles: ['lib/bajo.dart'],
          minPercent: 20,
        ),
        isEmpty,
      );
      expect(
        evaluateCoverage(
          report: report,
          touchedFiles: ['lib/alto.dart'],
          minPercent: 81,
        ),
        hasLength(1),
      );
    });
  });
}
