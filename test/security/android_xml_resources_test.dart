// T-DBG -- Test escrito por el SUPERVISOR (Opus) ANTES de la corrección.
// Hallazgo nuevo (auditoría de TASK-004): android/app/src/debug/res/xml/
// network_security_config.xml tiene "--" dentro de un comentario XML. XML lo
// prohíbe y AAPT aborta: `flutter build apk --debug` falla desde el commit
// 5aa42fd (2026-09-07). El release no lo detecta porque no usa recursos de debug.
// No modificar sin aprobación registrada en docs/qa/TEST_CHANGES.md.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Problemas de comentarios XML que AAPT rechaza: "--" dentro del comentario,
/// comentario que termina en "--->" y comentario sin cerrar.
List<String> xmlCommentProblems(String content) {
  final problems = <String>[];
  var index = 0;
  while (true) {
    final start = content.indexOf('<!--', index);
    if (start == -1) break;
    final bodyStart = start + 4;
    final end = content.indexOf('-->', bodyStart);
    if (end == -1) {
      problems.add('comentario sin cerrar en el offset $start');
      break;
    }
    final body = content.substring(bodyStart, end);
    if (body.contains('--') || body.endsWith('-')) {
      final line = '\n'.allMatches(content.substring(0, start)).length + 1;
      problems.add('"--" dentro de un comentario (línea $line)');
    }
    index = end + 3;
  }
  return problems;
}

void main() {
  group('detector de comentarios inválidos', () {
    test('comentario válido', () {
      expect(xmlCommentProblems('<a><!-- ok - bien --></a>'), isEmpty);
    });

    test('"--" dentro del comentario', () {
      expect(
        xmlCommentProblems('<a>\n<!-- desarrollo -- localhost --></a>'),
        ['"--" dentro de un comentario (línea 2)'],
      );
    });

    test('comentario que termina con "--->"', () {
      expect(xmlCommentProblems('<!-- x --->'), hasLength(1));
    });

    test('comentario sin cerrar', () {
      expect(xmlCommentProblems('<a><!-- x </a>'), hasLength(1));
    });
  });

  test('ningún XML de android/app/src tiene comentarios inválidos', () {
    final files = Directory('android/app/src')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.xml'))
        .toList();
    expect(files, isNotEmpty);

    final problems = <String>[
      for (final file in files)
        for (final p in xmlCommentProblems(file.readAsStringSync()))
          '${file.path.replaceAll('\\', '/')}: $p',
    ];

    expect(problems, isEmpty);
  });
}
