// Q1 revisión 1 -- Tests escritos por el SUPERVISOR (Opus) tras auditar la
// primera implementación: cada caso es una forma real de evadir el control.
// No modificar sin aprobación registrada en docs/qa/TEST_CHANGES.md.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/qa/test_lock.dart';

const _shaAbc =
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

void main() {
  group('findUnapprovedSkips — evasiones', () {
    test('skip con una variable cuenta', () {
      final violations = findUnapprovedSkips(
        path: 'test/a_test.dart',
        content: "const s = true;\ntest('x', () {}, skip: s);\n",
      );
      expect(violations.map((v) => v.line), [2]);
    });

    test('skip con una expresión cuenta', () {
      final violations = findUnapprovedSkips(
        path: 'test/a_test.dart',
        content: "test('x', () {}, skip: !isCi);\n",
      );
      expect(violations.map((v) => v.line), [1]);
    });

    test('skip: false seguido de coma o paréntesis sigue sin contar', () {
      final violations = findUnapprovedSkips(
        path: 'test/a_test.dart',
        content: "test('x', () {}, skip: false);\ntest('y', () {},\n  skip: false,\n);\n",
      );
      expect(violations, isEmpty);
    });

    test('un string triple con apóstrofe no oculta un skip posterior', () {
      final violations = findUnapprovedSkips(
        path: 'test/a_test.dart',
        content:
            "const nota = '''it's fine''';\n"
            "test('x', () {}, skip: true);\n",
      );
      expect(violations.map((v) => v.line), [2]);
    });

    test('un string triple con comillas dobles y apóstrofe tampoco', () {
      final violations = findUnapprovedSkips(
        path: 'test/a_test.dart',
        content:
            'const nota = """it\'s "fine" """;\n'
            "test('x', () {}, skip: true);\n",
      );
      expect(violations.map((v) => v.line), [2]);
    });

    test('un string raw con barra invertida final no oculta un skip', () {
      final violations = findUnapprovedSkips(
        path: 'test/a_test.dart',
        content:
            r"const ruta = r'C:\dir\';"
            "\n"
            "test('x', () {}, skip: true);\n",
      );
      expect(violations.map((v) => v.line), [2]);
    });

    test('skip: dentro del NOMBRE de un test no cuenta', () {
      final violations = findUnapprovedSkips(
        path: 'test/a_test.dart',
        content: "test('skip: true en el nombre', () {});\n",
      );
      expect(violations, isEmpty);
    });

    test('skip dentro de un comentario de bloque no cuenta', () {
      final violations = findUnapprovedSkips(
        path: 'test/a_test.dart',
        content: "/* ejemplo: skip: true */\ntest('x', () {});\n",
      );
      expect(violations, isEmpty);
    });
  });

  group('verifyTestLock — protege también las herramientas de calidad', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('test_lock_hard_');
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    void writeFile(String relative, String content) {
      final file = File('${root.path}/$relative');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
    }

    test('tools/qa/ y .github/workflows/ son rutas bloqueables válidas', () {
      writeFile('tools/qa/test_lock.dart', 'abc');
      writeFile('.github/workflows/ci.yml', 'abc');
      final violations = verifyTestLock(
        root: root,
        lock: const TestLock(
          files: {
            'tools/qa/test_lock.dart': _shaAbc,
            '.github/workflows/ci.yml': _shaAbc,
          },
        ),
        approvals: const [],
      );
      expect(violations, isEmpty);
    });

    test('modificar el verificador bloqueado sin aprobación -> modified', () {
      writeFile('tools/qa/test_lock.dart', 'return true; // siempre pasa');
      final violations = verifyTestLock(
        root: root,
        lock: const TestLock(files: {'tools/qa/test_lock.dart': _shaAbc}),
        approvals: const [],
      );
      expect(violations.single.kind, LockViolationKind.modified);
    });

    test('otras rutas de .github/ o tools/ siguen siendo inválidas', () {
      final violations = verifyTestLock(
        root: root,
        lock: const TestLock(
          files: {
            'tools/verify-release-version.mjs': _shaAbc,
            '.github/CODEOWNERS': _shaAbc,
            'tools/qa/../../lib/main.dart': _shaAbc,
          },
        ),
        approvals: const [],
      );
      expect(
        violations.map((v) => v.kind).toSet(),
        {LockViolationKind.invalidPath},
      );
      expect(violations, hasLength(3));
    });
  });
}
