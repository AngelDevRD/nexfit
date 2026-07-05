import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/api_client.dart';

/// Exporta/importa todos los datos del usuario (rutinas, entrenamientos,
/// nutrición, check-ins, metas) como un archivo .json de respaldo.
class DataTransferService {
  final ApiClient client;

  DataTransferService(this.client);

  /// Pide el export completo al backend, lo escribe a un archivo temporal y
  /// abre la hoja de compartir nativa para que el usuario lo guarde donde
  /// quiera (Drive, Archivos, WhatsApp, etc.).
  Future<void> exportAll() async {
    final data = await client.get('/api/v1/users/me/export');
    final dir = await getTemporaryDirectory();
    final date = DateTime.now().toIso8601String().split('T').first;
    final file = File('${dir.path}/appgym_backup_$date.json');
    await file.writeAsString(jsonEncode(data));
    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Backup de datos de AppGym');
  }

  /// Abre el selector de archivos, lee el .json elegido y lo manda al
  /// endpoint de import. Devuelve el resumen de cuántos registros se
  /// crearon/omitieron.
  Future<Map<String, dynamic>?> importAll() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return null;

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    final payload = jsonDecode(content) as Map<String, dynamic>;

    final summary = await client.post('/api/v1/users/me/import', body: payload);
    return summary as Map<String, dynamic>;
  }
}
