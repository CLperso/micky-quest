import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'model.dart';
import 'store.dart';
import 'theme.dart';

/// Un message de la discussion avec Micky.
class MickyMsg {
  final String role; // user, micky, info
  final String text;
  final List<String> done; // ce que Micky a rangé (étiquettes lisibles)
  final List<Map<String, dynamic>> undo; // de quoi défaire
  bool undone;
  final int t;
  MickyMsg(this.role, this.text, {List<String>? done, List<Map<String, dynamic>>? undo, this.undone = false, int? t})
      : done = done ?? [],
        undo = undo ?? [],
        t = t ?? nowMs();

  factory MickyMsg.fromJson(Map<String, dynamic> j) => MickyMsg(
        '${j['r']}',
        '${j['x']}',
        done: j['d'] is List ? (j['d'] as List).map((e) => '$e').toList() : null,
        undo: j['u'] is List ? (j['u'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList() : null,
        undone: j['n'] == true,
        t: (j['t'] as num?)?.toInt(),
      );
  Map<String, dynamic> toJson() => {'r': role, 'x': text, 'd': done, 'u': undo, 'n': undone, 't': t};
}

/// Les moments où l'on parle à Micky.
const mickyModes = {
  'briefing': 'Briefing du matin',
  'bloque': 'Je bloque',
  'organise': 'Réorganise ma journée',
  'soir': 'Feu de camp',
  'semaine': 'Bilan de la semaine',
};

const _openers = {
  'briefing': 'Bonjour Micky, on fait le briefing ?',
  'bloque': 'Je bloque, j’arrive pas à m’y mettre.',
  'organise': 'Tu peux m’aider à réorganiser ma journée ?',
  'soir': 'On fait le feu de camp ?',
  'semaine': 'On fait le bilan de la semaine ?',
};

/// Micky qui parle : la discussion, le contexte envoyé, les actions qu'elle range dans le carnet.
class Micky extends ChangeNotifier {
  static final Micky i = Micky._();
  Micky._();

  static const _chatKey = 'carnet_micky_chat';
  static const _useKey = 'carnet_micky_use';
  static const fallbackModel = 'openai/gpt-oss-20b';
  static const dailyFree = 1000;

  final List<MickyMsg> chat = [];
  bool busy = false;
  int used = 0;
  String _usedDay = '';
  bool _loaded = false;
  final Map<String, String> _ids = {}; // identifiant court → identifiant réel

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final p = await SharedPreferences.getInstance();
    try {
      final raw = p.getString(_chatKey);
      if (raw != null) {
        chat.addAll((jsonDecode(raw) as List).map((e) => MickyMsg.fromJson(Map<String, dynamic>.from(e as Map))));
      }
      final u = (p.getString(_useKey) ?? '').split('|');
      if (u.length == 2) {
        _usedDay = u[0];
        used = int.tryParse(u[1]) ?? 0;
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    while (chat.length > 80) {
      chat.removeAt(0);
    }
    await p.setString(_chatKey, jsonEncode(chat.map((m) => m.toJson()).toList()));
    await p.setString(_useKey, '$_usedDay|$used');
  }

  int get usedToday => _usedDay == dayKey(DateTime.now()) ? used : 0;

  void _count() {
    final d = dayKey(DateTime.now());
    if (_usedDay != d) {
      _usedDay = d;
      used = 0;
    }
    used++;
  }

  /// Messages d'aujourd'hui (la discussion repart chaque matin, l'historique reste gardé).
  List<MickyMsg> get today {
    final start = DateTime.now().copyWith(hour: 0, minute: 0, second: 0).millisecondsSinceEpoch;
    return chat.where((m) => m.t >= start).toList();
  }

  Future<void> clearToday() async {
    final start = DateTime.now().copyWith(hour: 0, minute: 0, second: 0).millisecondsSinceEpoch;
    chat.removeWhere((m) => m.t >= start);
    await _save();
    notifyListeners();
  }

  // ------------------------------------------------------------------ personnalité
  String _persona(Store s, String mode) {
    final c = s.settings.mickyCoach;
    final dose = c < 0.34
        ? 'Aujourd’hui, penche nettement côté amie : écoute, chaleur, humour, peu de consignes. Tu proposes seulement si elle le demande.'
        : c > 0.66
            ? 'Aujourd’hui, penche côté coach : structurée, concrète, tu proposes un plan, tu relances, tu tiens ce qui a été décidé (avec tendresse).'
            : 'Dose équilibrée : d’abord tu accueilles, puis tu aides à passer à l’action.';
    final now = DateTime.now();
    final modeTxt = switch (mode) {
      'briefing' => 'MOMENT : briefing du matin. Aide-la à choisir 1 à 3 priorités réalistes selon son énergie et son cycle, range-les dans la journée, '
          'et demande-lui quand et où elle commence. Ce qui ne tient pas glisse à plus tard, sans culpabilité.',
      'bloque' => 'MOMENT : « je bloque ». Suis ces étapes, une seule question par message : 1) accueille en une phrase ; '
          '2) demande ce qui coince : c’est flou / rien ne presse / je tourne en rond / j’évite le dur / mon corps (faim, fatigue, assise) ; '
          '3) selon la réponse : flou → la toute prochaine chose visible (une action qu’on pourrait filmer) ; rien ne presse → une mini-échéance ; '
          'je tourne en rond → une version « moche mais finie » ; j’évite le dur → 10 min sur le dur seulement ; corps → 5 min pour le corps d’abord ; '
          '4) demande « dans 15 min, tu auras… ? » ; 5) lance un sprint (action sprint) et dis que tu restes avec elle. '
          'Rappelle une de ses raisons (objectifs) si ça aide. Une relance compte même si elle s’arrête avant.',
      'organise' => 'MOMENT : réorganiser la journée. Regarde ce qui est prévu, propose un ordre court (3 choses max pour le cœur de journée), '
          'reporte le reste (actions move), et annonce clairement ce que tu as déplacé.',
      'soir' => 'MOMENT : feu de camp du soir. Elle raconte en vrac ; toi tu remplis ses suivis à partir de ce qu’elle dit (actions log, habit, done) '
          'sans lui reposer de questions inutiles, puis tu relèves une vraie victoire et tu lui souhaites bonne nuit. Ne remplis que ce qu’elle a dit.',
      'semaine' => 'MOMENT : bilan de la semaine. Relève 2 ou 3 choses qui ont marché, un schéma que tu remarques dans ses suivis (prudemment, sans diagnostic), '
          'et propose 1 à 3 jalons doux pour la semaine prochaine.',
      _ => 'MOMENT : discussion libre.',
    };
    return '''
Tu es Micky, la chatte rousse et blanche de Charlotte, devenue la compagne de son carnet (bullet journal) pour l’aider à s’organiser avec un TDAH.
Tu parles en français, tu la tutoies, et tu restes toi : une chatte, avec un humour léger (ronronner, squatter le clavier, la fenêtre…), jamais lourd.

Tu es entre une amie et une coach :
- Amie : tu écoutes d’abord, tu reconnais quand c’est dur, tu te souviens de ce qu’elle t’a dit, tu fêtes les vraies victoires même petites. Jamais de culpabilité : une journée ratée est une information, pas un échec.
- Coach : une seule question à la fois ; tu transformes le flou en prochaine action concrète ; tu l’aides à décider quand et où elle commence ; tu proposes un ordre selon son énergie et son cycle, mais c’est elle qui décide ; tu rappelles avec tendresse ce qui avait été prévu.
$dose

Ta façon de parler :
- Comme une vraie amie qui écrit un message : naturel, chaleureux, précis, jamais de phrases toutes faites ni de jargon de coach.
- Tu t’appuies sur ce que tu vois dans son carnet (tâches, objectif de la semaine, suivis) plutôt que sur des conseils généraux.
- Tu varies tes tournures, tu ne répètes pas ce qu’elle vient de dire, tu ne commences pas chaque message par la même formule.

Règles :
- Réponses courtes : 1 à 4 phrases, pas de listes longues, pas de titres, pas de markdown.
- Pas de diagnostic ni de conseil médical. Si elle semble aller vraiment mal, dis-le franchement et encourage-la à en parler à un proche ou à un professionnel ; en cas d’idées suicidaires, le 3114 (France) répond jour et nuit.
- Tu ne mens pas sur ce que tu as fait : n’annonce un rangement que si tu mets l’action correspondante.

$modeTxt

Nous sommes le ${niceDay(now)} ${now.year}, il est ${now.hour} h ${two(now.minute)}.

ACTIONS : quand tu modifies le carnet, ajoute TOUT À LA FIN de ta réponse un bloc
<actions>[ ... ]</actions>
contenant une liste JSON. Actions possibles (utilise les identifiants courts du contexte) :
{"a":"add","text":"…","when":"AAAA-MM-JJ" ou "someday","kind":"task"|"event"|"note"}
{"a":"move","id":"t3","when":"AAAA-MM-JJ" ou "someday"}
{"a":"done","id":"t3"}
{"a":"log","field":"mood"|"energy"|"period"|"proMin"|"win"|"intention"|"journal","value":…}  (mood 1-5, energy 1-5, period 0-3, proMin en minutes, win/intention/journal en texte ; pour aujourd’hui)
{"a":"habit","id":"h1"}  (habitude faite aujourd’hui)
{"a":"track","id":"k1","value":…}  (un autre suivi, pour aujourd’hui)
{"a":"goal","id":"g1"}  (un pas vers un objectif aujourd’hui)
{"a":"sprint","min":15}  (lance un minuteur de travail)
{"a":"wgoal","text":"…"}  (fixe l’objectif de la semaine, si elle le décide)
{"a":"wgoalday","value":3|2|0}  (objectif de la semaine aujourd’hui : 3 atteint, 2 avancé, 0 pas aujourd’hui)
N’ajoute le bloc que si tu fais vraiment quelque chose. N’invente pas d’identifiants.
'''
        .trim();
  }

  // ------------------------------------------------------------------ contexte léger (~3K tokens max)
  String _context(Store s) {
    _ids.clear();
    final sees = s.settings.mickySees;
    final now = DateTime.now();
    final t = dayKey(now);
    final b = StringBuffer('CONTEXTE DU CARNET\n');
    var n = 0;
    String sid(Entry e) {
      final k = 't${++n}';
      _ids[k] = e.id;
      return k;
    }

    String line(Entry e) => '- ${sid(e)} ${e.kind == 'event' ? '(rdv) ' : e.kind == 'note' ? '(note) ' : ''}${e.text}${e.done ? ' [fait]' : ''}${e.dropped ? ' [abandonné]' : ''}';

    if (sees.contains('cycle')) {
      final cd = s.cycleDay(t);
      if (cd != null) b.writeln('Cycle : jour J$cd.');
    }
    if (sees.contains('tasks')) {
      final todayE = s.dayEntries(t);
      b.writeln('Aujourd’hui ($t) :');
      if (todayE.isEmpty) b.writeln('- rien de prévu');
      for (final e in todayE.take(20)) {
        b.writeln(line(e));
      }
      final left = s.leftovers();
      if (left.isNotEmpty) {
        b.writeln('Tâches restées ouvertes des jours d’avant :');
        for (final e in left.reversed.take(8)) {
          b.writeln('${line(e)} (prévu le ${e.when})');
        }
      }
      b.writeln('7 prochains jours :');
      var any = false;
      for (var i = 1; i <= 7; i++) {
        final k = dayKey(now.add(Duration(days: i)));
        final l = s.dayEntries(k).where((e) => !e.done && !e.dropped).take(5).toList();
        if (l.isEmpty) continue;
        any = true;
        b.writeln('$k (${dayNames[now.add(Duration(days: i)).weekday - 1]}) :');
        for (final e in l) {
          b.writeln(line(e));
        }
      }
      if (!any) b.writeln('- rien');
      final some = s.somedayEntries().take(6).toList();
      if (some.isNotEmpty) {
        b.writeln('Un jour / bientôt :');
        for (final e in some) {
          b.writeln(line(e));
        }
      }
    }
    final wg = s.weekGoal(now);
    b.writeln(wg.trim().isEmpty ? 'Objectif de la semaine : pas encore choisi.' : 'Objectif de la semaine : $wg');
    final goals = s.activeGoals;
    if (goals.isNotEmpty) {
      b.writeln('Objectifs (et ses raisons) :');
      for (var i = 0; i < goals.length; i++) {
        final g = goals[i];
        _ids['g${i + 1}'] = g.id;
        b.writeln('- g${i + 1} ${g.title} (${g.kind}) — pourquoi : ${g.why}');
      }
    }
    final habits = s.activeHabits;
    if (habits.isNotEmpty) {
      b.writeln('Habitudes :');
      for (var i = 0; i < habits.length; i++) {
        _ids['h${i + 1}'] = habits[i].id;
        b.writeln('- h${i + 1} ${habits[i].name} (${habits[i].perWeek}/semaine)');
      }
    }
    final custom = s.activeTrackers.where((t) => !const ['mood', 'energy', 'period', 'work'].contains(t.id)).toList();
    if (custom.isNotEmpty) {
      b.writeln('Autres suivis (id, type) :');
      for (var i = 0; i < custom.length; i++) {
        final t = custom[i];
        _ids['k${i + 1}'] = t.id;
        final ty = switch (t.type) { 'yesno' => 'oui/non (true/false)', 'scale' => '1 à 5', 'number' => 'nombre${t.unit.isEmpty ? '' : ' de ${t.unit}'}', 'duration' => 'durée en minutes', _ => 'texte' };
        b.writeln('- k${i + 1} ${t.name} : $ty');
      }
    }
    if (sees.contains('trackers')) {
      b.writeln('Suivis des 7 derniers jours (humeur 1-5, énergie 1-5, temps pro) :');
      for (var i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final l = s.logs[dayKey(d)];
        if (l == null || l.empty) continue;
        final hab = l.habits.map((id) => s.habits[id]?.name).whereType<String>().join(', ');
        b.writeln('- ${dayKey(d)} : humeur ${l.mood == 0 ? '?' : l.mood}, énergie ${l.energy == 0 ? '?' : l.energy}, pro ${fmtMin(l.proMin)}'
            '${hab.isEmpty ? '' : ', habitudes : $hab'}${_vals(s, l)}${l.win.isEmpty ? '' : ', victoire : ${_cut(l.win, 80)}'}${l.intention.isEmpty ? '' : ', intention : ${_cut(l.intention, 80)}'}');
      }
    }
    for (final j in s.journals.values.where((j) => !j.del && j.share && j.text.trim().isNotEmpty && now.difference(DateTime.tryParse(j.day) ?? DateTime(2000)).inDays <= 7)) {
      b.writeln('Page de journal qu’elle t’a montrée (${j.day}) : ${_cut(j.text, 500)}');
    }
    if (sees.contains('journal')) {
      for (final j in s.journals.values.where((j) => !j.del && !j.share && j.text.trim().isNotEmpty && now.difference(DateTime.tryParse(j.day) ?? DateTime(2000)).inDays <= 2)) {
        b.writeln('Journal (${j.day}) : ${_cut(j.text, 400)}');
      }
      for (var i = 2; i >= 0; i--) {
        final l = s.logs[dayKey(now.subtract(Duration(days: i)))];
        if (l != null && l.journal.isNotEmpty) b.writeln('Journal ${dayKey(now.subtract(Duration(days: i)))} : ${_cut(l.journal, 400)}');
      }
    }
    return _cut(b.toString(), 7000);
  }

  String _vals(Store s, DayLog l) {
    final parts = <String>[];
    for (final e in l.vals.entries) {
      if (e.key.startsWith('petal:')) continue;
      final t = s.trackers[e.key];
      if (t == null) continue;
      final v = e.value;
      parts.add('${t.name} ${v is bool ? (v ? 'oui' : 'non') : t.type == 'duration' && v is num ? fmtMin(v.toInt()) : _cut('$v', 60)}${t.unit.isEmpty || v is bool ? '' : ' ${t.unit}'}');
    }
    return parts.isEmpty ? '' : ', ${parts.join(', ')}';
  }

  static String _cut(String x, int n) => x.length <= n ? x : '${x.substring(0, n)}…';

  // ------------------------------------------------------------------ envoyer
  Future<void> send(Store s, String text, {String mode = 'libre'}) async {
    final claude = s.settings.aiProvider == 'claude';
    final key = (claude ? s.settings.claudeKey : s.settings.groqKey).trim();
    if (text.trim().isEmpty || busy) return;
    chat.add(MickyMsg('user', text.trim()));
    if (key.isEmpty) {
      chat.add(MickyMsg('info', claude ? 'Il me faut ta clé Claude pour parler (Réglages → Micky).' : 'Il me faut ta clé Groq pour parler (Réglages → Micky). C’est gratuit.'));
      await _save();
      notifyListeners();
      return;
    }
    busy = true;
    notifyListeners();
    try {
      final hist = today.where((m) => m.role != 'info').toList();
      final recent = hist.length > 14 ? hist.sublist(hist.length - 14) : hist;
      final messages = [
        {'role': 'system', 'content': '${_persona(s, mode)}\n\n${_context(s)}'},
        for (final m in recent) {'role': m.role == 'user' ? 'user' : 'assistant', 'content': _cut(m.text, 1500)},
      ];
      var (reply, err) = claude
          ? await _callClaude(s.settings.claudeModel.trim().isEmpty ? 'claude-haiku-5-5' : s.settings.claudeModel.trim(), key, messages)
          : await _call(s.settings.groqModel.trim().isEmpty ? 'openai/gpt-oss-120b' : s.settings.groqModel.trim(), key, messages);
      if (!claude && reply == null && err == 'limite' && s.settings.groqModel != fallbackModel) {
        (reply, err) = await _call(fallbackModel, key, messages);
      }
      if (reply == null) {
        chat.add(MickyMsg('info', err == 'limite' ? 'Je fais une petite sieste (limite gratuite atteinte). Réessaie dans une minute ✿' : (err ?? 'Je n’ai pas pu répondre.')));
      } else {
        _count();
        final (clean, actions) = _split(reply);
        final (done, undo) = await _apply(s, actions);
        chat.add(MickyMsg('micky', clean.isEmpty ? '✿' : clean, done: done, undo: undo));
      }
    } catch (e) {
      chat.add(MickyMsg('info', claude ? 'Je n’arrive pas à joindre Claude (connexion ?).' : 'Je n’arrive pas à joindre Groq (connexion ?).'));
    }
    busy = false;
    await _save();
    notifyListeners();
  }

  /// Claude (Anthropic) : système à part, messages qui alternent en commençant par l'utilisatrice.
  Future<(String?, String?)> _callClaude(String model, String key, List<Map<String, String>> messages) async {
    final system = messages.first['content'] ?? '';
    final conv = <Map<String, String>>[];
    for (final m in messages.skip(1)) {
      if (conv.isEmpty && m['role'] != 'user') continue;
      if (conv.isNotEmpty && conv.last['role'] == m['role']) {
        conv.last = {'role': m['role']!, 'content': '${conv.last['content']}\n\n${m['content']}'};
      } else {
        conv.add(Map<String, String>.from(m));
      }
    }
    if (conv.isEmpty) return (null, 'Rien à envoyer.');
    final r = await http
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'x-api-key': key,
            'anthropic-version': '2023-06-01',
            'anthropic-dangerous-direct-browser-access': 'true',
            'content-type': 'application/json',
          },
          body: jsonEncode({'model': model, 'max_tokens': 1200, 'system': system, 'messages': conv}),
        )
        .timeout(const Duration(seconds: 60));
    if (r.statusCode == 429 || r.statusCode == 529) return (null, 'limite');
    if (r.statusCode == 401) return (null, 'Ma clé Claude ne marche pas : vérifie-la dans Réglages → Micky.');
    if (r.statusCode >= 300) {
      String msg = '';
      try {
        msg = '${(jsonDecode(utf8.decode(r.bodyBytes)) as Map)['error']?['message'] ?? ''}';
      } catch (_) {}
      return (null, 'Claude refuse la demande (${r.statusCode}) : ${_cut(msg, 160)}');
    }
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final parts = (j['content'] as List).whereType<Map>().where((c) => c['type'] == 'text').map((c) => '${c['text']}');
    return (parts.join('\n'), null);
  }

  Future<(String?, String?)> _call(String model, String key, List<Map<String, String>> messages) async {
    final r = await http
        .post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {'Authorization': 'Bearer $key', 'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': model,
            'messages': messages,
            'temperature': 0.7,
            'max_completion_tokens': 1200,
            if (model.contains('gpt-oss')) 'reasoning_effort': 'low',
          }),
        )
        .timeout(const Duration(seconds: 45));
    if (r.statusCode == 429) return (null, 'limite');
    if (r.statusCode == 401) return (null, 'Ma clé Groq ne marche pas : vérifie-la dans Réglages → Micky.');
    if (r.statusCode == 404 || r.statusCode == 400) {
      String msg = '';
      try {
        msg = '${(jsonDecode(utf8.decode(r.bodyBytes)) as Map)['error']?['message'] ?? ''}';
      } catch (_) {}
      return (null, 'Groq refuse la demande (${r.statusCode}) : ${_cut(msg, 160)}');
    }
    if (r.statusCode >= 300) return (null, 'Groq ne répond pas bien (${r.statusCode}). Réessaie dans un moment.');
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final c = ((j['choices'] as List).first as Map)['message']['content'];
    return ('${c ?? ''}', null);
  }

  /// Sépare le texte et le bloc d'actions.
  (String, List<Map<String, dynamic>>) _split(String reply) {
    final re = RegExp(r'<actions>([\s\S]*?)(</actions>|$)');
    final m = re.firstMatch(reply);
    var text = reply.replaceAll(re, '').trim();
    text = text.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').trim();
    final acts = <Map<String, dynamic>>[];
    if (m != null) {
      try {
        var raw = m.group(1)!.trim();
        raw = raw.replaceAll(RegExp(r'^```(json)?'), '').replaceAll(RegExp(r'```$'), '').trim();
        final l = jsonDecode(raw);
        if (l is List) {
          for (final x in l) {
            if (x is Map) acts.add(Map<String, dynamic>.from(x));
          }
        }
      } catch (_) {}
    }
    return (text, acts);
  }

  String _when(String w) {
    if (w == 'someday') return 'un jour';
    if (w.length == 10) {
      final d = DateTime.tryParse(w);
      if (d == null) return w;
      final diff = dateOnly(d).difference(dateOnly(DateTime.now())).inDays;
      if (diff == 0) return 'aujourd’hui';
      if (diff == 1) return 'demain';
      return dayNames[d.weekday - 1];
    }
    return w;
  }

  bool _okWhen(String w) => w == 'someday' || RegExp(r'^\d{4}-\d{2}(-\d{2})?$').hasMatch(w);

  Future<(List<String>, List<Map<String, dynamic>>)> _apply(Store s, List<Map<String, dynamic>> acts) async {
    final done = <String>[], undo = <Map<String, dynamic>>[];
    final t = dayKey(DateTime.now());
    for (final a in acts) {
      try {
        switch (a['a']) {
          case 'add':
            final text = '${a['text'] ?? ''}'.trim();
            final when = '${a['when'] ?? t}';
            if (text.isEmpty || !_okWhen(when)) break;
            final kind = const ['task', 'event', 'note'].contains(a['kind']) ? '${a['kind']}' : 'task';
            final e = await s.addEntry(text, when: when, kind: kind);
            done.add('$text → ${_when(when)}');
            undo.add({'a': 'del', 'id': e.id});
          case 'move':
            final e = s.entries[_ids['${a['id']}'] ?? ''];
            final when = '${a['when'] ?? ''}';
            if (e == null || !_okWhen(when)) break;
            undo.add({'a': 'move', 'id': e.id, 'when': e.when, 'drop': e.dropped});
            await s.moveEntry(e, when);
            done.add('${_cut(e.text, 40)} → ${_when(when)}');
          case 'done':
            final e = s.entries[_ids['${a['id']}'] ?? ''];
            if (e == null || e.done) break;
            await s.toggleDone(e);
            undo.add({'a': 'undone', 'id': e.id});
            done.add('fait : ${_cut(e.text, 40)}');
          case 'log':
            final l = s.log(t);
            final f = '${a['field']}';
            final v = a['value'];
            int iv(int lo, int hi) => (v is num ? v.toInt() : int.tryParse('$v') ?? lo).clamp(lo, hi);
            undo.add({'a': 'log', 'field': f, 'value': switch (f) { 'mood' => l.mood, 'energy' => l.energy, 'period' => l.period, 'proMin' => l.proMin, 'win' => l.win, 'intention' => l.intention, 'journal' => l.journal, _ => null }});
            switch (f) {
              case 'mood':
                l.mood = iv(1, 5);
                done.add('humeur · ${const ['', 'dure', 'bof', 'neutre', 'bien', 'super'][l.mood]}');
              case 'energy':
                l.energy = iv(1, 5);
                done.add('énergie · ${l.energy}/5');
              case 'period':
                l.period = iv(0, 3);
                done.add('règles · ${const ['rien', 'léger', 'moyen', 'abondant'][l.period]}');
              case 'proMin':
                l.proMin = iv(0, 900);
                done.add('travail · ${fmtMin(l.proMin)}');
              case 'win':
                l.win = '$v';
                done.add('victoire notée');
              case 'intention':
                l.intention = '$v';
                done.add('intention notée');
              case 'journal':
                l.journal = l.journal.isEmpty ? '$v' : '${l.journal}\n$v';
                done.add('ajouté au journal');
              default:
                undo.removeLast();
            }
            await s.touchLog(l);
          case 'track':
            final id = _ids['${a['id']}'];
            final tr = id == null ? null : s.trackers[id];
            if (tr == null) break;
            var v = a['value'];
            if (tr.type == 'yesno') v = v == true || v == 'true' || v == 'oui';
            if (tr.type == 'number' || tr.type == 'duration' || tr.type == 'scale') v = v is num ? v.toInt() : int.tryParse('$v') ?? 0;
            undo.add({'a': 'track', 'id': tr.id, 'value': s.tval(t, tr.id)});
            await s.setTval(t, tr.id, v);
            done.add('${tr.name} · ${v is bool ? (v ? 'oui' : 'non') : tr.type == 'duration' && v is int ? fmtMin(v) : v}');
          case 'habit':
            final id = _ids['${a['id']}'];
            final h = id == null ? null : s.habits[id];
            final l = s.log(t);
            if (h == null || l.habits.contains(h.id)) break;
            l.habits.add(h.id);
            await s.touchLog(l);
            undo.add({'a': 'unhabit', 'id': h.id});
            done.add('${h.name} · fait');
          case 'goal':
            final id = _ids['${a['id']}'];
            final g = id == null ? null : s.goals[id];
            final l = s.log(t);
            if (g == null || l.goals.contains(g.id)) break;
            l.goals.add(g.id);
            await s.touchLog(l);
            undo.add({'a': 'ungoal', 'id': g.id});
            done.add('un pas vers ${_cut(g.title, 30)}');
          case 'wgoal':
            final w = s.weekLog(DateTime.now());
            undo.add({'a': 'wgoal', 'value': w.win});
            w.win = '${a['text'] ?? ''}'.trim();
            await s.touchLog(w);
            done.add('objectif de la semaine noté');
          case 'wgoalday':
            final v = a['value'] is num ? (a['value'] as num).toInt().clamp(0, 3) : 2;
            undo.add({'a': 'wgoalday', 'value': s.level(t, 'wgoal')});
            await s.setWeekGoalDay(t, v);
            done.add('objectif : ${const ['pas aujourd’hui', 'un peu', 'avancé', 'atteint'][v]}');
          case 'sprint':
            if (s.timerStart == 0) await s.startTimer();
            final m = a['min'] is num ? (a['min'] as num).toInt() : 15;
            done.add('sprint de $m min lancé');
        }
      } catch (_) {}
    }
    return (done, undo);
  }

  /// Défait ce que Micky a rangé dans un message.
  Future<void> revert(Store s, MickyMsg m) async {
    final t = dayKey(DateTime.fromMillisecondsSinceEpoch(m.t));
    for (final u in m.undo.reversed) {
      final e = s.entries['${u['id']}'];
      switch (u['a']) {
        case 'del':
          if (e != null) await s.deleteEntry(e);
        case 'move':
          if (e != null) {
            e.when = '${u['when']}';
            e.dropped = u['drop'] == true;
            await s.updateEntry(e);
          }
        case 'undone':
          if (e != null && e.done) await s.toggleDone(e);
        case 'log':
          final l = s.log(t);
          final v = u['value'];
          switch (u['field']) {
            case 'mood':
              l.mood = v as int;
            case 'energy':
              l.energy = v as int;
            case 'period':
              l.period = v as int;
            case 'proMin':
              l.proMin = v as int;
            case 'win':
              l.win = '$v';
            case 'intention':
              l.intention = '$v';
            case 'journal':
              l.journal = '$v';
          }
          await s.touchLog(l);
        case 'track':
          await s.setTval(t, '${u['id']}', u['value']);
        case 'wgoal':
          final w = s.weekLog(DateTime.fromMillisecondsSinceEpoch(m.t));
          w.win = '${u['value'] ?? ''}';
          await s.touchLog(w);
        case 'wgoalday':
          await s.setWeekGoalDay(t, u['value'] is int ? u['value'] as int : null);
        case 'unhabit':
          final l = s.log(t);
          l.habits.remove('${u['id']}');
          await s.touchLog(l);
        case 'ungoal':
          final l = s.log(t);
          l.goals.remove('${u['id']}');
          await s.touchLog(l);
      }
    }
    m.undone = true;
    await _save();
    notifyListeners();
  }
}

