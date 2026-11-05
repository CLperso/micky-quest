import 'dart:convert';

import 'package:http/http.dart' as http;

import 'model.dart';
import 'store.dart';

class _Conflict implements Exception {}

/// Synchronisation tablette ↔ PC par un dépôt GitHub privé (un seul fichier JSON).
class Sync {
  static bool busy = false;
  static String? lastError;
  static const _file = 'carnet-micky.json';

  static bool configured(Store s) => s.settings.syncRepo.contains('/') && s.settings.syncToken.isNotEmpty;

  static Map<String, String> _headers(Store s) => {
        'Authorization': 'Bearer ${s.settings.syncToken.trim()}',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  static Uri _url(Store s) {
    final repo = s.settings.syncRepo.trim().replaceAll(RegExp(r'^https?://github\.com/'), '').replaceAll(RegExp(r'/$'), '');
    return Uri.parse('https://api.github.com/repos/$repo/contents/$_file');
  }

  static Future<(String?, String?)> _get(Store s) async {
    final r = await http.get(_url(s), headers: _headers(s));
    if (r.statusCode == 404) return (null, null);
    if (r.statusCode != 200) throw 'lecture ${r.statusCode}';
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final sha = j['sha'] as String?;
    final content = (j['content'] as String?) ?? '';
    if (content.isNotEmpty && j['encoding'] == 'base64') return (utf8.decode(base64.decode(content.replaceAll('\n', ''))), sha);
    final raw = await http.get(_url(s), headers: {..._headers(s), 'Accept': 'application/vnd.github.raw+json'});
    if (raw.statusCode != 200) throw 'lecture ${raw.statusCode}';
    return (utf8.decode(raw.bodyBytes), sha);
  }

  static Future<void> _put(Store s, String content, String? sha) async {
    final r = await http.put(
      _url(s),
      headers: {..._headers(s), 'Content-Type': 'application/json'},
      body: jsonEncode({'message': 'Carnet ${DateTime.now().toIso8601String()}', 'content': base64.encode(utf8.encode(content)), if (sha != null) 'sha': sha}),
    );
    if (r.statusCode == 409 || r.statusCode == 422) throw _Conflict();
    if (r.statusCode != 200 && r.statusCode != 201) throw 'écriture ${r.statusCode}';
  }

  static Future<String?> run(Store store) async {
    if (!configured(store) || busy) return null;
    busy = true;
    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final (remote, sha) = await _get(store);
          if (remote != null && remote.isNotEmpty) await store.mergeRemote(jsonDecode(remote) as Map<String, dynamic>);
          final mine = jsonEncode(store.syncPayload());
          if (mine != remote) await _put(store, mine, sha);
          break;
        } on _Conflict {
          if (attempt == 2) rethrow;
        }
      }
      store.settings.lastSync = nowMs();
      await store.save();
      store.refresh();
      lastError = null;
      return null;
    } catch (e) {
      lastError = e is _Conflict ? 'conflit, réessaie' : '$e';
      return lastError;
    } finally {
      busy = false;
    }
  }
}
