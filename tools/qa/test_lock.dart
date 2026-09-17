// Dart puro (sin Flutter): contrato de protección de tests bloqueados.
// Ver docs/AUDITORIA_2026-09-16_SUPERVISOR.md §15.3.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// SHA-256 hex del contenido normalizando CRLF a LF, para que el hash sea
/// el mismo en Windows local y en Linux (CI).
String normalizedSha256(List<int> bytes) {
  final normalized = <int>[];
  for (var i = 0; i < bytes.length; i++) {
    final byte = bytes[i];
    if (byte == 13 && i + 1 < bytes.length && bytes[i + 1] == 10) {
      continue;
    }
    normalized.add(byte);
  }
  return sha256.convert(normalized).toString();
}

final RegExp _hex64 = RegExp(r'^[0-9a-fA-F]{64}$');

class TestLock {
  final Map<String, String> files;

  const TestLock({required this.files});

  factory TestLock.parse(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      rethrow;
    }
    if (decoded is! Map) {
      throw const FormatException('El lock debe ser un objeto JSON');
    }
    final rawFiles = decoded['files'];
    if (rawFiles is! Map) {
      throw const FormatException('El lock debe tener la clave "files"');
    }
    final files = <String, String>{};
    for (final entry in rawFiles.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || value is! String || !_hex64.hasMatch(value)) {
        throw FormatException('Hash invalido para "$key"');
      }
      files[key] = value;
    }
    return TestLock(files: files);
  }
}

class ApprovedChange {
  final String task;
  final String file;
  final String sha256;

  const ApprovedChange({
    required this.task,
    required this.file,
    required this.sha256,
  });
}

final RegExp _approvedChangePattern = RegExp(
  r'^-\s*APPROVED-BY:\s*OPUS\s*\|\s*TASK:\s*(\S+)\s*\|\s*FILE:\s*(\S+)\s*\|\s*SHA256:\s*([0-9a-fA-F]{64}|DELETED)\s*$',
);

/// Lee solo las lineas firmadas por OPUS con el formato completo:
/// `- APPROVED-BY: OPUS | TASK: X | FILE: Y | SHA256: Z`
List<ApprovedChange> parseApprovedChanges(String markdown) {
  final approvals = <ApprovedChange>[];
  for (final line in markdown.split('\n')) {
    final match = _approvedChangePattern.firstMatch(line.trim());
    if (match == null) continue;
    approvals.add(
      ApprovedChange(
        task: match.group(1)!,
        file: match.group(2)!,
        sha256: match.group(3)!,
      ),
    );
  }
  return approvals;
}

enum LockViolationKind { modified, deleted, invalidPath }

class LockViolation {
  final String path;
  final LockViolationKind kind;

  const LockViolation({required this.path, required this.kind});
}

bool _isValidLockedPath(String path) {
  if (path.isEmpty) return false;
  if (path.contains('\\') || path.contains(':')) return false;
  if (path.startsWith('/')) return false;
  if (path.split('/').contains('..')) return false;
  return path.startsWith('test/') || path.startsWith('integration_test/');
}

/// Compara cada archivo del lock contra el disco y reporta TODAS las
/// violaciones (no se detiene en la primera).
List<LockViolation> verifyTestLock({
  required Directory root,
  required TestLock lock,
  required List<ApprovedChange> approvals,
}) {
  final violations = <LockViolation>[];
  for (final entry in lock.files.entries) {
    final path = entry.key;
    final expectedHash = entry.value;

    if (!_isValidLockedPath(path)) {
      violations.add(
        LockViolation(path: path, kind: LockViolationKind.invalidPath),
      );
      continue;
    }

    final file = File('${root.path}/$path');
    if (!file.existsSync()) {
      final deletionApproved = approvals.any(
        (a) => a.file == path && a.sha256 == 'DELETED',
      );
      if (!deletionApproved) {
        violations.add(
          LockViolation(path: path, kind: LockViolationKind.deleted),
        );
      }
      continue;
    }

    final actualHash = normalizedSha256(file.readAsBytesSync());
    if (actualHash == expectedHash) continue;

    final modificationApproved = approvals.any(
      (a) => a.file == path && a.sha256 == actualHash,
    );
    if (!modificationApproved) {
      violations.add(
        LockViolation(path: path, kind: LockViolationKind.modified),
      );
    }
  }
  return violations;
}

class SkipViolation {
  final String path;
  final int line;

  const SkipViolation({required this.path, required this.line});
}

final RegExp _skipValuePattern = RegExp(
  r'''skip\s*:\s*(true|'[^']*'|"[^"]*")''',
);
final RegExp _skipAnnotationPattern = RegExp(r'@Skip\s*\(');
final RegExp _skipApprovedPattern = RegExp(r'//\s*SKIP-APPROVED:\s*(\S+)');

enum _CodeState { code, string, comment }

/// Marca, para cada posición del contenido, si está en código real, dentro
/// de un string literal o dentro de un comentario `//`. Así el escaneo no
/// confunde texto que aparece DENTRO de un string (por ejemplo, un fixture
/// de ejemplo en un test que prueba este mismo detector) con uso real de
/// `skip:`/`@Skip` en código.
List<_CodeState> _computeCodeStates(String content) {
  final states = List<_CodeState>.filled(content.length, _CodeState.code);
  var state = _CodeState.code;
  var stringQuote = '';
  var i = 0;
  while (i < content.length) {
    final ch = content[i];
    states[i] = state;
    switch (state) {
      case _CodeState.code:
        if (ch == '/' && i + 1 < content.length && content[i + 1] == '/') {
          state = _CodeState.comment;
        } else if (ch == "'" || ch == '"') {
          state = _CodeState.string;
          stringQuote = ch;
        }
        break;
      case _CodeState.string:
        if (ch == r'\') {
          i++;
          if (i < content.length) states[i] = _CodeState.string;
        } else if (ch == stringQuote) {
          state = _CodeState.code;
        }
        break;
      case _CodeState.comment:
        if (ch == '\n') state = _CodeState.code;
        break;
    }
    i++;
  }
  return states;
}

/// Detecta `skip:` (con valor distinto de `false`) y `@Skip` no aprobados.
/// Una aprobación cubre la misma línea o la línea anterior con
/// `// SKIP-APPROVED: <TASK-ID>` (TASK-ID no vacío).
List<SkipViolation> findUnapprovedSkips({
  required String path,
  required String content,
}) {
  final states = _computeCodeStates(content);
  final lines = content.split('\n');
  final lineStarts = <int>[0];
  for (var i = 0; i < content.length; i++) {
    if (content[i] == '\n') lineStarts.add(i + 1);
  }

  int lineIndexAt(int offset) {
    var lo = 0, hi = lineStarts.length - 1, result = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (lineStarts[mid] <= offset) {
        result = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return result;
  }

  final violations = <SkipViolation>[];
  final seenLines = <int>{};

  void collect(RegExp pattern) {
    for (final match in pattern.allMatches(content)) {
      if (states[match.start] != _CodeState.code) continue;
      final lineIndex = lineIndexAt(match.start);
      if (!seenLines.add(lineIndex)) continue;

      final approvedHere = _skipApprovedPattern.hasMatch(lines[lineIndex]);
      final approvedPrevious =
          lineIndex > 0 && _skipApprovedPattern.hasMatch(lines[lineIndex - 1]);
      if (approvedHere || approvedPrevious) continue;

      violations.add(SkipViolation(path: path, line: lineIndex + 1));
    }
  }

  collect(_skipValuePattern);
  collect(_skipAnnotationPattern);
  violations.sort((a, b) => a.line.compareTo(b.line));
  return violations;
}
