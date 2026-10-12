import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const kStateKey = 'quest_state_v1';
const kPendingKey = 'pending_checkins_v1';

const xpPerLevel = 400;

class Discovery {
  final String id;
  final String title;
  final String text; // vide si encore verrouillée
  final double progress; // 0..1 vers le déblocage
  final String need;
  const Discovery(this.id, this.title, this.text, this.progress, this.need);
  bool get unlocked => text.isNotEmpty;
}

class ReplayEvent {
  final int ts;
  final String kind; // quest, mood, food, drink, coffee, free, task
  final String title;
  final String detail;
  final String photo;
  const ReplayEvent(this.ts, this.kind, this.title, this.detail, [this.photo = '']);
}

class AppStore extends ChangeNotifier {
  late SharedPreferences _prefs;

  List<Task> tasks = [];
  List<SessionRec> sessions = [];
  List<CheckIn> checkins = [];
  List<LogEntry> logs = [];
  Map<String, DayPlan> plans = {};
  List<XpEvent> xpEvents = [];
  List<String> inventory = [];
  Settings settings = Settings();
  int xp = 0;
  int jokers = 1;
  String lastChest = '';

  String get todayKey => dayKey(DateTime.now());
  String get tomorrowKey => dayKey(DateTime.now().add(const Duration(days: 1)));

