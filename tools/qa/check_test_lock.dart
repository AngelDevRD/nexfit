// CLI: verifica test/.test-lock.json y escanea skips no aprobados en
// test/ e integration_test/. Exit 1 si hay alguna violación.
import 'dart:io';

import 'test_lock.dart';

const _lockPath = 'test/.test-lock.json';
const _changesPath = 'docs/qa/TEST_CHANGES.md';

void main() {
  final root = Directory.current;
  var hasViolations = false;

  final lockFile = File(_lockPath);
  if (!lockFile.existsSync()) {
    stderr.writeln('ERROR: no existe $_lockPath');
    exit(1);
  }

  final TestLock lock;
  try {
    lock = TestLock.parse(lockFile.readAsStringSync());
  } on FormatException catch (e) {
    stderr.writeln('ERROR: $_lockPath invalido: ${e.message}');
    exit(1);
  }

  final changesFile = File(_changesPath);
  final approvals = changesFile.existsSync()
      ? parseApprovedChanges(changesFile.readAsStringSync())
      : const <ApprovedChange>[];

  final lockViolations = verifyTestLock(
    root: root,
    lock: lock,
    approvals: approvals,
  );
  for (final violation in lockViolations) {
    hasViolations = true;
    stderr.writeln(
      'LOCK VIOLATION [${violation.kind.name}]: ${violation.path}',
    );
  }

  for (final testDir in [
    Directory('${root.path}/test'),
    Directory('${root.path}/integration_test'),
  ]) {
    if (!testDir.existsSync()) continue;
    for (final entity in testDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('_test.dart')) continue;
      final relativePath = entity.path
          .substring(root.path.length + 1)
          .replaceAll('\\', '/');
      final skipViolations = findUnapprovedSkips(
        path: relativePath,
        content: entity.readAsStringSync(),
      );
      for (final violation in skipViolations) {
        hasViolations = true;
        stderr.writeln(
          'SKIP VIOLATION: ${violation.path}:${violation.line}',
        );
      }
    }
  }

  if (hasViolations) {
    exit(1);
  }
  stdout.writeln('OK: test-lock integro, sin skips no aprobados.');
}
