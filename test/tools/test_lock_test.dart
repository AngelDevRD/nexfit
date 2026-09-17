// Q1 -- Tests escritos por el SUPERVISOR (Opus) ANTES de la implementación.
// Contrato de `tools/qa/test_lock.dart`. No modificar sin aprobación
// registrada en docs/qa/TEST_CHANGES.md (ver docs/AUDITORIA_2026-09-16_SUPERVISOR.md §15.3).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/qa/test_lock.dart';

// Vectores SHA-256 conocidos (independientes de cualquier implementación).
const _shaAbc =
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
const _shaHelloLf =
    '5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('test_lock_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  void writeFile(String relative, String content) {
    final file = File('${root.path}/$relative');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  TestLock lockOf(Map<String, String> files) => TestLock(files: files);

  group('normalizedSha256', () {
    test('coincide con el vector conocido de "abc"', () {
      expect(normalizedSha256('abc'.codeUnits), _shaAbc);
    });

    test('CRLF y LF producen el mismo hash (Windows local vs Linux en CI)', () {
      expect(normalizedSha256('hello\n'.codeUnits), _shaHelloLf);
      expect(normalizedSha256('hello\r\n'.codeUnits), _shaHelloLf);
    });

    test('un cambio de un solo byte cambia el hash', () {
      expect(normalizedSha256('abd'.codeUnits), isNot(_shaAbc));
    });
  });

  group('TestLock.parse', () {
    test('lee version y mapa de archivos', () {
      final lock = TestLock.parse(
        '{"version":1,"files":{"test/a_test.dart":"$_shaAbc"}}',
      );
      expect(lock.files, {'test/a_test.dart': _shaAbc});
    });

    test('JSON inválido lanza FormatException', () {
      expect(() => TestLock.parse('{no es json'), throwsFormatException);
    });

    test('sin clave "files" lanza FormatException', () {
      expect(() => TestLock.parse('{"version":1}'), throwsFormatException);
    });

    test('hash que no es hex de 64 caracteres lanza FormatException', () {
      expect(
        () => TestLock.parse('{"version":1,"files":{"test/a_test.dart":"xyz"}}'),
        throwsFormatException,
      );
    });
  });

  group('parseApprovedChanges', () {
    test('lee solo líneas firmadas por OPUS con formato completo', () {
      final approvals = parseApprovedChanges('''
# Cambios de tests aprobados
- APPROVED-BY: OPUS | TASK: Q1 | FILE: test/a_test.dart | SHA256: $_shaAbc
- APPROVED-BY: SONNET | TASK: Q1 | FILE: test/b_test.dart | SHA256: $_shaAbc
- APPROVED-BY: OPUS | TASK: Q1 | FILE: test/c_test.dart
texto libre que no es una aprobación
''');
      expect(approvals, hasLength(1));
      expect(approvals.single.file, 'test/a_test.dart');
      expect(approvals.single.sha256, _shaAbc);
      expect(approvals.single.task, 'Q1');
    });
  });

  group('verifyTestLock', () {
    test('archivos intactos -> sin violaciones', () {
      writeFile('test/a_test.dart', 'abc');
      final violations = verifyTestLock(
        root: root,
        lock: lockOf({'test/a_test.dart': _shaAbc}),
        approvals: const [],
      );
      expect(violations, isEmpty);
    });

    test('intacto aunque en disco tenga CRLF y el lock se generó con LF', () {
      writeFile('test/a_test.dart', 'hello\r\n');
      final violations = verifyTestLock(
        root: root,
        lock: lockOf({'test/a_test.dart': _shaHelloLf}),
        approvals: const [],
      );
      expect(violations, isEmpty);
    });

    test('un byte alterado sin aprobación -> modified', () {
      writeFile('test/a_test.dart', 'abd');
      final violations = verifyTestLock(
        root: root,
        lock: lockOf({'test/a_test.dart': _shaAbc}),
        approvals: const [],
      );
      expect(violations, hasLength(1));
      expect(violations.single.path, 'test/a_test.dart');
      expect(violations.single.kind, LockViolationKind.modified);
    });

    test('cambio aprobado con el hash EXACTO del contenido nuevo -> OK', () {
      writeFile('test/a_test.dart', 'hello\n');
      final violations = verifyTestLock(
        root: root,
        lock: lockOf({'test/a_test.dart': _shaAbc}),
        approvals: [
          const ApprovedChange(
            task: 'Q1',
            file: 'test/a_test.dart',
            sha256: _shaHelloLf,
          ),
        ],
      );
      expect(violations, isEmpty);
    });

    test(
      'una aprobación no sirve para un cambio posterior distinto (liga al hash)',
      () {
        writeFile('test/a_test.dart', 'otro contenido');
        final violations = verifyTestLock(
          root: root,
          lock: lockOf({'test/a_test.dart': _shaAbc}),
          approvals: [
            const ApprovedChange(
              task: 'Q1',
              file: 'test/a_test.dart',
              sha256: _shaHelloLf,
            ),
          ],
        );
        expect(violations.single.kind, LockViolationKind.modified);
      },
    );

    test('aprobación para OTRO archivo no cubre este', () {
      writeFile('test/a_test.dart', 'hello\n');
      final violations = verifyTestLock(
        root: root,
        lock: lockOf({'test/a_test.dart': _shaAbc}),
        approvals: [
          const ApprovedChange(
            task: 'Q1',
            file: 'test/b_test.dart',
            sha256: _shaHelloLf,
          ),
        ],
      );
      expect(violations.single.kind, LockViolationKind.modified);
    });

    test('archivo bloqueado borrado -> deleted', () {
      final violations = verifyTestLock(
        root: root,
        lock: lockOf({'test/a_test.dart': _shaAbc}),
        approvals: const [],
      );
      expect(violations.single.kind, LockViolationKind.deleted);
    });

    test('borrado aprobado solo con SHA256: DELETED', () {
      final violations = verifyTestLock(
        root: root,
        lock: lockOf({'test/a_test.dart': _shaAbc}),
        approvals: [
          const ApprovedChange(
            task: 'Q1',
            file: 'test/a_test.dart',
            sha256: 'DELETED',
          ),
        ],
      );
      expect(violations, isEmpty);
    });

    test('archivo nuevo no registrado en el lock NO es violación', () {
      writeFile('test/a_test.dart', 'abc');
      writeFile('test/extra_test.dart', 'cualquier cosa');
      final violations = verifyTestLock(
        root: root,
        lock: lockOf({'test/a_test.dart': _shaAbc}),
        approvals: const [],
      );
      expect(violations, isEmpty);
    });

    test(
      'rutas fuera de test/ o integration_test/, absolutas o con .. -> invalidPath',
      () {
        writeFile('lib/x.dart', 'abc');
        final violations = verifyTestLock(
          root: root,
          lock: lockOf({
            'lib/x.dart': _shaAbc,
            'test/../lib/x.dart': _shaAbc,
            '/etc/passwd': _shaAbc,
            r'C:\Windows\x.dart': _shaAbc,
          }),
          approvals: const [],
        );
        expect(violations, hasLength(4));
        expect(
          violations.map((v) => v.kind).toSet(),
          {LockViolationKind.invalidPath},
        );
      },
    );

    test('integration_test/ es una ruta válida', () {
      writeFile('integration_test/flow_test.dart', 'abc');
      final violations = verifyTestLock(
        root: root,
        lock: lockOf({'integration_test/flow_test.dart': _shaAbc}),
        approvals: const [],
      );
      expect(violations, isEmpty);
    });

    test('varias violaciones se reportan todas, no solo la primera', () {
      writeFile('test/a_test.dart', 'abd');
      final violations = verifyTestLock(
        root: root,
        lock: lockOf({
          'test/a_test.dart': _shaAbc,
          'test/b_test.dart': _shaAbc,
        }),
        approvals: const [],
      );
      expect(violations.map((v) => v.path).toSet(), {
        'test/a_test.dart',
        'test/b_test.dart',
      });
    });
  });

  group('findUnapprovedSkips', () {
    test('skip: true sin aprobación -> violación con número de línea', () {
      final violations = findUnapprovedSkips(
        path: 'test/a_test.dart',
        content: "test('x', () {},\n  skip: true,\n);\n",
      );
      expect(violations, hasLength(1));
      expect(violations.single.line, 2);
      expect(violations.single.path, 'test/a_test.dart');
    });

    test('skip con motivo en string también cuenta', () {
      final violations = findUnapprovedSkips(
        path: 'test/a_test.dart',
        content: "test('x', () {}, skip: 'cuelga en CI');\n",
      );
      expect(violations, hasLength(1));
    });

    test('@Skip a nivel de archivo cuenta', () {
      final violations = findUnapprovedSkips(
        path: 'test/a_test.dart',
        content: "@Skip('pendiente')\nlibrary;\n",
      );
      expect(violations, hasLength(1));
    });

    test('skip: false no es violación', () {
      final violations = findUnapprovedSkips(
        path: 'test/a_test.dart',
        content: "test('x', () {}, skip: false);\n",
      );
      expect(violations, isEmpty);
    });

    test('aprobado en la misma línea o en la anterior -> OK', () {
      final violations = findUnapprovedSkips(
        path: 'test/a_test.dart',
        content:
            "test('x', () {},\n"
            "  // SKIP-APPROVED: Q4\n"
            "  skip: true,\n"
            ");\n"
            "test('y', () {}, skip: true); // SKIP-APPROVED: T-H3\n",
      );
      expect(violations, isEmpty);
    });

    test('marca sin TASK-ID no aprueba', () {
      final violations = findUnapprovedSkips(
        path: 'test/a_test.dart',
        content: "test('x', () {}, skip: true); // SKIP-APPROVED:\n",
      );
      expect(violations, hasLength(1));
    });

    test('la palabra skip en un comentario o nombre de test no cuenta', () {
      final violations = findUnapprovedSkips(
        path: 'test/a_test.dart',
        content:
            "// no hacer skip de este test\n"
            "test('skip del descanso funciona', () {});\n",
      );
      expect(violations, isEmpty);
    });
  });
}