  // ---------- Chargement et sauvegarde ----------

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    await _prefs.reload();
    final raw = _prefs.getString(kStateKey);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        List<Map<String, dynamic>> list(String k) =>
            ((j[k] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        tasks = list('tasks').map(Task.fromJson).toList();
        sessions = list('sessions').map(SessionRec.fromJson).toList();
        checkins = list('checkins').map(CheckIn.fromJson).toList();
        logs = list('logs').map(LogEntry.fromJson).toList();
        xpEvents = list('xpEvents').map(XpEvent.fromJson).toList();
        plans = {
          for (final p in list('plans').map(DayPlan.fromJson)) p.day: p,
        };
        inventory = ((j['inventory'] as List?) ?? []).map((e) => e.toString()).toList();
        settings = Settings.fromJson(Map<String, dynamic>.from((j['settings'] as Map?) ?? {}));
        xp = (j['xp'] as num?)?.toInt() ?? 0;
        jokers = (j['jokers'] as num?)?.toInt() ?? 1;
        lastChest = (j['lastChest'] as String?) ?? '';
      } catch (e) {
        debugPrint('État illisible : $e');
      }
    }
    _rollOver();
    await mergePending(notify: false);
    notifyListeners();
  }

  Future<void> save() async {
    final j = {
      'tasks': tasks.map((e) => e.toJson()).toList(),
      'sessions': sessions.map((e) => e.toJson()).toList(),
      'checkins': checkins.map((e) => e.toJson()).toList(),
      'logs': logs.map((e) => e.toJson()).toList(),
      'xpEvents': xpEvents.map((e) => e.toJson()).toList(),
      'plans': plans.values.map((e) => e.toJson()).toList(),
      'inventory': inventory,
      'settings': settings.toJson(),
      'xp': xp,
      'jokers': jokers,
      'lastChest': lastChest,
    };
    await _prefs.setString(kStateKey, jsonEncode(j));
  }

  Future<void> commit() async {
    await save();
    notifyListeners();
  }

  void refresh() => notifyListeners();

  /// Les tâches d'un jour passé non rangées reviennent à trier aujourd'hui.
  void _rollOver() {
    final today = todayKey;
    for (final t in tasks) {
      if (!t.done && !t.removed && t.day.compareTo(today) < 0) {
        t.day = today;
        t.deferred = true;
      }
    }
  }

  /// Réponses données depuis les notifications (appli fermée).
  Future<void> mergePending({bool notify = true}) async {
    await _prefs.reload();
    final list = _prefs.getStringList(kPendingKey) ?? [];
    if (list.isEmpty) return;
    for (final s in list) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        final c = CheckIn.fromJson(m);
        final existing = checkins.where((x) => x.ts == c.ts).toList();
        if (existing.isNotEmpty) {
          final e = existing.first;
          if (c.mood > 0) e.mood = c.mood;
          if (c.activity.isNotEmpty) e.activity = c.activity;
        } else {
          checkins.add(c);
          _gainXp(5, 'Check-in');
        }
      } catch (_) {}
    }
    checkins.sort((a, b) => a.ts.compareTo(b.ts));
    await _prefs.setStringList(kPendingKey, []);
    await save();
    if (notify) notifyListeners();
  }

  // ---------- XP, niveau, série ----------

  int get level => 1 + xp ~/ xpPerLevel;
  int get xpInLevel => xp % xpPerLevel;

  String get title {
    const titles = [
      'Apprentie organisée',
      'Exploratrice du temps',
      'Chasseuse de quêtes',
      'Maîtresse du focus',
      'Gardienne du temps',
      'Légende de Micky',
    ];
    return titles[min(titles.length - 1, (level - 1) ~/ 3)];
  }

  void _gainXp(int amount, String reason) {
    xp += amount;
    xpEvents.add(XpEvent(ts: DateTime.now().millisecondsSinceEpoch, amount: amount, reason: reason));
  }

  int xpOn(String day) => xpEvents
      .where((e) => dayKey(DateTime.fromMillisecondsSinceEpoch(e.ts)) == day)
      .fold(0, (a, e) => a + e.amount);

  Set<String> get _activeDays {
    final s = <String>{};
    for (final c in checkins) {
      s.add(dayKey(DateTime.fromMillisecondsSinceEpoch(c.ts)));
    }
    for (final x in sessions) {
      s.add(dayKey(DateTime.fromMillisecondsSinceEpoch(x.start)));
    }
    for (final p in plans.values) {
      if (p.briefingDone || p.eveningDone) s.add(p.day);
    }
    return s;
  }

  /// Série de jours actifs ; les jokers couvrent les jours manqués.
  int get streak {
    final active = _activeDays;
    var d = DateTime.now();
    if (!active.contains(dayKey(d))) d = d.subtract(const Duration(days: 1));
    var n = 0;
    var spare = jokers;
    for (var i = 0; i < 400; i++) {
      if (active.contains(dayKey(d))) {
        n++;
      } else if (spare > 0 && n > 0) {
        spare--;
      } else {
        break;
      }
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  // ---------- Stats de personnage (0 à 20) ----------

  List<CheckIn> _recentCheckins(int days) {
    final from = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    return checkins.where((c) => c.ts >= from).toList();
  }

  int get statFocus {
    final c = _recentCheckins(7).where((c) => c.activity.isNotEmpty).toList();
    if (c.isEmpty) return 0;
    final q = c.where((x) => x.activity == Act.quest).length;
    return (20 * q / c.length).round();
  }

  int get statTime {
    final from = DateTime.now().subtract(const Duration(days: 14)).millisecondsSinceEpoch;
    final s = sessions.where((x) => x.finished && x.start >= from && x.ratio > 0).toList();
    if (s.isEmpty) return 0;
    final err = s.map((x) => (log(x.ratio)).abs()).reduce((a, b) => a + b) / s.length;
    return (20 * (1 - min(1.0, err))).round();
  }

  int get statConstancy => min(20, streak);

  int get statSerenity {
    final c = _recentCheckins(7).where((c) => c.mood > 0).toList();
    if (c.isEmpty) return 0;
    final m = c.map((x) => x.mood).reduce((a, b) => a + b) / c.length;
    return (20 * (m - 1) / 4).round();
  }

  // ---------- Plans du jour ----------

  DayPlan plan(String day) => plans.putIfAbsent(day, () => DayPlan(day: day));
  DayPlan get today => plan(todayKey);

  Future<void> finishBriefing() async {
    if (!today.briefingDone) {
      today.briefingDone = true;
      _gainXp(30, 'Briefing du matin');
    }
    await commit();
  }

  Future<String> finishEvening() async {
    var chest = '';
    if (!today.eveningDone) {
      today.eveningDone = true;
      _gainXp(30, 'Feu de camp');
      chest = _openChest();
    }
    await commit();
    return chest;
  }

  // ---------- Tâches ----------

  List<Task> get openTasks {
    final t = tasks.where((t) => !t.done && !t.removed && t.day.compareTo(todayKey) <= 0).toList();
    t.sort((a, b) => a.order.compareTo(b.order));
    return t;
  }

  List<Task> tasksIn(String quad) => openTasks.where((t) => t.quad == quad).toList();

  List<Task> questSteps(String category) =>
      tasks.where((t) => t.category == category && t.day == todayKey && !t.removed).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  Task? get boss {
    for (final t in tasks) {
      if (t.isBoss && !t.removed && !t.done) return t;
    }
    return null;
  }

  Task? taskById(String id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<Task> addTask(String title, {String category = '', int estimate = 0, String quad = Quad.inbox}) async {
    final t = Task(
      title: title.trim(),
      category: category,
      estimateMin: estimate,
      quad: quad,
      day: todayKey,
      order: tasks.length,
    );
    tasks.add(t);
    await commit();
    return t;
  }

  Future<void> moveTask(Task t, String quad) async {
    t.quad = quad;
    await commit();
  }

  static const _quadXp = {Quad.doNow: 30, Quad.plan: 25, Quad.light: 10, Quad.drop: 5, Quad.inbox: 10};

  Future<void> completeTask(Task t) async {
    if (t.done) {
      t.done = false;
      t.doneAt = 0;
    } else {
      t.done = true;
      t.doneAt = DateTime.now().millisecondsSinceEpoch;
      _gainXp(_quadXp[t.quad] ?? 10, 'Tâche faite');
    }
    await commit();
  }

  Future<void> deferTask(Task t) async {
    t.day = tomorrowKey;
    t.deferred = true;
    await commit();
  }

  Future<void> removeTask(Task t) async {
    t.removed = true;
    await commit();
  }

  Future<void> setBoss(Task t) async {
    for (final x in tasks) {
      x.isBoss = false;
    }
    t.isBoss = true;
    t.bossHp = 100;
    await commit();
  }

  List<Task> get unfinishedToday => tasks
      .where((t) => !t.done && !t.removed && t.day == todayKey)
      .toList();

  List<Task> get deferredToday => tasks.where((t) => t.deferred && !t.done && !t.removed && t.day == todayKey).toList();

  // ---------- Sessions ----------

  SessionRec? get runningSession {
    for (final s in sessions) {
      if (s.running) return s;
    }
    return null;
  }

  Future<SessionRec> startSession(String taskId, String title, int predicted) async {
    final s = SessionRec(
      taskId: taskId,
      title: title,
      start: DateTime.now().millisecondsSinceEpoch,
      predictedMin: predicted,
    );
    sessions.add(s);
    final t = taskById(taskId);
    if (t != null && t.estimateMin == 0) t.estimateMin = predicted;
    await commit();
    return s;
  }

  /// Termine la session. Renvoie le butin éventuel.
  Future<String> endSession(SessionRec s, {required bool finished}) async {
    s.end = DateTime.now().millisecondsSinceEpoch;
    s.finished = finished;
    final minutes = s.actualMin;
    _gainXp(10 + min(60, minutes).round() ~/ 2, 'Session');
    final t = taskById(s.taskId);
    if (t != null && t.isBoss) {
      t.bossHp = max(0, t.bossHp - max(10, (minutes / 15).floor() * 20));
      if (t.bossHp == 0) {
        t.done = true;
        t.doneAt = s.end;
        _gainXp(150, 'Boss vaincu');
      }
    }
    var chest = '';
    if (s.onTarget) {
      _gainXp(20, 'Pari réussi');
      chest = _openChest();
    }
    await commit();
    return chest;
  }

  String _openChest() {
    final r = Random();
    String item;
    if (r.nextInt(5) == 0) {
      item = Loot.rewards[r.nextInt(Loot.rewards.length)];
      if (item == 'Joker de série') jokers++;
      if (item == '+50 XP bonus') _gainXp(50, 'Coffre');
    } else {
      final notOwned = Loot.items.where((i) => !inventory.contains(i)).toList();
      item = notOwned.isEmpty ? Loot.items[r.nextInt(Loot.items.length)] : notOwned[r.nextInt(notOwned.length)];
      if (!inventory.contains(item)) inventory.add(item);
    }
    lastChest = item;
    return item;
  }

  // ---------- Check-ins et journal ----------

  Future<void> addCheckIn(CheckIn c) async {
    checkins.add(c);
    _gainXp(5, 'Check-in');
    await commit();
  }

  Future<void> addLog(LogEntry e) async {
    logs.add(e);
    await commit();
  }

  List<CheckIn> checkinsOn(String day) =>
      checkins.where((c) => dayKey(DateTime.fromMillisecondsSinceEpoch(c.ts)) == day).toList();

  List<LogEntry> logsOn(String day) =>
      logs.where((c) => dayKey(DateTime.fromMillisecondsSinceEpoch(c.ts)) == day).toList();

  List<SessionRec> sessionsOn(String day) =>
      sessions.where((c) => dayKey(DateTime.fromMillisecondsSinceEpoch(c.start)) == day).toList();

  // ---------- Cycle ----------

  int? cycleDay(DateTime d) {
    if (settings.cycleStart.isEmpty) return null;
    final start = parseDay(settings.cycleStart);
    final diff = DateTime(d.year, d.month, d.day).difference(start).inDays;
    final len = max(20, settings.cycleLength);
    return ((diff % len) + len) % len + 1;
  }

  String? phaseOn(DateTime d) {
    final n = cycleDay(d);
    return n == null ? null : cyclePhase(n, max(20, settings.cycleLength));
  }

  // ---------- Récap de la journée ----------

  List<ReplayEvent> replay(String day) {
    final ev = <ReplayEvent>[];
    for (final s in sessionsOn(day)) {
      final detail = s.running
          ? 'en cours · pari ${s.predictedMin} min'
          : 'pari ${s.predictedMin} min · réel ${s.actualMin.round()} min${s.onTarget ? ' · coffre gagné' : ''}${s.finished ? '' : ' · interrompue'}';
      ev.add(ReplayEvent(s.start, 'quest', 'Session · ${s.title}', detail));
    }
    for (final c in checkinsOn(day)) {
      final parts = <String>[];
      if (c.reason.isNotEmpty) parts.add('raison : ${c.reason.toLowerCase()}');
      if (c.mood > 0) parts.add('humeur ${moodLabels[c.mood - 1].toLowerCase()}');
      if (c.energy >= 0) parts.add('énergie ${c.energy} %');
      if (c.note.isNotEmpty) parts.add(c.note);
      ev.add(ReplayEvent(c.ts, 'mood', 'Check-in · ${(Act.labels[c.activity] ?? 'humeur').toLowerCase()}', parts.join(' · ')));
    }
    for (final l in logsOn(day)) {
      final kind = l.kind == LogKind.meal
          ? 'food'
          : l.kind == LogKind.energy
              ? 'drink'
              : l.kind == LogKind.coffee
                  ? 'coffee'
                  : 'free';
      ev.add(ReplayEvent(l.ts, kind, LogKind.labels[l.kind] ?? 'Note', l.note, l.photo));
    }
    for (final t in tasks.where((t) => t.done && dayKey(DateTime.fromMillisecondsSinceEpoch(t.doneAt)) == day)) {
      ev.add(ReplayEvent(t.doneAt, 'task', 'Tâche faite', t.title));
    }
    ev.sort((a, b) => a.ts.compareTo(b.ts));
    return ev;
  }

  /// Répartition des activités du jour d'après les check-ins.
  Map<String, int> activityShare(String day) {
    final m = <String, int>{};
    for (final c in checkinsOn(day)) {
      if (c.activity.isEmpty) continue;
      m[c.activity] = (m[c.activity] ?? 0) + 1;
    }
    return m;
  }

  double focusMinutes(String day) =>
      sessionsOn(day).where((s) => !s.running).fold(0.0, (a, s) => a + s.actualMin);

  double? dayRatio(String day) {
    final s = sessionsOn(day).where((s) => s.ratio > 0).toList();
    if (s.isEmpty) return null;
    return s.map((x) => x.ratio).reduce((a, b) => a + b) / s.length;
  }

  // ---------- Découvertes ----------

  static const moodLabels = ['Très mal', 'Bof', 'Neutre', 'Bien', 'Super'];

  /// Part des check-ins « ma quête » par jour de semaine (lignes) et tranche de 2 h dès 8 h (colonnes).
  List<List<double?>> heatmap() {
    final hits = List.generate(7, (_) => List.filled(7, 0));
    final tot = List.generate(7, (_) => List.filled(7, 0));
    for (final c in _recentCheckins(42)) {
      if (c.activity.isEmpty) continue;
      final d = DateTime.fromMillisecondsSinceEpoch(c.ts);
      final col = (d.hour - 8) ~/ 2;
      if (col < 0 || col > 6) continue;
      tot[d.weekday - 1][col]++;
      if (c.activity == Act.quest) hits[d.weekday - 1][col]++;
    }
    return List.generate(
        7, (r) => List.generate(7, (c) => tot[r][c] == 0 ? null : hits[r][c] / tot[r][c]));
  }

  static const _days = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

  double _meanAbsErr(Iterable<SessionRec> s) {
    final l = s.toList();
    if (l.isEmpty) return 0;
    return l.map((x) => (x.ratio - 1).abs()).reduce((a, b) => a + b) / l.length;
  }

  List<Discovery> discoveries() {
    final out = <Discovery>[];
    final withAct = checkins.where((c) => c.activity.isNotEmpty).toList();

    // 1. Zone d'or : la tranche horaire la plus concentrée.
    {
      final byBlock = <int, List<int>>{};
      for (final c in withAct) {
        final h = DateTime.fromMillisecondsSinceEpoch(c.ts).hour;
        final b = (h ~/ 2) * 2;
        byBlock.putIfAbsent(b, () => [0, 0]);
        byBlock[b]![1]++;
        if (c.activity == Act.quest) byBlock[b]![0]++;
      }
      final ok = byBlock.entries.where((e) => e.value[1] >= 4).toList();
      if (ok.length >= 3) {
        ok.sort((a, b) => (b.value[0] / b.value[1]).compareTo(a.value[0] / a.value[1]));
        final b = ok.first;
        out.add(Discovery('gold', 'Ta zone d\'or',
            'Entre ${b.key} h et ${b.key + 2} h, tu es sur ta quête ${(100 * b.value[0] / b.value[1]).round()} % du temps.', 1, ''));
      } else {
        out.add(Discovery('gold', 'Ta zone d\'or', '', min(1.0, withAct.length / 30), 'environ 30 check-ins'));
      }
    }

    // 2. Multiplicateur de temps.
    {
      final s = sessions.where((x) => x.finished && x.ratio > 0).toList();
      if (s.length >= 5) {
        final r = s.map((x) => x.ratio).toList()..sort();
        final med = r[r.length ~/ 2];
        final txt = med > 1.1
            ? 'Une tâche te prend en général ×${med.toStringAsFixed(1).replaceAll('.', ',')} le temps prévu. Multiplie tes paris d\'autant.'
            : med < 0.9
                ? 'Tu finis souvent plus vite que prévu (×${med.toStringAsFixed(1).replaceAll('.', ',')}). Tu peux viser plus ambitieux.'
                : 'Tes paris sont justes : ton réel colle à ton prévu.';
        out.add(Discovery('mult', 'Ton multiplicateur de temps', txt, 1, ''));
      } else {
        out.add(Discovery('mult', 'Ton multiplicateur de temps', '', s.length / 5, '5 sessions terminées'));
      }
    }

    // 3. Déclencheur principal de décrochage.
    {
      final r = checkins.where((c) => c.reason.isNotEmpty).toList();
      if (r.length >= 6) {
        final count = <String, int>{};
        for (final c in r) {
          count[c.reason] = (count[c.reason] ?? 0) + 1;
        }
        final top = count.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        out.add(Discovery('why', 'Ton piège principal',
            '« ${top.first.key} » explique ${(100 * top.first.value / r.length).round()} % de tes décrochages.', 1, ''));
      } else {
        out.add(Discovery('why', 'Ton piège principal', '', r.length / 6, '6 décrochages expliqués'));
      }
    }

    // 4 et 5. Energy drinks et café.
    for (final kind in [LogKind.energy, LogKind.coffee]) {
      final name = kind == LogKind.energy ? 'Energy drinks' : 'Café';
      final drinks = logs.where((l) => l.kind == kind).map((l) => l.ts).toList();
      bool after(int ts) => drinks.any((d) => ts >= d && ts - d <= 3 * 3600 * 1000);
      final fin = sessions.where((x) => x.finished && x.ratio > 0).toList();
      final a = fin.where((x) => after(x.start)).toList();
      final b = fin.where((x) => !after(x.start)).toList();
      final ma = checkins.where((c) => c.mood > 0 && after(c.ts)).toList();
      final mb = checkins.where((c) => c.mood > 0 && !after(c.ts)).toList();
      if (drinks.length >= 4 && a.length >= 3 && b.length >= 3) {
        final ea = _meanAbsErr(a), eb = _meanAbsErr(b);
        final focusTxt = ea < eb - 0.1
            ? 'tes paris sont plus justes dans les 3 h qui suivent'
            : ea > eb + 0.1
                ? 'tes paris sont moins justes dans les 3 h qui suivent'
                : 'ça ne change pas la justesse de tes paris';
        var moodTxt = '';
        if (ma.length >= 3 && mb.length >= 3) {
          final xa = ma.map((c) => c.mood).reduce((x, y) => x + y) / ma.length;
          final xb = mb.map((c) => c.mood).reduce((x, y) => x + y) / mb.length;
          moodTxt = xa > xb + 0.3
              ? ', et ton humeur est meilleure'
              : xa < xb - 0.3
                  ? ', et ton humeur est plus basse'
                  : '';
        }
        out.add(Discovery(kind, '$name et focus', 'Après un ${name == 'Café' ? 'café' : 'energy drink'}, $focusTxt$moodTxt.', 1, ''));
      } else {
        final p = (min(drinks.length, 4) + min(a.length, 3) + min(b.length, 3)) / 10;
        out.add(Discovery(kind, '$name et focus', '', p, '4 prises et 3 sessions avec et sans'));
      }
    }

    // 6. Cycle et humeur.
    {
      if (settings.cycleStart.isEmpty) {
        out.add(const Discovery('cycle', 'Humeur et cycle', '', 0, 'la date de tes dernières règles (Réglages)'));
      } else {
        final by = <String, List<int>>{};
        for (final c in checkins.where((c) => c.mood > 0)) {
          final p = phaseOn(DateTime.fromMillisecondsSinceEpoch(c.ts));
          if (p == null) continue;
          by.putIfAbsent(p, () => []).add(c.mood);
        }
        final ok = by.entries.where((e) => e.value.length >= 4).toList();
        if (ok.length >= 3) {
          double mean(List<int> l) => l.reduce((a, b) => a + b) / l.length;
          ok.sort((a, b) => mean(b.value).compareTo(mean(a.value)));
          out.add(Discovery('cycle', 'Humeur et cycle',
              'Ton humeur est la plus haute en phase ${ok.first.key} et la plus basse en phase ${ok.last.key}.', 1, ''));
        } else {
          out.add(Discovery('cycle', 'Humeur et cycle', '', ok.length / 3, 'des check-ins dans 3 phases du cycle'));
        }
      }
    }

    // 7. Meilleur jour de la semaine.
    {
      final by = List.generate(7, (_) => [0, 0]);
      for (final c in withAct) {
        final w = DateTime.fromMillisecondsSinceEpoch(c.ts).weekday - 1;
        by[w][1]++;
        if (c.activity == Act.quest) by[w][0]++;
      }
      final ok = [for (var i = 0; i < 7; i++) if (by[i][1] >= 4) i];
      if (ok.length >= 4) {
        ok.sort((a, b) => (by[b][0] / by[b][1]).compareTo(by[a][0] / by[a][1]));
        out.add(Discovery('day', 'Ton jour le plus fort',
            'Le ${_days[ok.first]}, tu es le plus souvent sur tes quêtes ; le ${_days[ok.last]}, le moins.', 1, ''));
      } else {
        out.add(Discovery('day', 'Ton jour le plus fort', '', ok.length / 4, 'des check-ins sur 4 jours différents'));
      }
    }

    // 8. Sommeil et humeur.
    {
      final pts = <List<double>>[];
      for (final p in plans.values.where((p) => p.sleepH > 0)) {
        final moods = checkinsOn(p.day).where((c) => c.mood > 0).map((c) => c.mood).toList();
        if (moods.isEmpty) continue;
        pts.add([p.sleepH / 2, moods.reduce((a, b) => a + b) / moods.length]);
      }
      if (pts.length >= 7) {
        final short = pts.where((p) => p[0] < 7).toList();
        final long = pts.where((p) => p[0] >= 7).toList();
        if (short.isNotEmpty && long.isNotEmpty) {
          final ms = short.map((p) => p[1]).reduce((a, b) => a + b) / short.length;
          final ml = long.map((p) => p[1]).reduce((a, b) => a + b) / long.length;
          out.add(Discovery('sleep', 'Sommeil et humeur',
              ml > ms + 0.3
                  ? 'Les jours après 7 h de sommeil ou plus, ton humeur est nettement meilleure.'
                  : 'Ton humeur dépend peu de ton nombre d\'heures de sommeil.',
              1, ''));
        } else {
          out.add(Discovery('sleep', 'Sommeil et humeur', '', 0.8, 'des nuits courtes et des nuits longues'));
        }
      } else {
        out.add(Discovery('sleep', 'Sommeil et humeur', '', pts.length / 7, '7 matins avec ton sommeil noté'));
      }
    }
    return out;
  }

  // ---------- Notion ----------

  bool get notionReady => settings.notionToken.isNotEmpty && settings.notionDb.isNotEmpty;

  /// Ajoute la tâche au calendrier Notion. Renvoie un message d'erreur, ou null.
  Future<String?> sendToNotion(Task t, DateTime date) async {
    if (!notionReady) return 'Notion n\'est pas configuré (Réglages).';
    final db = settings.notionDb.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    final id = db.length >= 32 ? db.substring(db.length - 32) : db;
    try {
      final r = await http.post(
        Uri.parse('https://api.notion.com/v1/pages'),
        headers: {
          'Authorization': 'Bearer ${settings.notionToken.trim()}',
          'Notion-Version': '2022-06-28',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'parent': {'database_id': id},
          'properties': {
            settings.notionTitleProp: {
              'title': [
                {
                  'text': {'content': t.title}
                }
              ]
            },
            settings.notionDateProp: {
              'date': {'start': dayKey(date)}
            },
          },
        }),
      );
      if (r.statusCode >= 200 && r.statusCode < 300) {
        t.removed = true;
        await commit();
        return null;
      }
      String msg = 'erreur ${r.statusCode}';
      try {
        msg = (jsonDecode(r.body) as Map)['message']?.toString() ?? msg;
      } catch (_) {}
      return 'Notion : $msg';
    } catch (e) {
      return 'Notion injoignable : $e';
    }
  }

  Future<void> updateSettings() async => commit();
}