/// Le petit portrait de Micky, avec son nœud.
class MickyAvatar extends StatelessWidget {
  final double size;
  final String img;
  const MickyAvatar({super.key, this.size = 40, this.img = 'm20'});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: size > 34 ? 3 : 2),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
          image: DecorationImage(image: AssetImage('assets/micky/$img.jpg'), fit: BoxFit.cover),
        ),
      );
}

/// Le panneau de discussion.
class MickyPanel extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onSettings;
  const MickyPanel({super.key, required this.onClose, this.onSettings});
  @override
  State<MickyPanel> createState() => _MickyPanelState();
}

class _MickyPanelState extends State<MickyPanel> {
  final _c = TextEditingController();
  final _scroll = ScrollController();
  String _mode = 'libre';

  @override
  void initState() {
    super.initState();
    Micky.i.load();
    Micky.i.addListener(_changed);
    final h = DateTime.now().hour;
    _mode = h < 12 ? 'briefing' : (h >= 19 ? 'soir' : 'libre');
  }

  @override
  void dispose() {
    Micky.i.removeListener(_changed);
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _send([String? text, String? mode]) async {
    final s = StoreScope.read(context);
    final t = text ?? _c.text;
    if (mode != null) _mode = mode;
    if (text == null) _c.clear();
    await Micky.i.send(s, t, mode: _mode);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = Pal.byId(store.settings.theme);
    final m = Micky.i;
    final msgs = m.today;
    final claude = store.settings.aiProvider == 'claude';
    final noKey = (claude ? store.settings.claudeKey : store.settings.groqKey).trim().isEmpty;

    Widget bubble(MickyMsg x) {
      if (x.role == 'user') {
        return Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10, left: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(color: pal.card, border: Border.all(color: pal.line), borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(4))),
            child: Text(x.text, style: hand(20, pal.ink)),
          ),
        );
      }
      final info = x.role == 'info';
      return Padding(
        padding: const EdgeInsets.only(bottom: 10, right: 24),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const MickyAvatar(size: 34),
          const SizedBox(width: 8),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: info ? pal.line : pal.tint,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18)),
                ),
                child: SelectableText(x.text, style: body(14, pal.ink, w: FontWeight.w600).copyWith(height: 1.4)),
              ),
              if (x.done.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final d in x.done)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: x.undone ? pal.line : pal.acc2.withValues(alpha: .22), borderRadius: BorderRadius.circular(999)),
                      child: Text('${x.undone ? '↺' : '✓'} $d', style: body(11.5, pal.ink, w: FontWeight.w800).copyWith(decoration: x.undone ? TextDecoration.lineThrough : null)),
                    ),
                  if (!x.undone && x.undo.isNotEmpty)
                    InkWell(
                      onTap: () => Micky.i.revert(store, x),
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: Text('annuler', style: body(11.5, pal.soft, w: FontWeight.w800).copyWith(decoration: TextDecoration.underline))),
                    ),
                ]),
              ],
            ]),
          ),
        ]),
      );
    }

    Widget modeChip(String id) => Padding(
          padding: const EdgeInsets.only(right: 6, bottom: 6),
          child: ActionChip(
            label: Text(mickyModes[id]!, style: body(12, pal.ink, w: FontWeight.w800)),
            backgroundColor: pal.card,
            side: BorderSide(color: pal.line),
            shape: const StadiumBorder(),
            onPressed: m.busy ? null : () => _send(_openers[id], id),
          ),
        );

    return Material(
      color: pal.paper,
      elevation: 6,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 6, 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: pal.line))),
          child: Row(children: [
            const MickyAvatar(size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Micky', style: script(26, pal.acc)),
                Text(noKey ? 'clé à ajouter' : claude ? 'Claude Haiku · ${m.usedToday} messages aujourd’hui' : 'gratuit · Groq · ${m.usedToday} / ${Micky.dailyFree} aujourd’hui', style: body(11, pal.soft, w: FontWeight.w800)),
              ]),
            ),
            if (msgs.isNotEmpty) IconButton(tooltip: 'Nouvelle discussion', onPressed: () => Micky.i.clearToday(), icon: Icon(Icons.refresh_rounded, color: pal.soft)),
            if (widget.onSettings != null) IconButton(tooltip: 'Réglages de Micky', onPressed: widget.onSettings, icon: Icon(Icons.tune_rounded, color: pal.soft)),
            IconButton(onPressed: widget.onClose, icon: Icon(Icons.close_rounded, color: pal.soft)),
          ]),
        ),
        Expanded(
          child: noKey
              ? const SingleChildScrollView(padding: EdgeInsets.all(16), child: MickyKeyCard())
              : ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(14, 14, 14, 6), children: [
                  if (msgs.isEmpty)
                    bubble(MickyMsg('micky', switch (_mode) {
                      'briefing' => 'Coucou ! On regarde ta journée ensemble ? Dis-moi comment tu te sens, ou touche « Briefing du matin ».',
                      'soir' => 'La journée est finie. Tu me racontes en vrac ? Je remplis tes suivis pendant ce temps.',
                      _ => 'Je suis là, sur le bureau. Dis-moi ce qui se passe.',
                    })),
                  for (final x in msgs) bubble(x),
                  if (m.busy)
                    Padding(
                      padding: const EdgeInsets.only(left: 42, bottom: 10),
                      child: Text('Micky réfléchit en ronronnant…', style: body(12, pal.soft, w: FontWeight.w700).copyWith(fontStyle: FontStyle.italic)),
                    ),
                ]),
        ),
        if (!noKey)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: pal.line))),
            child: Column(children: [
              SizedBox(
                width: double.infinity,
                child: Wrap(children: [for (final id in mickyModes.keys) modeChip(id)]),
              ),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _c,
                    minLines: 1,
                    maxLines: 4,
                    style: hand(20, pal.ink),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'écris au stylet ou au clavier…',
                      hintStyle: hand(19, pal.soft),
                      filled: true,
                      fillColor: pal.card,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: pal.line)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: pal.line)),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: pal.acc),
                  onPressed: m.busy ? null : () => _send(),
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ]),
            ]),
          ),
      ]),
    );
  }
}

