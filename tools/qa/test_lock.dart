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
    final decoded = jsonDecode(source);
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
  return path.startsWith('test/') ||
      path.startsWith('integration_test/') ||
      path.startsWith('tools/qa/') ||
      path.startsWith('.github/workflows/');
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

final RegExp _skipKeywordPattern = RegExp(r'\bskip\s*:');
final RegExp _skipAnnotationPattern = RegExp(r'@Skip\s*\(');
final RegExp _skipApprovedPattern = RegExp(r'//\s*SKIP-APPROVED:\s*(\S+)');

enum _CodeState { code, string, comment }

bool _matchesAt(String content, int index, String token) {
  if (index + token.length > content.length) return false;
  for (var k = 0; k < token.length; k++) {
    if (content[index + k] != token[k]) return false;
  }
  return true;
}

/// Marca, para cada posición del contenido, si está en código real, dentro
/// de un string literal (simple, triple, o raw) o de un comentario (`//` o
/// `/* */`). Así el escaneo no confunde texto que aparece DENTRO de un
/// string o comentario (por ejemplo, un fixture de ejemplo en un test que
/// prueba este mismo detector, o el nombre de un test) con uso real de
/// `skip:`/`@Skip` en código.
List<_CodeState> _computeCodeStates(String content) {
  final states = List<_CodeState>.filled(content.length, _CodeState.code);
  var i = 0;
  while (i < content.length) {
    if (_matchesAt(content, i, '//')) {
      final start = i;
      while (i < content.length && content[i] != '\n') {
        i++;
      }
      for (var k = start; k < i; k++) {
        states[k] = _CodeState.comment;
      }
      continue;
    }

    if (_matchesAt(content, i, '/*')) {
      final start = i;
      i += 2;
      while (i < content.length && !_matchesAt(content, i, '*/')) {
        i++;
      }
      i = i + 2 <= content.length ? i + 2 : content.length;
      for (var k = start; k < i; k++) {
        states[k] = _CodeState.comment;
      }
      continue;
    }

    final isRawPrefix = (content[i] == 'r' || content[i] == 'R') &&
        i + 1 < content.length &&
        (content[i + 1] == "'" || content[i + 1] == '"');
    final quoteStart = isRawPrefix ? i + 1 : i;
    final quoteChar = quoteStart < content.length ? content[quoteStart] : '';

    if (quoteChar == "'" || quoteChar == '"') {
      final isTriple = _matchesAt(content, quoteStart, quoteChar * 3);
      final delimiter = isTriple ? quoteChar * 3 : quoteChar;
      final start = i;
      var j = quoteStart + delimiter.length;
      while (j < content.length && !_matchesAt(content, j, delimiter)) {
        if (!isRawPrefix && content[j] == r'\') {
          j += 2;
        } else {
          j++;
        }
      }
      j = j + delimiter.length <= content.length
          ? j + delimiter.length
          : content.length;
      for (var k = start; k < j; k++) {
        states[k] = _CodeState.string;
      }
      i = j;
      continue;
    }

    i++;
  }
  return states;
}

/// Extrae el texto del valor asignado a `skip:` desde justo después de los
/// dos puntos hasta la coma o el paréntesis/corchete/llave de cierre al
/// mismo nivel de anidación (sin contar los que están dentro de strings o
/// comentarios).
String _extractSkipValue(String content, List<_CodeState> states, int start) {
  var depth = 0;
  var i = start;
  while (i < content.length) {
    if (states[i] != _CodeState.code) {
      i++;
      continue;
    }
    final ch = content[i];
    if (ch == '(' || ch == '[' || ch == '{') {
      depth++;
    } else if (ch == ')' || ch == ']' || ch == '}') {
      if (depth == 0) break;
      depth--;
    } else if (ch == ',' && depth == 0) {
      break;
    }
    i++;
  }
  return content.substring(start, i).trim();
}

/// Detecta `skip:` (con cualquier valor distinto del literal `false`) y
/// `@Skip` no aprobados. Una aprobación cubre la misma línea o la línea
/// anterior con `// SKIP-APPROVED: <TASK-ID>` (TASK-ID no vacío).
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

  bool isApproved(int lineIndex) {
    final approvedHere = _skipApprovedPattern.hasMatch(lines[lineIndex]);
    final approvedPrevious =
        lineIndex > 0 && _skipApprovedPattern.hasMatch(lines[lineIndex - 1]);
    return approvedHere || approvedPrevious;
  }

  final violations = <SkipViolation>[];
  final seenLines = <int>{};

  for (final match in _skipKeywordPattern.allMatches(content)) {
    if (states[match.start] != _CodeState.code) continue;
    final value = _extractSkipValue(content, states, match.end);
    if (value == 'false') continue;

    final lineIndex = lineIndexAt(match.start);
    if (!seenLines.add(lineIndex)) continue;
    if (isApproved(lineIndex)) continue;
    violations.add(SkipViolation(path: path, line: lineIndex + 1));
  }

  for (final match in _skipAnnotationPattern.allMatches(content)) {
    if (states[match.start] != _CodeState.code) continue;
    final lineIndex = lineIndexAt(match.start);
    if (!seenLines.add(lineIndex)) continue;
    if (isApproved(lineIndex)) continue;
    violations.add(SkipViolation(path: path, line: lineIndex + 1));
  }

  violations.sort((a, b) => a.line.compareTo(b.line));
  return violations;
}
