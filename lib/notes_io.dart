import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// Les traits de chaque page manuscrite, dans un fichier par page.
class NotesIO {
  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/carnet');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  static Future<File> _file(String id) async => File('${(await _dir()).path}/$id.json');

  static Future<List<Stroke>> load(String id) async {
    try {
      final f = await _file(id);
      if (!f.existsSync()) return [];
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return ((j['strokes'] as List?) ?? []).map((e) => Stroke.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<String?> raw(String id) async {
    final f = await _file(id);
    return f.existsSync() ? f.readAsString() : null;
  }

  static Future<void> save(String id, List<Stroke> strokes) async {
    final f = await _file(id);
    await f.writeAsString(jsonEncode({'strokes': strokes.map((s) => s.toJson()).toList()}));
  }

  static Future<void> saveRaw(String id, String content) async {
    final f = await _file(id);
    await f.writeAsString(content);
  }
}