/// Coller la clé Groq (gratuite).
class MickyKeyCard extends StatefulWidget {
  const MickyKeyCard({super.key});
  @override
  State<MickyKeyCard> createState() => _MickyKeyCardState();
}

class _MickyKeyCardState extends State<MickyKeyCard> {
  final _k = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = Pal.byId(store.settings.theme);
    final claude = store.settings.aiProvider == 'claude';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SegmentedButton<String>(
        segments: const [ButtonSegment(value: 'groq', label: Text('Groq · gratuit')), ButtonSegment(value: 'claude', label: Text('Claude Haiku'))],
        selected: {store.settings.aiProvider},
        onSelectionChanged: (v) {
          store.settings.aiProvider = v.first;
          store.commit();
        },
      ),
      const SizedBox(height: 12),
      Text(claude ? 'Pour que je parle avec Claude (quelques centimes par mois) :' : 'Pour que je parle, il me faut une clé Groq. C’est gratuit :', style: body(14, pal.ink, w: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(
          claude
              ? '1. Va sur console.anthropic.com et crée un compte.\n2. « Billing » : ajoute 5 \$ de crédit (ça dure des mois).\n3. « API Keys » → « Create Key », copie la clé (sk-ant-…) et colle-la ici.'
              : '1. Va sur console.groq.com et connecte-toi (Google marche).\n2. Menu « API Keys », puis « Create API Key ».\n3. Copie la clé (elle commence par gsk_) et colle-la ici.',
          style: body(13, pal.soft, w: FontWeight.w700).copyWith(height: 1.5)),
      const SizedBox(height: 12),
      TextField(controller: _k, obscureText: true, decoration: InputDecoration(labelText: claude ? 'Clé Claude (sk-ant-…)' : 'Clé Groq (gsk_…)')),
      const SizedBox(height: 10),
      FilledButton(
        onPressed: () async {
          if (claude) {
            store.settings.claudeKey = _k.text.trim();
          } else {
            store.settings.groqKey = _k.text.trim();
          }
          await store.commit();
        },
        child: const Text('C’est parti'),
      ),
      const SizedBox(height: 10),
      Text('Ta clé reste sur cet appareil. Je n’envoie qu’un petit résumé de ton carnet, selon ce que tu m’autorises à voir. Ni Groq ni Claude ne s’en servent pour entraîner leurs modèles.', style: body(11.5, pal.soft, w: FontWeight.w600)),
    ]);
  }
}

