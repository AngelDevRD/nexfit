// T-S2 -- Tests escritos por el SUPERVISOR (Opus) ANTES de la implementación.
// Hallazgo S2 de docs/AUDITORIA_2026-09-16_SUPERVISOR.md: sin configuración,
// Android respalda por defecto la base SQLite (datos de salud) y
// SharedPreferences (incluye la sesión persistida de Supabase) en la nube de
// Google y en la transferencia entre dispositivos.
// No modificar sin aprobación registrada en docs/qa/TEST_CHANGES.md.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _manifestPath = 'android/app/src/main/AndroidManifest.xml';
const _rulesPath = 'android/app/src/main/res/xml/data_extraction_rules.xml';

/// Atributos de la etiqueta `<application ...>` del manifest principal.
Map<String, String> _applicationAttributes(String manifest) {
  final tag = RegExp(r'<application\b([^>]*)>', dotAll: true).firstMatch(manifest);
  expect(tag, isNotNull, reason: 'el manifest debe tener <application>');
  return {
    for (final m in RegExp(r'([\w:]+)\s*=\s*"([^"]*)"').allMatches(tag!.group(1)!))
      m.group(1)!: m.group(2)!,
  };
}

/// Contenido de la sección `<name> ... </name>` de las reglas, sin comentarios.
String _section(String rules, String name) {
  final withoutComments = rules.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  final match = RegExp('<$name\\b[^>]*>(.*?)</$name>', dotAll: true)
      .firstMatch(withoutComments);
  expect(match, isNotNull, reason: 'data_extraction_rules.xml debe tener <$name>');
  return match!.group(1)!;
}

bool _excludesDomain(String section, String domain) => RegExp(
  '<exclude\\b[^>]*\\bdomain\\s*=\\s*"$domain"',
).hasMatch(section);

void main() {
  late String manifest;

  setUpAll(() {
    manifest = File(_manifestPath).readAsStringSync();
  });

  test('allowBackup está desactivado explícitamente (Android <= 11)', () {
    expect(_applicationAttributes(manifest)['android:allowBackup'], 'false');
  });

  test('declara reglas de extracción de datos (Android 12+)', () {
    expect(
      _applicationAttributes(manifest)['android:dataExtractionRules'],
      '@xml/data_extraction_rules',
    );
    expect(File(_rulesPath).existsSync(), isTrue);
  });

  for (final section in ['cloud-backup', 'device-transfer']) {
    test('$section excluye la base de datos y las preferencias', () {
      final body = _section(File(_rulesPath).readAsStringSync(), section);
      final excludesAll = _excludesDomain(body, 'root');
      expect(
        excludesAll ||
            (_excludesDomain(body, 'database') &&
                _excludesDomain(body, 'sharedpref')),
        isTrue,
        reason: '$section debe excluir database y sharedpref (o root)',
      );
    });
  }

  test('una exclusión dentro de un comentario XML no cuenta', () {
    const rules = '''
<data-extraction-rules>
  <cloud-backup>
    <!-- <exclude domain="database" path="."/> -->
    <exclude domain="sharedpref" path="."/>
  </cloud-backup>
</data-extraction-rules>''';
    final body = _section(rules, 'cloud-backup');
    expect(_excludesDomain(body, 'database'), isFalse);
    expect(_excludesDomain(body, 'sharedpref'), isTrue);
  });
}
