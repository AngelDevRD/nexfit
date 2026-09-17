// CLI: evalua cobertura de los archivos tocados desde --base hasta HEAD
// contra un reporte lcov. Exit 1 si hay violaciones.
import 'dart:io';

import 'coverage_gate.dart';

const _exceptionsPath = 'tools/qa/coverage_exceptions.txt';

void main(List<String> args) {
  String? lcovPath;
  String? base;
  var minPercent = 80.0;

  String? nextArg(int i, String flag) {
    if (i + 1 >= args.length) {
      stderr.writeln('ERROR: falta el valor de "$flag"');
      exit(2);
    }
    return args[i + 1];
  }

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--lcov':
        lcovPath = nextArg(i, '--lcov');
        i++;
        break;
      case '--base':
        base = nextArg(i, '--base');
        i++;
        break;
      case '--min':
        final raw = nextArg(i, '--min')!;
        final parsed = double.tryParse(raw);
        if (parsed == null) {
          stderr.writeln('ERROR: "--min" no es numerico: "$raw"');
          exit(2);
        }
        minPercent = parsed;
        i++;
        break;
      default:
        stderr.writeln('ERROR: argumento desconocido "${args[i]}"');
        exit(2);
    }
  }

  if (lcovPath == null || base == null) {
    stderr.writeln(
      'Uso: check_coverage.dart --lcov <ruta lcov.info> --base <git-ref> [--min <porcentaje>]',
    );
    exit(2);
  }

  final lcovFile = File(lcovPath);
  if (!lcovFile.existsSync()) {
    stderr.writeln('ERROR: no existe el reporte lcov "$lcovPath"');
    exit(1);
  }

  if (base.replaceAll('0', '').isEmpty) {
    base = 'HEAD~1';
  }

  final diffResult = Process.runSync('git', [
    'diff',
    '--name-only',
    '$base...HEAD',
  ]);
  if (diffResult.exitCode != 0) {
    stderr.writeln('ERROR: git diff fallo: ${diffResult.stderr}');
    exit(1);
  }
  final touchedFiles = (diffResult.stdout as String)
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty);

  final exceptionsFile = File(_exceptionsPath);
  final exceptions = exceptionsFile.existsSync()
      ? parseCoverageExceptions(exceptionsFile.readAsStringSync())
      : const <String>{};

  final report = parseLcov(lcovFile.readAsStringSync());
  final violations = evaluateCoverage(
    report: report,
    touchedFiles: touchedFiles,
    minPercent: minPercent,
    exceptions: exceptions,
  );

  if (violations.isEmpty) {
    stdout.writeln('OK: cobertura de archivos tocados >= $minPercent %.');
    return;
  }

  for (final violation in violations) {
    stderr.writeln(
      'COVERAGE VIOLATION [${violation.kind.name}]: ${violation.path} '
      '(${violation.percent.toStringAsFixed(1)} %)',
    );
  }
  exit(1);
}