/// Réglages de Micky (dans l'écran Réglages).
class MickySettings extends StatefulWidget {
  const MickySettings({super.key});
  @override
  State<MickySettings> createState() => _MickySettingsState();
}

class _MickySettingsState extends State<MickySettings> {
  late final _key = TextEditingController(text: StoreScope.read(context).settings.groqKey);
  late final _model = TextEditingController(text: StoreScope.read(context).settings.groqModel);
  late final _ckey = TextEditingController(text: StoreScope.read(context).settings.claudeKey);
  late final _cmodel = TextEditingController(text: StoreScope.read(context).settings.claudeModel);

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final st = store.settings;
    final pal = Pal.byId(st.theme);
    Widget see(String id, String title, String sub) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: st.mickySees.contains(id),
          title: Text(title),
          subtitle: Text(sub),
          onChanged: (v) {
            v ? st.mickySees.add(id) : st.mickySees.remove(id);
            store.touchSettings();
          },
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Label('Micky, ma compagne', pal.soft),
      SegmentedButton<String>(
        segments: const [ButtonSegment(value: 'groq', label: Text('Groq · gratuit')), ButtonSegment(value: 'claude', label: Text('Claude Haiku · payant'))],
        selected: {st.aiProvider},
        onSelectionChanged: (v) {
          setState(() => st.aiProvider = v.first);
          store.commit();
        },
      ),
      if (st.aiProvider == 'claude') ...[
        TextField(
          controller: _ckey,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Clé Claude (console.anthropic.com)'),
          onChanged: (v) {
            st.claudeKey = v.trim();
            store.save();
          },
        ),
        TextField(
          controller: _cmodel,
          decoration: const InputDecoration(labelText: 'Modèle', helperText: 'claude-haiku-5-5 · environ quelques centimes par mois'),
          onChanged: (v) {
            st.claudeModel = v.trim();
            store.save();
          },
        ),
      ],
      if (st.aiProvider != 'claude') TextField(
        controller: _key,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Clé Groq (gratuite, console.groq.com)'),
        onChanged: (v) {
          st.groqKey = v.trim();
          store.save();
        },
      ),
      if (st.aiProvider != 'claude') TextField(
        controller: _model,
        decoration: const InputDecoration(labelText: 'Modèle', helperText: 'openai/gpt-oss-120b · en secours openai/gpt-oss-20b'),
        onChanged: (v) {
          st.groqModel = v.trim();
          store.save();
        },
      ),
      const SizedBox(height: 14),
      Text('Micky, entre amie et coach', style: body(13, pal.ink)),
      Slider(
        value: st.mickyCoach.clamp(0, 1),
        onChanged: (v) => setState(() => st.mickyCoach = v),
        onChangeEnd: (_) => store.touchSettings(),
      ),
      Row(children: [
        Text('plus amie · écoute, humour', style: body(11, pal.soft)),
        const Spacer(),
        Text('plus coach · cadre, relance', style: body(11, pal.soft)),
      ]),
      const SizedBox(height: 8),
      Text('Ce que Micky voit', style: body(13, pal.ink)),
      see('tasks', 'Tâches et rendez-vous', 'pour ranger ta journée'),
      see('trackers', 'Suivis des 7 derniers jours', 'pour repérer tes schémas'),
      see('cycle', 'Cycle', 'pour adapter la charge'),
      see('journal', 'Tout mon journal', 'sinon, seulement les pages que je lui montre'),
      Text('Tes dessins et ton journal privé ne sont jamais envoyés. Ni Groq ni Claude ne s’en servent pour entraîner leurs modèles.', style: body(11.5, pal.soft, w: FontWeight.w600)),
    ]);
  }
}
