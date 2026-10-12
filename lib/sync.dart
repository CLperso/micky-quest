import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'notes_io.dart';
import 'store.dart';

/// Synchronisation entre appareils via un dépôt GitHub privé.
class Sync {
  static bool busy = false;
  static String? lastError;
  static const _file = 'micky-quest.json';
  static const _pagesUp = 'notes_uploaded_v1';
  static const _pagesDown = 'notes_downloaded_v1';

  static bool configured(AppStore s) => s.settings.syncRepo.contains('/') && s.settings.syncToken.isNotEmpty;

  static Map<String, String> _headers(AppStore s, {bool raw = false}) => {
        'Authorization': 'Bearer ${s.settings.syncToken.trim()}',
        'Accept': raw ? 'application/vnd.github.raw+json' : 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  static Uri _url(AppStore s, String path) {
    final repo = s.settings.syncRepo.trim().replaceAll(RegExp(r'^https?://github\.com/'), '').replaceAll(RegExp(r'/$'), '');
    return Uri.parse('https://api.github.com/repos/$repo/contents/$path');
  }

  /// Lit un fichier du dépôt : (contenu, sha), ou (null, null) s'il n'existe pas.
  static Future<(String?, String?)> _get(AppStore s, String path) async {
    final r = await http.get(_url(s, path), headers: _headers(s));
    if (r.statusCode == 404) return (null, null);
    if (r.statusCode != 200) throw 'lecture ${r.statusCode} : ${_msg(r)}';
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final sha = j['sha'] as String?;
    final content = (j['content'] as String?) ?? '';
    if (content.isNotEmpty && j['encoding'] == 'base64') {
      return (utf8.decode(base64.decode(content.replaceAll('\n', ''))), sha);
    }
    // fichier volumineux : on le télécharge brut
    final raw = await http.get(_url(s, path), headers: _headers(s, raw: true));
    if (raw.statusCode != 200) throw 'lecture ${raw.statusCode}';
    return (utf8.decode(raw.bodyBytes), sha);
  }

  static Future<void> _put(AppStore s, String path, String content, String? sha, String message) async {
    final r = await http.put(
      _url(s, path),
      headers: {..._headers(s), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': message,
        'content': base64.encode(utf8.encode(content)),
        if (sha != null) 'sha': sha,
      }),
    );
    if (r.statusCode == 409 || r.statusCode == 422) throw _Conflict();
    if (r.statusCode != 200 && r.statusCode != 201) throw 'écriture ${r.statusCode} : ${_msg(r)}';
  }

  static String _msg(http.Response r) {
    try {
      return (jsonDecode(r.body) as Map)['message']?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Envoie et récupère les changements. Renvoie un message d'erreur, ou null.
  static Future<String?> run(AppStore store, {bool tablet = false}) async {
    if (!configured(store) || busy) return null;
    busy = true;
    try {
      await store.mergePending(notify: false);
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final (remote, sha) = await _get(store, _file);
          if (remote != null && remote.isNotEmpty) {
            await store.mergeRemote(jsonDecode(remote) as Map<String, dynamic>);
          }
          final mine = jsonEncode(store.syncPayload());
          if (mine != remote) {
            await _put(store, _file, mine, sha, 'Synchro ${DateTime.now().toIso8601String()}');
          }
          break;
        } on _Conflict {
          if (attempt == 2) rethrow;
        }
      }
      await _syncPages(store, tablet);
      store.settings.lastSync = DateTime.now().millisecondsSinceEpoch;
      await store.save(stamp: false);
      store.refresh();
      lastError = null;
      return null;
    } catch (e) {
      lastError = e is _Conflict ? 'conflit d\'écriture, réessaie' : '$e';
      return lastError;
    } finally {
      busy = false;
    }
  }

  /// Pages manuscrites : chaque appareil envoie les siennes ; seule la tablette télécharge.
  static Future<void> _syncPages(AppStore store, bool tablet) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, int> read(String k) {
      try {
        return Map<String, dynamic>.from(jsonDecode(prefs.getString(k) ?? '{}') as Map)
            .map((key, v) => MapEntry(key, (v as num).toInt()));
      } catch (_) {
        return {};
      }
    }

    final up = read(_pagesUp);
    final down = read(_pagesDown);
    for (final n in store.notes) {
      final path = 'carnet/${n.id}.json';
      final known = up[n.id] ?? down[n.id] ?? 0;
      final local = await NotesIO.raw(n.id);
      if (local != null && n.mod > known) {
        // modifiée ici : on l'envoie
        String? sha;
        try {
          sha = (await _get(store, path)).$2;
        } catch (_) {}
        await _put(store, path, local, sha, 'Page ${n.day}');
        up[n.id] = n.mod;
        down[n.id] = n.mod;
      } else if (tablet && n.mod > (down[n.id] ?? 0)) {
        // modifiée ailleurs : on la récupère
        final (content, _) = await _get(store, path);
        if (content != null) {
          await NotesIO.saveRaw(n.id, content);
          down[n.id] = n.mod;
          up[n.id] = n.mod;
        }
      }
    }
    await prefs.setString(_pagesUp, jsonEncode(up));
    await prefs.setString(_pagesDown, jsonEncode(down));
  }
}

class _Conflict implements Exception {}
