import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const kStateKey = 'quest_state_v1';
const kPendingKey = 'pending_checkins_v1';
const kPendingHabitsKey = 'pending_habits_v1';
const kPendingRemindKey = 'pending_reminders_v1';

const xpPerLevel = 1000;

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
  List<Pause> pauses = [];
  List<NoteMeta> notes = [];
  List<Habit> habits = [];
  List<HabitLog> habitLogs = [];
  List<Reflection> reflections = [];
  List<Expense> expenses = [];
  List<Remind> reminders = [];
  List<Placement> placements = [];
  List<Slot> slots = [];
  List<CabinVisit> cabin = [];
  Settings settings = Settings();
  String lastChest = '';

  /// Appelé quand le planning change (blocs écrits dans l'agenda du téléphone).
  Future<void> Function(AppStore)? onPlanChanged;
  Future<void> _planChanged() async {
    try {
      await onPlanChanged?.call(this);
    } catch (_) {}
  }

  /// Après une session ou une tâche faite, on pose la question « et maintenant ? » dans l'appli :
  /// pas de check-in avant ce moment.
  int skipCheckinsUntil = 0;

  void skipCheckins({int minutes = 20}) =>
      skipCheckinsUntil = DateTime.now().add(Duration(minutes: minutes)).millisecondsSinceEpoch;

  bool skippedAt(DateTime t) => t.millisecondsSinceEpoch < skipCheckinsUntil;

  /// Empreinte de chaque enregistrement au dernier enregistrement (pour dater les modifications).
  final Map<String, String> _seen = {};

  int get xp => xpEvents.fold(0, (a, e) => a + e.amount);
  int get jokers => 1 + xpEvents.where((e) => e.reason == 'Joker').length;

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
        pauses = list('pauses').map(Pause.fromJson).toList();
        notes = list('notes').map(NoteMeta.fromJson).toList();
        habits = list('habits').map(Habit.fromJson).toList();
        habitLogs = list('habitLogs').map(HabitLog.fromJson).toList();
        reflections = list('reflections').map(Reflection.fromJson).toList();
        expenses = list('expenses').map(Expense.fromJson).toList();
        reminders = list('reminders').map(Remind.fromJson).toList();
        placements = list('placements').map(Placement.fromJson).toList();
        slots = list('slots').map(Slot.fromJson).toList();
        cabin = list('cabin').map(CabinVisit.fromJson).toList();
        settings = Settings.fromJson(Map<String, dynamic>.from((j['settings'] as Map?) ?? {}));
        lastChest = (j['lastChest'] as String?) ?? '';
      } catch (e) {
        debugPrint('État illisible : $e');
      }
    }
    if (habits.isEmpty && !(_prefs.getBool('habits_seeded') ?? false)) {
      habits.add(Habit(
        name: 'Kannada',
        cue: 'Après mon petit-déjeuner',
        mini: '2 minutes : revoir 3 mots',
        color: 0xFF4FE3FF,
        created: todayKey,
      ));
      await _prefs.setBool('habits_seeded', true);
    }
    _fixLateEvenings();
    _seedBooks();
    _stamp(init: true);
    _rollOver();
    _checkBudgetDays();
    await mergePending(notify: false);
    notifyListeners();
  }

  /// Toutes les collections synchronisables, par type puis par identifiant.
  Map<String, Map<String, Map<String, dynamic>>> records() => {
        'tasks': {for (final e in tasks) e.id: e.toJson()},
        'sessions': {for (final e in sessions) e.id: e.toJson()},
        'checkins': {for (final e in checkins) e.id: e.toJson()},
        'logs': {for (final e in logs) e.id: e.toJson()},
        'plans': {for (final e in plans.values) e.day: e.toJson()},
        'pauses': {for (final e in pauses) e.id: e.toJson()},
        'notes': {for (final e in notes) e.id: e.toJson()},
        'habits': {for (final e in habits) e.id: e.toJson()},
        'habitLogs': {for (final e in habitLogs) e.id: e.toJson()},
        'reflections': {for (final e in reflections) e.id: e.toJson()},
        'expenses': {for (final e in expenses) e.id: e.toJson()},
        'reminders': {for (final e in reminders) e.id: e.toJson()},
        'placements': {for (final e in placements) e.id: e.toJson()},
        'slots': {for (final e in slots) e.id: e.toJson()},
        'cabin': {for (final e in cabin) e.id: e.toJson()},
      };

  /// Date les enregistrements qui ont changé depuis la dernière fois.
  void _stamp({bool init = false}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    void check(String kind, String id, Map<String, dynamic> json, void Function(int) setMod) {
      final copy = Map<String, dynamic>.from(json)..remove('mod');
      final sig = jsonEncode(copy);
      final key = '$kind:$id';
      if (!init && _seen[key] != sig) setMod(now);
      if (init && (json['mod'] ?? 0) == 0) setMod(now);
      _seen[key] = sig;
    }

    for (final e in tasks) {
      check('tasks', e.id, e.toJson(), (m) => e.mod = m);
    }
    for (final e in sessions) {
      check('sessions', e.id, e.toJson(), (m) => e.mod = m);
    }
    for (final e in checkins) {
      check('checkins', e.id, e.toJson(), (m) => e.mod = m);
    }
    for (final e in logs) {
      check('logs', e.id, e.toJson(), (m) => e.mod = m);
    }
    for (final e in plans.values) {
      check('plans', e.day, e.toJson(), (m) => e.mod = m);
    }
    for (final e in pauses) {
      check('pauses', e.id, e.toJson(), (m) => e.mod = m);
    }
    for (final e in notes) {
      check('notes', e.id, e.toJson(), (m) => e.mod = m);
    }
    for (final e in habits) {
      check('habits', e.id, e.toJson(), (m) => e.mod = m);
    }
    for (final e in habitLogs) {
      check('habitLogs', e.id, e.toJson(), (m) => e.mod = m);
    }
    for (final e in reflections) {
      check('reflections', e.id, e.toJson(), (m) => e.mod = m);
    }
    for (final e in expenses) {
      check('expenses', e.id, e.toJson(), (m) => e.mod = m);
    }
    for (final e in reminders) {
      check('reminders', e.id, e.toJson(), (m) => e.mod = m);
    }
    for (final e in placements) {
      check('placements', e.id, e.toJson(), (m) => e.mod = m);
    }
    for (final e in slots) {
      check('slots', e.id, e.toJson(), (m) => e.mod = m);
    }
    for (final e in cabin) {
      check('cabin', e.id, e.toJson(), (m) => e.mod = m);
    }
  }

  /// Contenu partagé entre appareils (sans les réglages propres à l'appareil).
  Map<String, dynamic> syncPayload() {
    final r = records();
    return {
      'v': 1,
      for (final e in r.entries) e.key: e.value.values.toList(),
      'xpEvents': xpEvents.map((e) => e.toJson()).toList(),
      'inventory': inventory,
      'cycle': {'start': settings.cycleStart, 'len': settings.cycleLength},
      'cabinPrefs': {
        'books': settings.books,
        'library': settings.library,
        'contacts': settings.contacts,
        'favAngles': settings.favAngles,
        'letter': settings.goodDaysLetter,
      },
    };
  }

  /// Fusionne le contenu d'un autre appareil : le plus récent gagne, rien ne se perd.
  Future<void> mergeRemote(Map<String, dynamic> remote) async {
    List<Map<String, dynamic>> list(String k) =>
        ((remote[k] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    void mergeInto<T>(List<T> local, List<Map<String, dynamic>> incoming, String Function(T) idOf,
        String Function(Map<String, dynamic>) idOfJson, int Function(T) modOf, T Function(Map<String, dynamic>) make) {
      final index = {for (var i = 0; i < local.length; i++) idOf(local[i]): i};
      for (final j in incoming) {
        final id = idOfJson(j);
        final m = (j['mod'] as num?)?.toInt() ?? 0;
        final i = index[id];
        if (i == null) {
          local.add(make(j));
          index[id] = local.length - 1;
        } else if (m > modOf(local[i])) {
          local[i] = make(j);
        }
      }
    }

    mergeInto<Task>(tasks, list('tasks'), (e) => e.id, (j) => j['id'] as String, (e) => e.mod, Task.fromJson);
    mergeInto<SessionRec>(
        sessions, list('sessions'), (e) => e.id, (j) => j['id'] as String, (e) => e.mod, SessionRec.fromJson);
    mergeInto<CheckIn>(checkins, list('checkins'), (e) => e.id, (j) => '${j['ts']}', (e) => e.mod, CheckIn.fromJson);
    mergeInto<LogEntry>(logs, list('logs'), (e) => e.id, (j) => j['id'] as String, (e) => e.mod, LogEntry.fromJson);
    mergeInto<Pause>(pauses, list('pauses'), (e) => e.id, (j) => j['id'] as String, (e) => e.mod, Pause.fromJson);
    mergeInto<NoteMeta>(notes, list('notes'), (e) => e.id, (j) => j['id'] as String, (e) => e.mod, NoteMeta.fromJson);
    mergeInto<Habit>(habits, list('habits'), (e) => e.id, (j) => j['id'] as String, (e) => e.mod, Habit.fromJson);
    mergeInto<HabitLog>(
        habitLogs, list('habitLogs'), (e) => e.id, (j) => '${j['habit']}|${j['day']}', (e) => e.mod, HabitLog.fromJson);
    mergeInto<Reflection>(
        reflections, list('reflections'), (e) => e.id, (j) => j['id'] as String, (e) => e.mod, Reflection.fromJson);
    mergeInto<Expense>(expenses, list('expenses'), (e) => e.id, (j) => j['id'] as String, (e) => e.mod, Expense.fromJson);
    mergeInto<Remind>(reminders, list('reminders'), (e) => e.id, (j) => j['id'] as String, (e) => e.mod, Remind.fromJson);
    mergeInto<Placement>(placements, list('placements'), (e) => e.id, (j) => j['id'] as String, (e) => e.mod, Placement.fromJson);
    mergeInto<Slot>(slots, list('slots'), (e) => e.id, (j) => j['id'] as String, (e) => e.mod, Slot.fromJson);
    mergeInto<CabinVisit>(cabin, list('cabin'), (e) => e.id, (j) => j['id'] as String, (e) => e.mod, CabinVisit.fromJson);
    for (final j in list('plans')) {
      final d = j['day'] as String;
      final m = (j['mod'] as num?)?.toInt() ?? 0;
      final cur = plans[d];
      if (cur == null || m > cur.mod) plans[d] = DayPlan.fromJson(j);
    }
    final ids = xpEvents.map((e) => e.id).toSet();
    for (final j in list('xpEvents')) {
      final e = XpEvent.fromJson(j);
      if (ids.add(e.id)) xpEvents.add(e);
    }
    xpEvents.sort((a, b) => a.ts.compareTo(b.ts));
    for (final it in ((remote['inventory'] as List?) ?? []).map((e) => e.toString())) {
      if (!inventory.contains(it)) inventory.add(it);
    }
    final cp = remote['cabinPrefs'] as Map?;
    if (cp != null) {
      void union(List<String> mine, Object? theirs) {
        for (final x in ((theirs as List?) ?? []).map((e) => e.toString())) {
          if (!mine.contains(x)) mine.add(x);
        }
      }

      union(settings.books, cp['books']);
      union(settings.library, cp['library']);
      union(settings.contacts, cp['contacts']);
      union(settings.favAngles, cp['favAngles']);
      final l = (cp['letter'] as String?) ?? '';
      if (settings.goodDaysLetter.isEmpty && l.isNotEmpty) settings.goodDaysLetter = l;
    }
    final cyc = remote['cycle'] as Map?;
    if (cyc != null && settings.cycleStart.isEmpty && (cyc['start'] as String? ?? '').isNotEmpty) {
      settings.cycleStart = cyc['start'] as String;
      settings.cycleLength = (cyc['len'] as num?)?.toInt() ?? 28;
    } else if (cyc != null && (cyc['start'] as String? ?? '').compareTo(settings.cycleStart) > 0) {
      settings.cycleStart = cyc['start'] as String;
      settings.cycleLength = (cyc['len'] as num?)?.toInt() ?? settings.cycleLength;
    }
    checkins.sort((a, b) => a.ts.compareTo(b.ts));
    // les copies reçues gardent leur date de modification
    _stamp(init: true);
    _rollOver();
    await save(stamp: false);
    notifyListeners();
  }

  Future<void> save({bool stamp = true}) async {
    if (stamp) _stamp();
    final j = {
      'tasks': tasks.map((e) => e.toJson()).toList(),
      'sessions': sessions.map((e) => e.toJson()).toList(),
      'checkins': checkins.map((e) => e.toJson()).toList(),
      'logs': logs.map((e) => e.toJson()).toList(),
      'xpEvents': xpEvents.map((e) => e.toJson()).toList(),
      'plans': plans.values.map((e) => e.toJson()).toList(),
      'inventory': inventory,
      'pauses': pauses.map((e) => e.toJson()).toList(),
      'notes': notes.map((e) => e.toJson()).toList(),
      'habits': habits.map((e) => e.toJson()).toList(),
      'habitLogs': habitLogs.map((e) => e.toJson()).toList(),
      'reflections': reflections.map((e) => e.toJson()).toList(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
      'reminders': reminders.map((e) => e.toJson()).toList(),
      'placements': placements.map((e) => e.toJson()).toList(),
      'slots': slots.map((e) => e.toJson()).toList(),
      'cabin': cabin.map((e) => e.toJson()).toList(),
      'settings': settings.toJson(),
      'lastChest': lastChest,
    };
    await _prefs.setString(kStateKey, jsonEncode(j));
  }

  static String _s(Object? v) => (v as String?) ?? '';

  Future<void> commit() async {
    await save();
    notifyListeners();
  }

  void refresh() => notifyListeners();

  /// Les tâches d'un jour passé non rangées reviennent à trier aujourd'hui.
  void _rollOver() {
    final today = todayKey;
    // boss d'avant la règle « 1 PV = 1 minute » : on repart des minutes estimées s'il n'a pas encore été attaqué
    for (final t in tasks) {
      if (t.isBoss && !t.done && t.bossHp == 100 && !sessions.any((s) => s.taskId == t.id)) t.bossHp = bossTotal(t);
    }
    for (final t in tasks) {
      if (!t.done && !t.removed && t.day.compareTo(today) < 0) {
        t.day = today;
        t.deferred = true;
        t.plannedAt = 0;
      }
    }
  }

  /// Réponses données depuis les notifications (appli fermée).
  Future<void> mergePending({bool notify = true}) async {
    await _prefs.reload();
    final hl = _prefs.getStringList(kPendingHabitsKey) ?? [];
    if (hl.isNotEmpty) {
      await _prefs.setStringList(kPendingHabitsKey, []);
      for (final raw in hl) {
        try {
          final m = jsonDecode(raw) as Map<String, dynamic>;
          for (final h in habits) {
            if (h.id == m['habit']) {
              await cycleHabit(h, day: m['day'] as String?, to: (m['level'] as num).toInt());
            }
          }
        } catch (_) {}
      }
    }
    final rl = _prefs.getStringList(kPendingRemindKey) ?? [];
    if (rl.isNotEmpty) {
      await _prefs.setStringList(kPendingRemindKey, []);
      for (final raw in rl) {
        try {
          final m = jsonDecode(raw) as Map<String, dynamic>;
          final t = taskById(_s(m['task']));
          if (t == null) continue;
          final mins = (m['snooze'] as num?)?.toInt() ?? 0;
          if (mins > 0) {
            await postpone(t, minutes: mins, at: (m['ts'] as num?)?.toInt(), save: false);
          }
        } catch (_) {}
      }
      await save();
    }
    final list = _prefs.getStringList(kPendingKey) ?? [];
    if (list.isEmpty) {
      if ((hl.isNotEmpty || rl.isNotEmpty) && notify) notifyListeners();
      return;
    }
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
          _gainXp(1, 'Check-in');
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
    // horodatage unique : sert d'identifiant pour la synchronisation
    var ts = DateTime.now().millisecondsSinceEpoch;
    if (xpEvents.isNotEmpty && ts <= xpEvents.last.ts) ts = xpEvents.last.ts + 1;
    xpEvents.add(XpEvent(ts: ts, amount: amount, reason: reason));
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
    // une journée en pause (cours, sortie…) ne casse jamais la série
    for (final p in pauses) {
      final end = p.end == 0 ? DateTime.now().millisecondsSinceEpoch : p.end;
      for (var t = p.start; t <= end; t += 6 * 3600 * 1000) {
        s.add(dayKey(DateTime.fromMillisecondsSinceEpoch(t)));
      }
      s.add(dayKey(DateTime.fromMillisecondsSinceEpoch(end)));
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

  /// Focus : minutes de vrai focus (sessions pro, débrief sans interruption) sur 7 jours,
  /// rapportées à l'objectif pro du jour (3 h par défaut).
  int get statFocus {
    var total = 0.0;
    var goal = 0.0;
    for (var i = 0; i < 7; i++) {
      final d = dayKey(DateTime.now().subtract(Duration(days: i)));
      total += focusMinutes(d);
      final g = plans[d]?.proGoalMin ?? 0;
      goal += g > 0 ? g : 180;
    }
    if (goal == 0) return 0;
    return min(20, (20 * total / goal).round());
  }

  int get statTime {
    final from = DateTime.now().subtract(const Duration(days: 14)).millisecondsSinceEpoch;
    final s = sessions.where((x) => x.finished && x.start >= from && x.ratio > 0).toList();
    if (s.isEmpty) return 0;
    final err = s.map((x) => (log(x.ratio)).abs()).reduce((a, b) => a + b) / s.length;
    return (20 * (1 - min(1.0, err))).round();
  }

  /// Constance : sur 10 jours, un point par jour avec une tâche pro faite, un point pour les habitudes.
  int get statConstancy {
    var pts = 0.0;
    for (var i = 0; i < 10; i++) {
      final d = dayKey(DateTime.now().subtract(Duration(days: i)));
      if (tasks.any((t) => t.done && t.category != 'perso' && dayKey(DateTime.fromMillisecondsSinceEpoch(t.doneAt)) == d)) {
        pts += 1;
      }
      final hs = activeHabits;
      if (hs.isNotEmpty) {
        final done = hs.where((h) => habitLevel(h, d) > 0).length;
        pts += done == hs.length ? 1 : (done > 0 ? 0.5 : 0);
      }
    }
    return min(20, pts.round());
  }

  /// Sérénité : elle se gagne par des gestes de régulation, elle ne baisse jamais parce qu'on va mal.
  int get statSerenity {
    final from = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    var pts = 0.0;
    for (final e in xpEvents.where((e) => e.ts >= from)) {
      if (e.reason == 'Réflexion') pts += 2;
      if (e.reason.startsWith('Sérénité')) pts += 2;
      if (e.reason == 'Ruban') pts += 3;
      if (e.reason == 'Auto-évaluation') pts += 0.5;
    }
    for (final p in pauses.where((p) => p.start >= from)) {
      pts += p.label == 'Repos' ? 1 : 0.5;
    }
    return min(20, pts.round());
  }

  /// Un geste de régulation (respiration, porte, exercice…) : compte pour la Sérénité.
  Future<void> noteSerenity(String what) async {
    _gainXp(0, 'Sérénité : $what');
    logs.add(LogEntry(ts: DateTime.now().millisecondsSinceEpoch, kind: LogKind.calm, note: what));
    await commit();
  }

  // ---------- Objectifs du jour et médailles ----------

  /// Minutes pro d'un jour (sessions et check-ins).
  double proMinutesOn(String day) => minutesByCategory(day)[Act.pro] ?? 0;

  /// Moyenne de minutes pro par jour sur les N derniers jours (hors aujourd'hui).
  double avgProMinutes(int days) {
    var t = 0.0;
    for (var i = 1; i <= days; i++) {
      t += proMinutesOn(dayKey(DateTime.now().subtract(Duration(days: i))));
    }
    return t / days;
  }

  /// 0 rien · 1 bronze (1 h de pro) · 2 argent (objectif pro) · 3 or (pro + perso) · 4 couronne (tout, habitudes comprises).
  int medalOn(String day) {
    final p = plans[day];
    final pro = proMinutesOn(day);
    var m = pro >= 60 ? 1 : 0;
    final goal = p?.proGoalMin ?? 0;
    if (goal > 0 && pro >= goal) m = 2;
    if (m == 2 && (p?.persoGoal.isNotEmpty ?? false) && (p?.persoGoalDone ?? false)) m = 3;
    if (m == 3) {
      final todays = tasks.where((t) => t.day == day && !t.removed).toList();
      final hs = activeHabits;
      if (todays.length >= 3 && todays.every((t) => t.done) && hs.isNotEmpty && hs.every((h) => habitLevel(h, day) > 0)) m = 4;
    }
    return m;
  }

  static const medalNames = ['', 'Bronze', 'Argent', 'Or', 'Couronne'];

  /// Attribue les récompenses de médaille du jour (une seule fois chacune).
  void _checkMedals() {
    final m = medalOn(todayKey);
    final msgs = <String>[];
    if (m >= 2 && !_claimedToday('Médaille d\'argent')) {
      _gainXp(60, 'Médaille d\'argent');
      msgs.add('MÉDAILLE D\'ARGENT · objectif pro atteint !\n+60 XP');
    }
    if (m >= 3 && !_claimedToday('Médaille d\'or')) {
      _gainXp(40, 'Médaille d\'or');
      msgs.add('MÉDAILLE D\'OR · objectifs pro et perso !\n+40 XP');
    }
    if (msgs.isNotEmpty) pendingCelebration = [if (pendingCelebration != null) pendingCelebration!, ...msgs].join('\n\n');
  }

  Future<void> setDayGoals({int? proGoalMin, String? persoGoal}) async {
    if (proGoalMin != null) today.proGoalMin = proGoalMin;
    if (persoGoal != null) today.persoGoal = persoGoal.trim();
    await commit();
  }

  /// L'objectif perso est fait : un ruban pour Micky, de la Sérénité, pas d'XP.
  Future<void> setPersoGoalDone(bool done) async {
    today.persoGoalDone = done;
    if (done && !_claimedToday('Ruban')) _gainXp(0, 'Ruban');
    _checkMedals();
    _checkBigBonuses();
    await commit();
  }

  /// Minutes de focus (sessions pro) d'un jour, pondérées par le débrief.
  double focusMinutes(String day) => sessionsOn(day)
      .where((s) => !s.running && sessionCategory(s) == Act.pro)
      .fold(0.0, (a, s) => a + s.focusMin);

  // ---------- Plans du jour ----------

  DayPlan plan(String day) => plans.putIfAbsent(day, () => DayPlan(day: day));
  DayPlan get today => plan(todayKey);

  Future<void> finishBriefing() async {
    if (!today.briefingDone) {
      today.briefingDone = true;
      _gainXp(10, 'Briefing du matin');
    }
    await commit();
  }

  /// Le feu de camp d'après minuit (avant 5 h) compte pour la veille.
  String get eveningKey {
    final now = DateTime.now();
    return now.hour < 5 ? dayKey(now.subtract(const Duration(days: 1))) : todayKey;
  }

  DayPlan get evening => plan(eveningKey);

  Future<String> finishEvening() async {
    var chest = '';
    final p = evening;
    if (!p.eveningDone) {
      p.eveningDone = true;
      final reason = 'Feu de camp · ${p.day}';
      if (!xpEvents.any((e) => e.reason == reason)) {
        _gainXp(10, reason);
        chest = _openChest();
      }
      _selfBonuses(p.day);
    }
    await commit();
    return chest;
  }

  /// Rouvrir un feu de camp clos par erreur (pas de double XP).
  Future<void> reopenEvening(String day) async {
    plan(day).eveningDone = false;
    await commit();
  }

  /// Feux de camp validés après minuit avant ce correctif : on les rend à la veille.
  void _fixLateEvenings() {
    for (final e in xpEvents) {
      if (e.reason != 'Feu de camp') continue;
      final d = DateTime.fromMillisecondsSinceEpoch(e.ts);
      if (d.hour >= 5) {
        e.reason = 'Feu de camp · ${dayKey(d)}';
        continue;
      }
      final wrong = dayKey(d), right = dayKey(d.subtract(const Duration(days: 1)));
      e.reason = 'Feu de camp · $right';
      final pw = plans[wrong];
      if (pw != null && pw.eveningDone) {
        pw.eveningDone = false;
        plan(right).eveningDone = true;
      }
    }
  }

  // ---------- Tâches ----------

  List<Task> get openTasks {
    final t = tasks.where((t) => !t.done && !t.removed && t.day.compareTo(todayKey) <= 0).toList();
    t.sort((a, b) => a.order.compareTo(b.order));
    return t;
  }

  List<Task> tasksIn(String quad) => openTasks.where((t) => t.quad == quad).toList();

  List<Task> questSteps(String category) =>
      tasks.where((t) => t.inQuest && t.category == category && t.day == todayKey && !t.removed).toList()
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

  Future<Task> addTask(String title, {String category = '', int estimate = 0, String quad = Quad.inbox, bool? inQuest}) async {
    final q = inQuest ?? category.isNotEmpty;
    final t = Task(
      title: title.trim(),
      category: category,
      estimateMin: estimate,
      quad: q && quad == Quad.inbox ? Quad.doNow : quad,
      day: todayKey,
      order: q ? questSteps(category).length : tasks.length,
      inQuest: q && category.isNotEmpty,
    );
    tasks.add(t);
    await commit();
    return t;
  }

  /// Réordonne les étapes d'une quête.
  Future<void> reorderSteps(String category, int oldIndex, int newIndex) async {
    final steps = questSteps(category);
    if (oldIndex < 0 || oldIndex >= steps.length) return;
    final moved = steps.removeAt(oldIndex);
    steps.insert(newIndex.clamp(0, steps.length), moved);
    for (var i = 0; i < steps.length; i++) {
      steps[i].order = i;
    }
    await commit();
  }

  /// Change le titre, le pari ou la quête d'une tâche.
  Future<void> editTask(Task t, {String? title, int? estimate, String? category, bool? inQuest}) async {
    if (title != null && title.trim().isNotEmpty) t.title = title.trim();
    if (estimate != null) t.estimateMin = estimate;
    if (category != null) {
      t.category = category;
      if (category.isEmpty) t.inQuest = false;
    }
    if (inQuest != null && t.category.isNotEmpty) {
      t.inQuest = inQuest;
      if (inQuest) {
        t.day = todayKey;
        if (t.quad == Quad.inbox) t.quad = Quad.doNow;
        t.order = questSteps(t.category).length;
      }
    }
    await commit();
  }

  /// « Pas aujourd'hui » : la tâche ne sera plus proposée dans « À caser » avant demain.
  Future<void> hideToday(Task t) async {
    t.hiddenDay = todayKey;
    await commit();
  }

  /// Tâches de Planifier sans heure (ou conditionnelles), à proposer dans Aujourd'hui.
  List<Task> get toPlaceToday => tasks
      .where((t) => !t.done && !t.removed && t.quad == Quad.plan && t.plannedAt == 0 && t.hiddenDay != todayKey && !t.inQuest)
      .toList()
    ..sort((a, b) => a.createdDay.compareTo(b.createdDay));

  /// Toutes les étapes faites : on clôt la quête (+15 XP, une fois par jour et par quête).
  Future<bool> closeQuest(String category) async {
    final reason = 'Quête ${category == 'pro' ? 'pro' : 'perso'} close';
    if (_claimedToday(reason)) return false;
    _gainXp(category == 'pro' ? 15 : 5, reason);
    await commit();
    return true;
  }

  Future<void> setQuestTitle(String category, String title) async {
    if (category == 'pro') {
      today.pro = title.trim();
    } else {
      today.perso = title.trim();
    }
    await commit();
  }

  /// Vrai si la tâche fait partie d'Aujourd'hui (quête, Faire maintenant, heure aujourd'hui, reportée, boss).
  bool inToday(Task t) =>
      !t.done && !t.removed && t.day.compareTo(todayKey) <= 0 &&
      (t.inQuest || t.quad == Quad.doNow || t.deferred || t.isBoss ||
          (t.plannedAt > 0 && dayKey(DateTime.fromMillisecondsSinceEpoch(t.plannedAt)) == todayKey));

  Future<void> moveTask(Task t, String quad) async {
    t.quad = quad;
    await commit();
  }

  static const _quadXp = {Quad.doNow: 20, Quad.plan: 20, Quad.light: 5, Quad.drop: 2, Quad.inbox: 5};

  /// XP d'une tâche faite : le pro rapporte, le perso très peu.
  int taskXp(Task t) => t.category == 'perso' ? 2 : (_quadXp[t.quad] ?? 5);

  Future<void> completeTask(Task t) async {
    if (t.done) {
      // décocher (ou « Annuler ») reprend l'XP gagnée aujourd'hui
      if (t.doneAt > 0 && dayKey(DateTime.fromMillisecondsSinceEpoch(t.doneAt)) == todayKey) _gainXp(-taskXp(t), 'Tâche décochée');
      t.done = false;
      t.doneAt = 0;
    } else {
      t.done = true;
      t.doneAt = DateTime.now().millisecondsSinceEpoch;
      _gainXp(taskXp(t), 'Tâche faite');
      _checkBigBonuses();
      _checkMedals();
    }
    await commit();
    if (t.calEventId.isNotEmpty) await _planChanged();
  }

  Future<void> deferTask(Task t) async {
    t.day = tomorrowKey;
    t.deferred = true;
    t.plannedAt = 0;
    await commit();
    await _planChanged();
  }

  Future<void> removeTask(Task t) async {
    t.removed = true;
    await commit();
    if (t.calEventId.isNotEmpty) await _planChanged();
  }

  /// Points de vie du boss = minutes de travail estimées (5 h si rien n'est précisé).
  int bossTotal(Task t) => t.estimateMin > 0 ? max(60, t.estimateMin) : 300;

  Future<void> setBoss(Task t) async {
    for (final x in tasks) {
      x.isBoss = false;
    }
    t.isBoss = true;
    t.bossHp = bossTotal(t);
    t.bossProgress = 0;
    await commit();
  }

  /// Sessions passées sur le boss (ses coups), les plus anciennes d'abord.
  List<SessionRec> bossHits(Task boss) =>
      sessions.where((s) => s.taskId == boss.id && !s.running).toList()..sort((a, b) => a.start.compareTo(b.start));

  int bossMinutes(Task boss) => bossHits(boss).fold(0, (a, s) => a + s.actualMin.round());

  /// Avancement déclaré sur le boss ; à 100 il est vaincu (+300 XP, objet épique).
  Future<void> setBossProgress(Task t, int progress) async {
    t.bossProgress = progress.clamp(0, 100);
    if (t.bossProgress >= 100 && !t.done) {
      t.done = true;
      t.doneAt = DateTime.now().millisecondsSinceEpoch;
      t.bossHp = 0;
      _gainXp(300, 'Boss vaincu');
      final epic = Objects.all.where((o) => o.rarity == 3 && !inventory.contains(o.id)).toList();
      if (epic.isNotEmpty) {
        final obj = epic[Random().nextInt(epic.length)];
        inventory.add(obj.id);
        lastObject = obj.id;
        _gainXp(0, 'Butin : ${obj.name}');
      }
      pendingCelebration = 'BOSS VAINCU · ${t.title}\n+300 XP';
      _checkBigBonuses();
      _checkMedals();
    }
    await commit();
  }

  List<Task> get unfinishedToday => tasks
      .where((t) => !t.done && !t.removed && t.day == todayKey)
      .toList();

  List<Task> get deferredToday => tasks.where((t) => t.deferred && !t.done && !t.removed && t.day == todayKey).toList();

  /// Heure du premier moment de travail pro du jour (session ou check-in), ou null.
  DateTime? workStart(String day) {
    int? best;
    for (final x in sessionsOn(day)) {
      if (sessionCategory(x) == Act.pro && (best == null || x.start < best)) best = x.start;
    }
    for (final c in checkinsOn(day)) {
      if (categoryOf(c) != Act.pro) continue;
      final t = c.ts - (c.sinceMin >= 0 ? c.sinceMin : min(settings.intervalMin, 30)) * 60000;
      if (best == null || t < best) best = t;
    }
    return best == null ? null : DateTime.fromMillisecondsSinceEpoch(best);
  }

  /// Minutes passées à se préparer (check-ins et sessions « Se préparer »).
  double prepMinutes(String day) => minutesByTask(day)['label:Se préparer'] ?? 0;

  /// Ajoute un projet perso précisé dans un check-in, réutilisable ensuite.
  Future<void> addProject(String name) async {
    final n = name.trim();
    if (n.isEmpty || settings.projects.contains(n)) return;
    settings.projects.add(n);
    await commit();
  }

  /// Une étape pro précisée au check-in : elle rejoint le briefing du jour (+2 XP).
  Future<Task> addStepFromCheckin(String title) async {
    for (final t in questSteps('pro')) {
      if (t.title.toLowerCase() == title.trim().toLowerCase()) return t;
    }
    final t = await addTask(title, category: 'pro', quad: Quad.doNow);
    _gainXp(2, 'Étape précisée');
    await commit();
    return t;
  }

  // ---------- La cabane ----------

  /// La pile de livres inspirants, prête au premier lancement (pages approximatives, modifiables).
  void _seedBooks() {
    if (_prefs.getBool('books_seeded') ?? false) return;
    if (settings.books.isEmpty) {
      settings.books.addAll(const [
        'L\'Éthique, Spinoza|380',
        'Ainsi parlait Zarathoustra, Nietzsche|470',
        'Crépuscule des idoles, Ecce Homo… (Œuvres VIII), Nietzsche|450',
        'Nietzsche, la passion des sommets, Annick Stevens|200',
        'Le Miracle Spinoza, Frédéric Lenoir|230',
        'Le Problème Spinoza, Irvin Yalom|500',
        'Thérapie existentielle, Irvin Yalom|700',
        'Le Jardin d\'Épicure, Irvin Yalom|300',
        'Le Bourreau de l\'amour, Irvin Yalom|400',
        'La Malédiction du chat hongrois, Irvin Yalom|500',
        'La Mort d\'Ivan Ilitch, Tolstoï|120',
        'Fables, La Fontaine|600',
        'Cerveau & méditation, Matthieu Ricard et Wolf Singer|400',
        'Plaidoyer pour l\'altruisme, Matthieu Ricard|900',
        'Flow, Mihaly Csikszentmihalyi|300',
        'Stolen Focus, Johann Hari|350',
        'Chemins spirituels, Matthieu Ricard|400',
        'L\'Art de la méditation, Matthieu Ricard|180',
        'Le Cœur des enseignements du Bouddha, Thich Nhat Hanh|300',
      ]);
    }
    _prefs.setBool('books_seeded', true);
  }

  Future<void> saveCabinVisit(CabinVisit v) async {
    if (!cabin.contains(v)) {
      cabin.add(v);
      _gainXp(0, 'Sérénité : cabane');
    }
    await commit();
  }

  /// Baisse moyenne d'intensité par angle (au moins 2 passages).
  Map<String, double> angleEfficacy() {
    final by = <String, List<int>>{};
    for (final v in cabin) {
      if (v.angle.isEmpty || v.before < 0 || v.after < 0) continue;
      by.putIfAbsent(v.angle, () => []).add(v.before - v.after);
    }
    return {
      for (final e in by.entries)
        if (e.value.length >= 2) e.key: e.value.reduce((a, b) => a + b) / e.value.length
    };
  }

  /// Plusieurs passages intenses ces 3 derniers jours.
  bool get cabinHeavy {
    final from = DateTime.now().subtract(const Duration(days: 3)).millisecondsSinceEpoch;
    return cabin.where((v) => v.ts >= from && v.before >= 7).length >= 3;
  }

  // ---------- Créneaux notés après coup ----------

  List<Slot> slotsOn(String day) => slots
      .where((x) => !x.removed && dayKey(DateTime.fromMillisecondsSinceEpoch(x.start)) == day)
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  static String _hm(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.hour}h${d.minute.toString().padLeft(2, '0')}';
  }

  bool _inSlot(int ts) => slots.any((x) => !x.removed && ts > x.start && ts <= x.end);

  /// Noter un créneau honnêtement rapporte +1 XP, quel qu'il soit.
  Future<void> saveSlot(Slot x) async {
    if (!slots.contains(x)) {
      slots.add(x);
      _gainXp(1, 'Créneau noté');
    }
    await commit();
  }

  Future<void> removeSlot(Slot x) async {
    x.removed = true;
    await commit();
  }

  /// « Accepter » : un geste de régulation, compté en Sérénité.
  Future<void> acceptSlot({int lowerGoalBy = 0}) async {
    if (lowerGoalBy > 0 && today.proGoalMin > 0) today.proGoalMin = max(30, today.proGoalMin - lowerGoalBy);
    _gainXp(0, 'Sérénité : accepter');
    await commit();
  }

  // ---------- Timetable et rappels ----------

  /// Tâches placées dans la journée (bloc prévu), triées par heure.
  List<Task> plannedOn(String day) =>
      tasks.where((t) => !t.removed && t.plannedAt > 0 && dayKey(DateTime.fromMillisecondsSinceEpoch(t.plannedAt)) == day).toList()
        ..sort((a, b) => a.plannedAt.compareTo(b.plannedAt));

  /// Place une tâche à une heure : elle passe dans « Planifier » si elle était à trier.
  Future<void> planTask(Task t, DateTime at, {int? minutes, String condition = ''}) async {
    t.plannedAt = at.millisecondsSinceEpoch;
    if (minutes != null) t.plannedMin = minutes;
    t.day = dayKey(at);
    t.condition = condition;
    if (t.quad == Quad.inbox) t.quad = Quad.plan;
    await commit();
    await _planChanged();
  }

  /// « Seulement quand… » : pas d'heure, une condition.
  Future<void> setCondition(Task t, String condition) async {
    t.condition = condition.trim();
    t.plannedAt = 0;
    if (t.quad == Quad.inbox) t.quad = Quad.plan;
    await commit();
    await _planChanged();
  }

  Future<void> unplanTask(Task t) async {
    t.plannedAt = 0;
    await commit();
    await _planChanged();
  }

  Remind? reminderFor(Task t, int ts) {
    for (final r in reminders) {
      if (r.taskId == t.id && (r.ts - ts).abs() < 60000) return r;
    }
    return null;
  }

  /// Note la réponse au rappel (créé s'il n'existe pas).
  Remind answerReminder(Task t, int ts, String answer, {String detail = ''}) {
    var r = reminderFor(t, ts);
    if (r == null) {
      r = Remind(taskId: t.id, title: t.title, ts: ts);
      reminders.add(r);
    }
    r.answer = answer;
    r.detail = detail;
    return r;
  }

  /// Reporte le rappel de N minutes. Renvoie vrai si c'est le 3e report (Micky propose de découper).
  Future<bool> postpone(Task t, {required int minutes, int? at, bool save = true}) async {
    final ts = at ?? (t.plannedAt > 0 ? t.plannedAt : DateTime.now().millisecondsSinceEpoch);
    answerReminder(t, ts, '+$minutes');
    final base = max(ts, DateTime.now().millisecondsSinceEpoch);
    t.plannedAt = base + minutes * 60000;
    t.postponed++;
    if (save) {
      await commit();
      await _planChanged();
    }
    return t.postponed >= 3;
  }

  /// Rappels d'aujourd'hui passés et restés sans réponse (pour le journal).
  List<({Task task, int ts})> missedReminders() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final out = <({Task task, int ts})>[];
    for (final t in plannedOn(todayKey)) {
      if (t.done || t.plannedAt > now) continue;
      if (reminderFor(t, t.plannedAt) != null) continue;
      out.add((task: t, ts: t.plannedAt));
    }
    return out;
  }

  List<Remind> remindersOn(String day) =>
      reminders.where((r) => dayKey(DateTime.fromMillisecondsSinceEpoch(r.ts)) == day).toList()
        ..sort((a, b) => a.ts.compareTo(b.ts));

  /// Tâches entamées aujourd'hui (session lancée) et pas finies : alerte « tu switches ».
  List<Task> get switchingToday {
    final ids = <String>{};
    for (final s in sessionsOn(todayKey)) {
      if (s.taskId.isEmpty) continue;
      final t = taskById(s.taskId);
      if (t != null && !t.done && !t.removed) ids.add(t.id);
    }
    return [for (final id in ids) taskById(id)!];
  }

  // ---------- Sessions ----------

  SessionRec? get runningSession {
    for (final s in sessions) {
      if (s.running) return s;
    }
    return null;
  }

  Future<SessionRec> startSession(String taskId, String title, int predicted,
      {String category = '', bool silent = true, String stim = '', String target = ''}) async {
    final tk = taskById(taskId);
    final s = SessionRec(
      target: target,
      progFrom: tk == null ? -1 : (tk.isBoss ? tk.bossProgress : tk.progress),
      taskId: taskId,
      title: title,
      start: DateTime.now().millisecondsSinceEpoch,
      predictedMin: predicted,
      category: category,
      silent: silent,
      stim: stim,
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
    if (sessionCategory(s) == Act.perso) {
      // le perso n'est pas un jeu : on note le temps, sans coffre ni pari
      await commit();
      return '';
    }
    // pro : 1 XP par minute de travail (plafonné à 3 h)
    _gainXp(min(180, minutes).round(), 'Session');
    final t = taskById(s.taskId);
    if (t != null && t.isBoss) {
      // les minutes sont ses coups ; l'avancement, c'est toi qui le dis au débrief
      t.bossHp = max(0, bossTotal(t) - bossMinutes(t));
    }
    var chest = '';
    if (s.onTarget) {
      _gainXp(15, 'Pari réussi');
      chest = _openChest();
    }
    _checkMedals();
    await commit();
    return chest;
  }

  /// Tire un objet pas encore possédé (les rares sont plus rares), ou null si tout est possédé.
  GameObject? _drawObject({int maxRarity = 2}) {
    final r = Random();
    final pool = <GameObject>[];
    for (final o in Objects.all) {
      // pas d'objet sans illustration dans les coffres
      if (inventory.contains(o.id) || o.rarity > maxRarity || o.asset.isEmpty) continue;
      for (var i = 0; i < (o.rarity == 1 ? 4 : o.rarity == 2 ? 2 : 1); i++) {
        pool.add(o);
      }
    }
    if (pool.isEmpty) return null;
    return pool[r.nextInt(pool.length)];
  }

  String _openChest() {
    final r = Random();
    String item;
    final obj = r.nextInt(5) == 0 ? null : _drawObject();
    if (obj == null) {
      item = Loot.rewards[r.nextInt(Loot.rewards.length)];
      if (item == 'Joker de série') _gainXp(0, 'Joker');
      if (item == '+30 XP bonus') _gainXp(30, 'Coffre');
    } else {
      inventory.add(obj.id);
      item = obj.name;
      lastObject = obj.id;
    }
    lastChest = item;
    // trace du butin, pour les stats de gains
    _gainXp(0, 'Butin : $item');
    return item;
  }

  /// Dernier objet gagné (pour la carte de révélation), consommé par l'interface.
  String lastObject = '';

  List<GameObject> get ownedObjects => [for (final id in inventory) if (Objects.byId(id) != null) Objects.byId(id)!];

  /// Objets possédés mais pas encore posés.
  List<GameObject> get unplacedObjects => ownedObjects.where((o) => !placements.any((p) => p.id == o.id)).toList();

  Placement? placementOf(String id) {
    for (final p in placements) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> placeObject(String id, String room, int gx, int gy) async {
    // une case par objet
    placements.removeWhere((p) => p.id != id && p.room == room && p.gx == gx && p.gy == gy && !(Objects.byId(p.id)?.accessory ?? false));
    final cur = placementOf(id);
    if (cur == null) {
      placements.add(Placement(id: id, room: room, gx: gx, gy: gy));
    } else {
      cur.room = room;
      cur.gx = gx;
      cur.gy = gy;
    }
    await commit();
  }

  Future<void> unplaceObject(String id) async {
    placements.removeWhere((p) => p.id == id);
    await commit();
  }

  /// Accessoires que Micky porte (posés dans la « pièce » micky).
  List<GameObject> get worn => [
        for (final p in placements)
          if (p.room == 'micky' && Objects.byId(p.id) != null) Objects.byId(p.id)!
      ];

  bool seriesComplete(String series) => Objects.inSeries(series).every((o) => inventory.contains(o.id));

  /// Célébration à afficher (coffre géant, journée parfaite), consommée par l'interface.
  String? pendingCelebration;

  bool _claimedToday(String reason) => xpEvents.any(
      (e) => e.reason == reason && dayKey(DateTime.fromMillisecondsSinceEpoch(e.ts)) == todayKey);

  /// Vérifie les super bonus du jour.
  void _checkBigBonuses() {
    final today = tasks.where((t) => t.day == todayKey && !t.removed).toList();
    final pro = today.where((t) => t.category != 'perso').toList();
    final msgs = <String>[];
    if (pro.length >= 2 && pro.every((t) => t.done) && !_claimedToday('Coffre géant')) {
      _gainXp(100, 'Coffre géant');
      final a = _openChest();
      final b = _openChest();
      msgs.add('COFFRE GÉANT · toutes tes tâches pro sont faites !\n+100 XP · $a · $b');
    }
    final habitsOk = activeHabits.isNotEmpty && activeHabits.every((h) => habitLevel(h, todayKey) > 0);
    if (today.length >= 3 && today.every((t) => t.done) && habitsOk && !_claimedToday('Journée parfaite')) {
      _gainXp(200, 'Journée parfaite');
      _gainXp(0, 'Joker');
      final epic = Objects.all.where((o) => o.rarity == 3 && !inventory.contains(o.id)).toList();
      final obj = epic.isEmpty ? _drawObject(maxRarity: 3) : epic[Random().nextInt(epic.length)];
      final item = obj?.name ?? 'Thème doré pour 24 h';
      if (obj != null) {
        inventory.add(obj.id);
        lastObject = obj.id;
      }
      _gainXp(0, 'Butin : $item');
      msgs.add('JOURNÉE PARFAITE · tout est fait, habitudes comprises !\n+200 XP · $item · un joker de série');
    }
    if (msgs.isNotEmpty) pendingCelebration = msgs.join('\n\n');
  }

  /// Gains d'un jour : XP total, détail par raison, butins.
  ({int xp, Map<String, int> byReason, List<String> loot}) gainsOn(String day) {
    var total = 0;
    final by = <String, int>{};
    final loot = <String>[];
    for (final e in xpEvents) {
      if (dayKey(DateTime.fromMillisecondsSinceEpoch(e.ts)) != day) continue;
      if (e.reason.startsWith('Butin : ')) {
        loot.add(e.reason.substring(8));
        continue;
      }
      if (e.amount == 0) continue;
      total += e.amount;
      final k = e.reason.startsWith('Habitude')
          ? 'Habitudes'
          : e.reason == 'Tâche décochée'
              ? 'Tâche faite'
              : e.reason.startsWith('Budget tenu')
                  ? 'Budget tenu'
                  : e.reason.startsWith('Feu de camp')
                      ? 'Feu de camp'
                      : e.reason.startsWith('Mieux que ta médiane')
                          ? 'Mieux que ta médiane'
                          : e.reason.startsWith('Remontée')
                              ? 'Remontée'
                              : e.reason;
      by[k] = (by[k] ?? 0) + e.amount;
    }
    return (xp: total, byReason: by, loot: loot);
  }

  // ---------- Check-ins et journal ----------

  Future<void> addCheckIn(CheckIn c) async {
    checkins.add(c);
    checkins.sort((a, b) => a.ts.compareTo(b.ts));
    _gainXp(1, 'Check-in');
    await commit();
  }

  Future<void> removeCheckIn(CheckIn c) async {
    checkins.remove(c);
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
          : 'pari ${s.predictedMin} min · réel ${s.actualMin.round()} min${s.onTarget ? ' · coffre gagné' : ''}${s.stopWhy.isNotEmpty ? ' · arrêtée : ${s.stopWhy.toLowerCase()}' : s.finished ? '' : ' · décrochée'}${s.interrupted == 0 ? ' · sans interruption' : s.interrupted == 1 ? ' · 1 interruption' : s.interrupted >= 2 ? ' · plusieurs interruptions' : ''}';
      ev.add(ReplayEvent(s.start, 'quest', 'Session · ${s.title}', detail));
    }
    for (final c in checkinsOn(day)) {
      final parts = <String>[];
      final task = c.taskId.isEmpty ? null : taskById(c.taskId);
      if (task != null) parts.add(task.title);
      if (c.label.isNotEmpty) parts.add(c.label);
      if (c.sinceMin >= 0) parts.add('depuis ${c.sinceMin} min');
      if (c.reason.isNotEmpty) parts.add('raison : ${c.reason.toLowerCase()}');
      if (c.emotion.isNotEmpty) {
        parts.add('${c.emotion}${c.cause.isNotEmpty ? ' (${c.cause})' : ''}');
      } else if (c.mood > 0) {
        parts.add('humeur ${moodLabels[c.mood - 1].toLowerCase()}');
      }
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
                  : l.kind == LogKind.pill
                      ? 'pill'
                      : l.kind == LogKind.calm
                          ? 'calm'
                          : 'free';
      ev.add(ReplayEvent(l.ts, kind, l.label, l.note, l.photo));
    }
    for (final l in habitLogs.where((l) => l.day == day && l.level > 0)) {
      Habit? h;
      for (final x in habits) {
        if (x.id == l.habitId) h = x;
      }
      if (h == null) continue;
      ev.add(ReplayEvent(l.mod, 'habit', 'Habitude · ${h.name}', l.level == 2 ? 'version complète' : 'version mini'));
    }
    for (final r in reflections.where((r) => dayKey(DateTime.fromMillisecondsSinceEpoch(r.ts)) == day)) {
      final parts = [...r.reasons, if (r.text.isNotEmpty) r.text];
      if (r.ifCue.isNotEmpty) parts.add('si ${r.ifCue}, alors ${r.thenDo}');
      ev.add(ReplayEvent(r.ts, 'reflect', 'Réflexion · ${r.title}', parts.join(' · ')));
    }
    for (final e in expenses.where((e) => !e.removed && dayKey(DateTime.fromMillisecondsSinceEpoch(e.ts)) == day)) {
      ev.add(ReplayEvent(e.ts, 'expense', 'Dépense · ${e.amount.toStringAsFixed(2).replaceAll('.', ',')} €',
          '${Expense.labels[e.category] ?? e.category}${e.why.isNotEmpty ? ' · ${e.why}' : ''}'));
    }
    for (final x in slotsOn(day)) {
      final parts = <String>[
        '${_hm(x.start)}–${_hm(x.end)}',
        if (x.title.isNotEmpty) x.title,
        if (x.emotion.isNotEmpty) x.emotion,
        if (x.why.isNotEmpty) 'pourquoi : ${x.why.toLowerCase()}',
      ];
      ev.add(ReplayEvent(x.start, x.kind == 'idle' ? 'idle' : 'slot', 'Créneau · ${Slot.labels[x.kind] ?? x.kind}', parts.join(' · ')));
    }
    for (final r in remindersOn(day)) {
      ev.add(ReplayEvent(r.ts, 'remind', 'Rappel · ${r.title}',
          '${Remind.labels[r.answer] ?? r.answer}${r.detail.isNotEmpty ? ' · ${r.detail}' : ''}'));
    }
    for (final p in pauses) {
      if (dayKey(DateTime.fromMillisecondsSinceEpoch(p.start)) != day) continue;
      final until = p.end == 0 ? 'en cours' : 'jusqu\'à ${DateTime.fromMillisecondsSinceEpoch(p.end).hour}h${DateTime.fromMillisecondsSinceEpoch(p.end).minute.toString().padLeft(2, '0')}';
      ev.add(ReplayEvent(p.start, 'pause', 'Pause · ${p.label}', '$until · check-ins coupés'));
    }
    for (final t in tasks.where((t) => t.done && dayKey(DateTime.fromMillisecondsSinceEpoch(t.doneAt)) == day)) {
      ev.add(ReplayEvent(t.doneAt, 'task', 'Tâche faite', t.title));
    }
    ev.sort((a, b) => a.ts.compareTo(b.ts));
    return ev;
  }

  /// Minutes passées par tâche dans la journée : sessions + check-ins.
  /// Un check-in sans durée précisée vaut l'intervalle depuis le check-in précédent.
  Map<String, double> minutesByTask(String day) {
    final m = <String, double>{};
    for (final s in sessionsOn(day)) {
      final k = s.taskId.isNotEmpty ? s.taskId : 'label:${s.title}';
      if (s.running) {
        m[k] = (m[k] ?? 0) + DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(s.start)).inMinutes;
      } else {
        m[k] = (m[k] ?? 0) + s.actualMin;
      }
    }
    final cs = checkinsOn(day)..sort((a, b) => a.ts.compareTo(b.ts));
    for (var i = 0; i < cs.length; i++) {
      final c = cs[i];
      if (c.taskId.isEmpty && c.label.isEmpty) continue;
      if (c.taskId.isEmpty) {
        if (_duringSession(c.ts)) continue;
        final k = 'label:${c.label}';
        m[k] = (m[k] ?? 0) + _checkinMinutes(cs, i);
        continue;
      }
      // pendant une session, le temps est déjà compté
      if (sessionsOn(day).any((s) => s.taskId == c.taskId && c.ts >= s.start && (s.running || c.ts <= s.end))) continue;
      double mins;
      if (c.sinceMin >= 0) {
        mins = c.sinceMin.toDouble();
      } else {
        final prev = i > 0 ? cs[i - 1].ts : c.ts - settings.intervalMin * 60000;
        mins = min(settings.intervalMin.toDouble(), (c.ts - prev) / 60000.0);
      }
      m[c.taskId] = (m[c.taskId] ?? 0) + mins;
    }
    return m;
  }

  double minutesOnTask(Task t, String day) => minutesByTask(day)[t.id] ?? 0;

  /// Catégorie d'une session : la sienne, sinon celle de sa tâche (pro par défaut).
  String sessionCategory(SessionRec s) {
    if (s.category.isNotEmpty) return s.category;
    return taskById(s.taskId)?.category == 'perso' ? Act.perso : Act.pro;
  }

  /// Nom lisible d'une clé de minutesByTask (identifiant de tâche ou « label:… »).
  String keyTitle(String k) => k.startsWith('label:') ? k.substring(6) : (taskById(k)?.title ?? 'Tâche');

  /// Catégorie d'un check-in : pro, perso, pause, phone ou none.
  String categoryOf(CheckIn c) {
    if (c.activity == Act.quest || c.activity == Act.other) {
      final t = c.taskId.isEmpty ? null : taskById(c.taskId);
      return t?.category == 'perso' ? Act.perso : Act.pro;
    }
    return c.activity;
  }

  double _checkinMinutes(List<CheckIn> sorted, int i) {
    final c = sorted[i];
    if (c.sinceMin >= 0) return c.sinceMin.toDouble();
    final prev = i > 0 ? sorted[i - 1].ts : c.ts - settings.intervalMin * 60000;
    return min(settings.intervalMin.toDouble(), (c.ts - prev) / 60000.0);
  }

  bool _duringSession(int ts) => sessions.any((s) => ts >= s.start && (s.running || ts <= s.end));

  /// Minutes par catégorie (pro, perso, pause, phone, none) pour un jour.
  Map<String, double> minutesByCategory(String day) {
    final m = <String, double>{};
    void add(String k, double v) => m[k] = (m[k] ?? 0) + v;
    for (final s in sessionsOn(day)) {
      add(sessionCategory(s),
          s.running ? DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(s.start)).inMinutes.toDouble() : s.actualMin);
    }
    for (final x in slotsOn(day)) {
      add(x.category, x.minutes);
    }
    final cs = checkinsOn(day)..sort((a, b) => a.ts.compareTo(b.ts));
    for (var i = 0; i < cs.length; i++) {
      if (cs[i].activity.isEmpty || _duringSession(cs[i].ts) || _inSlot(cs[i].ts)) continue;
      add(categoryOf(cs[i]), _checkinMinutes(cs, i));
    }
    return m;
  }

  /// Cumul par catégorie sur les N derniers jours.
  Map<String, double> minutesByCategoryLast(int days) {
    final m = <String, double>{};
    for (var i = 0; i < days; i++) {
      minutesByCategory(dayKey(DateTime.now().subtract(Duration(days: i)))).forEach((k, v) => m[k] = (m[k] ?? 0) + v);
    }
    return m;
  }

  /// Minutes de travail (pro) par heure de la journée, sur les N derniers jours.
  List<double> proByHour(int days) {
    final out = List.filled(24, 0.0);
    final from = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    void spread(int start, int end) {
      var t = start;
      while (t < end) {
        final d = DateTime.fromMillisecondsSinceEpoch(t);
        final nextHour = DateTime(d.year, d.month, d.day, d.hour + 1).millisecondsSinceEpoch;
        final stop = min(end, nextHour);
        out[d.hour] += (stop - t) / 60000.0;
        t = stop;
      }
    }

    for (final s in sessions) {
      if (s.start < from || sessionCategory(s) != Act.pro) continue;
      spread(s.start, s.running ? DateTime.now().millisecondsSinceEpoch : s.end);
    }
    for (final x in slots.where((x) => !x.removed && x.kind == 'pro' && x.start >= from)) {
      spread(x.start, x.end);
    }
    final cs = checkins.where((c) => c.ts >= from).toList()..sort((a, b) => a.ts.compareTo(b.ts));
    for (var i = 0; i < cs.length; i++) {
      if (categoryOf(cs[i]) != Act.pro || _duringSession(cs[i].ts) || _inSlot(cs[i].ts)) continue;
      final mins = _checkinMinutes(cs, i);
      spread(cs[i].ts - (mins * 60000).round(), cs[i].ts);
    }
    return out;
  }

  /// Répartition des activités du jour d'après les check-ins.
  Map<String, int> activityShare(String day) {
    final m = <String, int>{};
    for (final c in checkinsOn(day)) {
      if (c.activity.isEmpty) continue;
      final k = categoryOf(c);
      m[k] = (m[k] ?? 0) + 1;
    }
    return m;
  }

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
      if (Act.isWork(c.activity)) hits[d.weekday - 1][col]++;
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
        if (Act.isWork(c.activity)) byBlock[b]![0]++;
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

    // 3. Déclencheur principal de décrochage (check-ins et réflexions).
    {
      final reasons = <String>[
        for (final c in checkins)
          if (c.reason.isNotEmpty) c.reason,
        for (final r in reflections) ...r.reasons,
      ];
      if (reasons.length >= 6) {
        final count = <String, int>{};
        for (final c in reasons) {
          count[c] = (count[c] ?? 0) + 1;
        }
        final top = count.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        out.add(Discovery('why', 'Ton piège principal',
            '« ${top.first.key} » revient dans ${(100 * top.first.value / reasons.length).round()} % de tes décrochages.', 1, ''));
      } else {
        out.add(Discovery('why', 'Ton piège principal', '', reasons.length / 6, '6 décrochages expliqués'));
      }
    }

    // 3 ter. Ce qui te fait flotter (relances choisies).
    {
      final rel = logs.where((l) => l.note.startsWith('Relance : ')).toList();
      if (rel.length >= 6) {
        final count = <String, int>{};
        final when = <String, int>{};
        for (final l in rel) {
          final c = l.note.substring(10);
          count[c] = (count[c] ?? 0) + 1;
          final h = DateTime.fromMillisecondsSinceEpoch(l.ts).hour;
          final w = h < 12 ? 'le matin' : (h < 17 ? 'l\'après-midi' : 'le soir');
          when[w] = (when[w] ?? 0) + 1;
        }
        final top = count.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final tw = when.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        out.add(Discovery('float', 'Ce qui te fait flotter',
            'Quand ça flotte, c\'est surtout « ${top.first.key} » (${(100 * top.first.value / rel.length).round()} %), plutôt ${tw.first.key}.', 1, ''));
      } else {
        out.add(Discovery('float', 'Ce qui te fait flotter', '', rel.length / 6, '6 relances « ça flotte »'));
      }
    }

    // 3 bis. Difficulté ressentie et estimation.
    {
      final rated = sessions.where((x) => x.finished && x.ratio > 0 && x.difficulty > 0).toList();
      final hard = rated.where((x) => x.difficulty == 3).toList();
      final easy = rated.where((x) => x.difficulty < 3).toList();
      if (hard.length >= 3 && easy.length >= 3) {
        double med(List<SessionRec> l) {
          final r = l.map((x) => x.ratio).toList()..sort();
          return r[r.length ~/ 2];
        }

        final mh = med(hard), me = med(easy);
        String f(double v) => '×${v.toStringAsFixed(1).replaceAll('.', ',')}';
        out.add(Discovery('hard', 'Les tâches dures et ton estimation',
            mh > me + 0.15
                ? 'Quand une tâche te paraît dure, elle prend ${f(mh)} le temps prévu (contre ${f(me)} sinon). Découpe-les plus finement.'
                : 'Tu estimes aussi bien les tâches dures (${f(mh)}) que les faciles (${f(me)}).',
            1, ''));
      } else {
        out.add(Discovery('hard', 'Les tâches dures et ton estimation', '',
            (min(hard.length, 3) + min(easy.length, 3)) / 6, '3 sessions notées « dur » et 3 autres'));
      }
    }

    // 3 ter. Ce qui rend une session agréable.
    {
      final felt = sessions.where((x) => x.feeling > 0 && x.end > 0).toList();
      if (felt.length >= 8) {
        final nice = felt.where((x) => x.feeling == 3).toList();
        final rest = felt.where((x) => x.feeling < 3).toList();
        double meanMin(List<SessionRec> l) => l.isEmpty ? 0 : l.map((x) => x.predictedMin).reduce((a, b) => a + b) / l.length;
        final txt = nice.isEmpty
            ? 'Aucune session agréable pour l\'instant : essaie des blocs plus courts ou une tâche plus variée.'
            : meanMin(nice) < meanMin(rest) - 5
                ? 'Tes sessions agréables sont plus courtes (${meanMin(nice).round()} min en moyenne) : les petits blocs te réussissent.'
                : 'Tes sessions agréables durent environ ${meanMin(nice).round()} min : la durée n\'est pas ce qui te freine.';
        out.add(Discovery('feel', 'Ce qui te fait du bien', txt, 1, ''));
      } else {
        out.add(Discovery('feel', 'Ce qui te fait du bien', '', felt.length / 8, '8 sessions évaluées'));
      }
    }

    // 3 quater. Conditions de travail (seule, body double, bruit, musique).
    {
      final by = <String, List<SessionRec>>{};
      for (final x in sessions.where((x) => x.end > 0 && x.stim.isNotEmpty && sessionCategory(x) == Act.pro)) {
        by.putIfAbsent(x.stim, () => []).add(x);
      }
      final ok = by.entries.where((e) => e.value.length >= 3).toList();
      if (ok.length >= 2) {
        double score(List<SessionRec> l) =>
            l.map((x) => x.actualMin == 0 ? 0.0 : x.focusMin / x.actualMin).reduce((a, b) => a + b) / l.length;
        ok.sort((a, b) => score(b.value).compareTo(score(a.value)));
        out.add(Discovery('stim', 'Tes conditions de focus',
            'Tu tiens le mieux « ${SessionRec.stims[ok.first.key]?.toLowerCase()} » (${(100 * score(ok.first.value)).round()} % de focus) ; le moins « ${SessionRec.stims[ok.last.key]?.toLowerCase()} » (${(100 * score(ok.last.value)).round()} %).',
            1, ''));
      } else {
        out.add(Discovery('stim', 'Tes conditions de focus', '', min(1.0, ok.length / 2), '3 sessions dans 2 conditions différentes'));
      }
    }

    // 4 et 5. Energy drinks, café et pilule.
    for (final kind in [LogKind.energy, LogKind.coffee, LogKind.pill]) {
      final name = kind == LogKind.energy ? 'Energy drinks' : kind == LogKind.coffee ? 'Café' : 'Pilule';
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
        out.add(Discovery(kind, '$name et focus', 'Après ${name == 'Café' ? 'un café' : name == 'Pilule' ? 'une pilule' : 'un energy drink'}, $focusTxt$moodTxt.', 1, ''));
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
        if (Act.isWork(c.activity)) by[w][0]++;
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

    // 7 bis. Heure de début et temps de préparation.
    {
      final starts = <double>[];
      final preps = <double>[];
      for (var i = 0; i < 14; i++) {
        final d = dayKey(DateTime.now().subtract(Duration(days: i)));
        final st = workStart(d);
        if (st != null) {
          starts.add(st.hour + st.minute / 60);
          preps.add(prepMinutes(d));
        }
      }
      if (starts.length >= 5) {
        final ms = starts.reduce((a, b) => a + b) / starts.length;
        final mp = preps.reduce((a, b) => a + b) / preps.length;
        final h = ms.floor(), m = ((ms - h) * 60).round();
        out.add(Discovery('start', 'Ton heure de démarrage',
            'Tu commences à travailler vers ${h}h${m.toString().padLeft(2, '0')} en moyenne, après ${mp.round()} min de préparation. '
            '${mp > 60 ? 'Un point de spawn préparé la veille peut raccourcir ça.' : 'Chaque demi-heure gagnée le matin se retrouve dans ta barre Focus.'}',
            1, ''));
      } else {
        out.add(Discovery('start', 'Ton heure de démarrage', '', starts.length / 5, '5 jours avec du travail pro noté'));
      }
    }

    // 7 ter. Créneaux improductifs : quand et pourquoi.
    {
      final idle = slots.where((x) => !x.removed && x.kind == 'idle').toList();
      if (idle.length >= 4) {
        final parts = {'le matin': 0.0, 'l\'après-midi': 0.0, 'le soir': 0.0};
        final whys = <String, int>{};
        for (final x in idle) {
          final h = DateTime.fromMillisecondsSinceEpoch(x.start).hour;
          final k = h < 12 ? 'le matin' : h < 18 ? 'l\'après-midi' : 'le soir';
          parts[k] = parts[k]! + x.minutes;
          if (x.why.isNotEmpty) whys[x.why] = (whys[x.why] ?? 0) + 1;
        }
        final top = parts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final w = whys.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        // nuits courtes avant les jours improductifs ?
        final days = idle.map((x) => dayKey(DateTime.fromMillisecondsSinceEpoch(x.start))).toSet();
        final sl = days.map((d) => plans[d]?.sleepH ?? 0).where((v) => v > 0).toList();
        final shortSleep = sl.isNotEmpty && sl.where((v) => v < 14).length / sl.length >= 0.6;
        out.add(Discovery('idle', 'Tes créneaux qui glissent',
            'Ils tombent surtout ${top.first.key}${w.isNotEmpty ? ', le plus souvent par « ${w.first.key.toLowerCase()} »' : ''}.${shortSleep ? ' Et souvent après une nuit de moins de 7 h.' : ''} Un bloc facile planifié à ce moment-là peut aider.',
            1, ''));
      } else {
        out.add(Discovery('idle', 'Tes créneaux qui glissent', '', idle.length / 4, '4 créneaux « improductive » notés'));
      }
    }

    // 7 quater. La cabane : ce qui pèse et ce qui aide.
    {
      final visits = cabin.where((v) => v.weights.isNotEmpty).toList();
      if (visits.length >= 3) {
        final w = <String, int>{};
        for (final v in visits) {
          for (final x in v.weights) {
            w[x] = (w[x] ?? 0) + 1;
          }
        }
        final top = w.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final eff = angleEfficacy().entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final hours = visits.map((v) => DateTime.fromMillisecondsSinceEpoch(v.ts).hour).toList()..sort();
        final h = hours[hours.length ~/ 2];
        out.add(Discovery('cabin', 'Tes coups de mou',
            'Ce qui pèse le plus souvent : ${top.first.key.replaceAll(':', ' · ')}, plutôt vers ${h}h.'
            '${eff.isNotEmpty ? ' Ce qui t\'aide le plus : « ${eff.first.key} » (−${eff.first.value.toStringAsFixed(1).replaceAll('.', ',')} en moyenne).' : ''}',
            1, ''));
      } else {
        out.add(Discovery('cabin', 'Tes coups de mou', '', visits.length / 3, '3 passages dans la cabane'));
      }
    }

    // 7 quinquies. Peau : cycle et humeur des jours d'avant.
    {
      final noted = plans.values.where((p) => p.skin >= 0).toList();
      if (noted.length >= 14) {
        final parts = <String>[];
        if (settings.cycleStart.isNotEmpty) {
          final by = <String, List<int>>{};
          for (final p in noted) {
            final ph = phaseOn(parseDay(p.day));
            if (ph != null) by.putIfAbsent(ph, () => []).add(p.skin);
          }
          final ok = by.entries.where((e) => e.value.length >= 3).toList();
          if (ok.length >= 2) {
            double mean(List<int> l) => l.reduce((a, b) => a + b) / l.length;
            ok.sort((a, b) => mean(b.value).compareTo(mean(a.value)));
            parts.add('Ta peau est la plus agitée en phase ${ok.first.key} (${mean(ok.first.value).toStringAsFixed(1).replaceAll('.', ',')}/4) et la plus calme en phase ${ok.last.key}.');
          }
        }
        // humeur moyenne 2 jours avant
        final bad = <double>[], good = <double>[];
        for (final p in noted) {
          final d = parseDay(p.day).subtract(const Duration(days: 2));
          final moods = checkinsOn(dayKey(d)).where((c) => c.mood > 0).map((c) => c.mood).toList();
          if (moods.isEmpty) continue;
          final m = moods.reduce((a, b) => a + b) / moods.length;
          (p.skin >= 3 ? bad : p.skin <= 1 ? good : <double>[]).add(m);
        }
        if (bad.length >= 3 && good.length >= 3) {
          final mb = bad.reduce((a, b) => a + b) / bad.length, mg = good.reduce((a, b) => a + b) / good.length;
          parts.add(mb < mg - 0.3
              ? 'Les poussées suivent souvent des jours d\'humeur plus basse (deux jours avant).'
              : 'Ton humeur des jours d\'avant ne semble pas jouer sur ta peau.');
        }
        out.add(Discovery('skin', 'Ta peau', parts.isEmpty ? 'Pas encore de lien net avec ton cycle ou ton humeur.' : parts.join(' '), 1, ''));
      } else {
        out.add(Discovery('skin', 'Ta peau', '', noted.length / 14, '14 matins avec ta peau notée'));
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

  // ---------- Habitudes ----------

  List<Habit> get activeHabits => habits.where((h) => !h.archived).toList()..sort((a, b) => a.order.compareTo(b.order));

  int habitLevel(Habit h, String day) {
    for (final l in habitLogs) {
      if (l.habitId == h.id && l.day == day) return l.level;
    }
    return 0;
  }

  /// Fait (complète) → mini → rien, à chaque toucher.
  Future<int> cycleHabit(Habit h, {String? day, int? to}) async {
    final d = day ?? todayKey;
    HabitLog? log;
    for (final l in habitLogs) {
      if (l.habitId == h.id && l.day == d) log = l;
    }
    final cur = log?.level ?? 0;
    final next = to ?? (cur == 0 ? 2 : (cur == 2 ? 1 : 0));
    if (log == null) {
      log = HabitLog(habitId: h.id, day: d, level: next);
      habitLogs.add(log);
    } else {
      log.level = next;
    }
    if (cur == 0 && next > 0) _gainXp(next == 2 ? 5 : 3, 'Habitude');
    if (cur > 0 && next == 0) _gainXp(cur == 2 ? -5 : -3, 'Habitude annulée');
    if (cur == 2 && next == 1) _gainXp(-2, 'Habitude en mini');
    if (cur == 1 && next == 2) _gainXp(2, 'Habitude complète');
    if (next > 0) {
      _checkBigBonuses();
      _checkMedals();
    }
    await commit();
    return next;
  }

  /// Force de l'habitude (0 à 1) : monte avec chaque jour fait, baisse doucement sinon.
  /// Rater un jour ne remet rien à zéro.
  double habitStrength(Habit h) {
    if (h.created.isEmpty) return 0;
    var d = parseDay(h.created);
    final end = DateTime.now();
    final done = <String, int>{};
    for (final l in habitLogs) {
      if (l.habitId == h.id) done[l.day] = l.level;
    }
    var s = 0.0;
    var guard = 0;
    while (!d.isAfter(end) && guard++ < 2000) {
      final lv = done[dayKey(d)] ?? 0;
      final v = lv == 2 ? 1.0 : (lv == 1 ? 0.7 : 0.0);
      final isToday = dayKey(d) == todayKey;
      // aujourd'hui ne compte que si c'est déjà fait
      if (!isToday || v > 0) s += 0.07 * (v - s);
      d = d.add(const Duration(days: 1));
    }
    return s.clamp(0.0, 1.0);
  }

  static String strengthLabel(double s) {
    if (s < 0.15) return 'Graine';
    if (s < 0.4) return 'Pousse';
    if (s < 0.65) return 'Racines';
    if (s < 0.85) return 'Bien ancrée';
    return 'Automatique';
  }

  int habitDaysDone(Habit h, {int last = 7}) {
    final from = dayKey(DateTime.now().subtract(Duration(days: last - 1)));
    return habitLogs.where((l) => l.habitId == h.id && l.level > 0 && l.day.compareTo(from) >= 0).length;
  }

  Future<String?> saveHabit(Habit h) async {
    if (!habits.contains(h)) {
      if (activeHabits.length >= Habit.maxActive) {
        return 'Trois habitudes à la fois au maximum. Mets-en une en pause d\'abord.';
      }
      h.order = habits.length;
      habits.add(h);
    }
    await commit();
    return null;
  }

  Future<String?> setHabitArchived(Habit h, bool archived) async {
    if (!archived && activeHabits.length >= Habit.maxActive) {
      return 'Trois habitudes à la fois au maximum.';
    }
    h.archived = archived;
    await commit();
    return null;
  }

  // ---------- Évaluations et réflexions ----------

  /// Réponse « où est ton attention » pendant une session (0 à fond … 3 ailleurs).
  Future<void> recordAttention(SessionRec s, int level) async {
    s.atts += '${level.clamp(0, 3)}';
    await commit();
  }

  /// Relance choisie quand ça flotte (pas clair, pression, rond, difficile, corps).
  Future<void> addBoost(SessionRec? s, String cause) async {
    if (s != null) s.boosts = s.boosts.isEmpty ? cause : '${s.boosts},$cause';
    logs.add(LogEntry(ts: DateTime.now().millisecondsSinceEpoch, kind: LogKind.free, note: 'Relance : ${boostLabels[cause] ?? cause}'));
    await commit();
  }

  /// Session arrêtée pour un impératif pro (réunion, appel…) : le temps compte, ce n'est pas un décrochage.
  Future<void> stopForImperative(SessionRec s, String what) async {
    s.stopWhy = what;
    if (s.interrupted < 0) s.interrupted = 0;
    await endSession(s, finished: false);
  }

  static const imperatives = ['Réunion', 'Appel', 'Mail urgent', 'Quelqu\'un a besoin de moi', 'Autre impératif'];

  static const boostLabels = {
    'flou': 'pas clair',
    'pression': 'manque de pression',
    'rond': 'je tourne en rond',
    'dur': 'j\'évite le difficile',
    'corps': 'mon corps',
  };

  /// Débrief : concentration, avancement, résultat visé. Ne jamais faire perdre d'XP pour une réponse honnête.
  Future<void> rateProgress(SessionRec s, {int? focus, int? progTo, int? targetMet}) async {
    if (focus != null && focus > 0) {
      if (s.focus == 0) _gainXp(2, 'Réponse honnête');
      s.focus = focus;
    }
    if (targetMet != null) s.targetMet = targetMet;
    if (progTo != null) {
      final before = s.progTo;
      s.progTo = progTo.clamp(0, 100);
      if (s.progFrom < 0) s.progFrom = 0;
      final t = taskById(s.taskId);
      if (t != null && !t.isBoss) t.progress = max(t.progress, s.progTo);
      final gain = s.progGain - (before < 0 ? 0 : (before - s.progFrom).clamp(0, 100));
      if (gain > 0 && sessionCategory(s) == Act.pro) _gainXp(min(20, (gain * 0.4).round()), 'Avancement');
    }
    await commit();
  }

  // ---------- Toi contre toi ----------

  /// Mesures d'une journée. null = rien à mesurer ce jour-là.
  Map<String, double?> dayMetrics(String day) {
    final ss = sessionsOn(day).where((x) => !x.running && sessionCategory(x) == Act.pro).toList();
    final foc = ss.where((x) => x.focus > 0).map((x) => x.focus.toDouble()).toList();
    final prog = ss.where((x) => x.progTo >= 0).map((x) => x.progGain.toDouble()).toList();
    final est = ss.where((x) => x.predictedMin > 0 && x.actualMin >= 5).map((x) => (x.actualMin / x.predictedMin - 1).abs()).toList();
    final done = tasks.where((t) => t.done && t.doneAt > 0 && dayKey(DateTime.fromMillisecondsSinceEpoch(t.doneAt)) == day).length;
    final pro = proMinutesOn(day);
    final active = pro > 0 || done > 0 || ss.isNotEmpty;
    return {
      'pro': active ? pro : null,
      'focus': foc.isEmpty ? null : foc.reduce((a, b) => a + b) / foc.length,
      'prog': prog.isEmpty ? null : prog.reduce((a, b) => a + b),
      'tasks': active ? done.toDouble() : null,
      'est': est.isEmpty ? null : _median(est),
    };
  }

  static double _median(List<double> v) {
    final l = [...v]..sort();
    final n = l.length;
    return n.isOdd ? l[n ~/ 2] : (l[n ~/ 2 - 1] + l[n ~/ 2]) / 2;
  }

  static const selfLabels = {
    'pro': 'Temps pro',
    'focus': 'Concentration',
    'prog': 'Avancement',
    'tasks': 'Tâches faites',
    'est': 'Justesse d\'estimation',
  };

  /// Médiane des 21 jours précédents pour une mesure ; null s'il y a moins de 5 jours de données.
  (double, int)? selfMedian(String key, String day) {
    final d = DateTime.parse(day);
    final vals = <double>[];
    for (var i = 1; i <= 21; i++) {
      final v = dayMetrics(dayKey(d.subtract(Duration(days: i))))[key];
      if (v != null) vals.add(v);
    }
    if (vals.length < 5) return null;
    return (_median(vals), vals.length);
  }

  /// Statut d'une mesure par rapport à la médiane : 1 au-dessus, 0 dans la zone, -1 journée légère, null inconnu.
  /// Pour l'estimation, plus petit = mieux.
  int? selfStatus(String key, double? value, double? median) {
    if (value == null || median == null) return null;
    if (key == 'est') {
      if (median <= 0.05) return value <= 0.1 ? 0 : -1;
      final r = value / median;
      return r < 0.8 ? 1 : (r > 1.2 ? -1 : 0);
    }
    if (median <= 0) return value > 0 ? 1 : 0;
    final r = value / median;
    return r > 1.2 ? 1 : (r < 0.8 ? -1 : 0);
  }

  /// Nombre de jours avec des données (pour « on apprend ta médiane »).
  int selfDataDays(String day) {
    final d = DateTime.parse(day);
    var n = 0;
    for (var i = 1; i <= 21; i++) {
      if (dayMetrics(dayKey(d.subtract(Duration(days: i))))['pro'] != null) n++;
    }
    return n;
  }

  void _selfBonuses(String day) {
    final m = dayMetrics(day);
    for (final k in selfLabels.keys) {
      final med = selfMedian(k, day);
      if (selfStatus(k, m[k], med?.$1) == 1) {
        final reason = 'Mieux que ta médiane · ${selfLabels[k]} · $day';
        if (!xpEvents.any((e) => e.reason == reason)) _gainXp(k == 'est' ? 10 : 15, reason);
      }
    }
    // remontée : hier en dessous de ta zone de temps pro, aujourd'hui revenue dedans
    final y = dayKey(DateTime.parse(day).subtract(const Duration(days: 1)));
    final my = selfMedian('pro', y), mt = selfMedian('pro', day);
    if (selfStatus('pro', dayMetrics(y)['pro'] ?? 0, my?.$1) == -1 && (selfStatus('pro', m['pro'], mt?.$1) ?? -1) >= 0) {
      final reason = 'Remontée · $day';
      if (!xpEvents.any((e) => e.reason == reason)) _gainXp(20, reason);
    }
  }

  Future<void> rateSession(SessionRec s,
      {int? difficulty, int? feeling, String? helped, int? interrupted, String? hardWhat, String? worthWhy}) async {
    final first = s.difficulty == 0 && s.feeling == 0 && s.interrupted < 0;
    if (difficulty != null) s.difficulty = difficulty;
    if (feeling != null) s.feeling = feeling;
    if (helped != null) s.helped = helped;
    if (interrupted != null) s.interrupted = interrupted;
    if (hardWhat != null) s.hardWhat = hardWhat;
    if (worthWhy != null) s.worthWhy = worthWhy;
    if (first && (s.difficulty > 0 || s.feeling > 0 || s.interrupted >= 0)) _gainXp(2, 'Auto-évaluation');
    // deux minutes à s'asseoir avec ce qui a été dur et pourquoi ça valait le coup : ça ancre
    if ((hardWhat ?? '').isNotEmpty || (worthWhy ?? '').isNotEmpty) _gainXp(0, 'Sérénité : débrief');
    await commit();
  }

  /// Enregistre une réflexion ; le « si… alors » devient le plan B de demain s'il est libre.
  Future<void> addReflection(Reflection r) async {
    reflections.add(r);
    _gainXp(3, 'Réflexion');
    if (r.ifCue.isNotEmpty && r.thenDo.isNotEmpty) {
      final morning = DateTime.now().hour < 12;
      final target = plan(morning ? todayKey : tomorrowKey);
      if (target.planIf.isEmpty && target.planThen.isEmpty) {
        target.planIf = r.ifCue;
        target.planThen = r.thenDo;
      }
    }
    await commit();
  }

  List<Reflection> get recentIfThen {
    final seen = <String>{};
    final out = <Reflection>[];
    for (final r in reflections.reversed) {
      if (r.ifCue.isEmpty || r.thenDo.isEmpty) continue;
      if (seen.add('${r.ifCue}|${r.thenDo}')) out.add(r);
      if (out.length >= 4) break;
    }
    return out;
  }

  /// Heures de check-in d'aujourd'hui déjà passées et sans réponse.
  List<DateTime> missedCheckins() {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final interval = max(15, settings.intervalMin);
    final answered = checkinsOn(todayKey).map((c) => c.ts).toList();
    final out = <DateTime>[];
    for (var m = settings.startHour * 60 + interval; m <= settings.endHour * 60; m += interval) {
      final t = day.add(Duration(minutes: m));
      if (!t.isBefore(now)) break;
      if (pausedAt(t)) continue;
      final ts = t.millisecondsSinceEpoch;
      if (sessions.any((s) => s.silent && ts >= s.start && (s.running || ts <= s.end))) continue;
      final half = interval * 60000 ~/ 2;
      if (answered.any((a) => (a - ts).abs() <= half)) continue;
      out.add(t);
    }
    return out;
  }

  // ---------- Dépenses ----------

  String monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  List<Expense> expensesInMonth(DateTime d) {
    final k = monthKey(d);
    return expenses.where((e) => !e.removed && monthKey(DateTime.fromMillisecondsSinceEpoch(e.ts)) == k).toList()
      ..sort((a, b) => b.ts.compareTo(a.ts));
  }

  double spentInMonth(DateTime d) => expensesInMonth(d).fold(0.0, (a, e) => a + e.amount);
  double remainingThisMonth() => settings.monthlyBudget - spentInMonth(DateTime.now());

  Map<String, double> spentByCategory(DateTime d) {
    final m = <String, double>{};
    for (final e in expensesInMonth(d)) {
      m[e.category] = (m[e.category] ?? 0) + e.amount;
    }
    return m;
  }

  double spentOn(String day) => expenses
      .where((e) => !e.removed && dayKey(DateTime.fromMillisecondsSinceEpoch(e.ts)) == day)
      .fold(0.0, (a, e) => a + e.amount);

  /// Ce que tu peux dépenser au maximum ce jour-là pour tenir le budget du mois :
  /// (budget − dépensé avant ce jour) ÷ jours restants, ce jour compris.
  double dailyAllowance(String day) {
    final b = settings.monthlyBudget;
    if (b <= 0) return 0;
    final d = parseDay(day);
    final before = expenses
        .where((e) => !e.removed)
        .where((e) {
          final t = DateTime.fromMillisecondsSinceEpoch(e.ts);
          return t.year == d.year && t.month == d.month && t.day < d.day;
        })
        .fold(0.0, (a, e) => a + e.amount);
    final daysInMonth = DateTime(d.year, d.month + 1, 0).day;
    final left = daysInMonth - d.day + 1;
    return max(0, (b - before) / left);
  }

  /// +10 XP pour chaque jour passé (3 derniers) sous la limite du jour. Une fois par jour.
  void _checkBudgetDays() {
    if (settings.monthlyBudget <= 0 || expenses.isEmpty) return;
    final first = expenses.map((e) => e.ts).reduce(min);
    for (var i = 1; i <= 3; i++) {
      final d = DateTime.now().subtract(Duration(days: i));
      final k = dayKey(d);
      if (DateTime(d.year, d.month, d.day).millisecondsSinceEpoch + 86400000 < first) continue;
      final reason = 'Budget tenu · ${d.day}/${d.month}';
      if (xpEvents.any((e) => e.reason == reason)) continue;
      final allow = dailyAllowance(k);
      if (allow > 0 && spentOn(k) <= allow) _gainXp(10, reason);
    }
  }

  Future<void> setMonthlyBudget(double v) async {
    settings.monthlyBudget = v;
    await commit();
  }

  /// Plafond mensuel d'une enveloppe (0 = pas d'enveloppe).
  double envelopeFor(String cat) => settings.envelopes[cat] ?? 0;

  /// Reste dans l'enveloppe ce mois-ci.
  double envelopeLeft(String cat, [DateTime? d]) => envelopeFor(cat) - (spentByCategory(d ?? DateTime.now())[cat] ?? 0);

  Future<void> setEnvelope(String cat, double v) async {
    if (v <= 0) {
      settings.envelopes.remove(cat);
    } else {
      settings.envelopes[cat] = v;
    }
    await commit();
  }

  /// Frais fixes d'un type (abonnement ou charge) : (index, nom, montant).
  List<(int, String, double)> fixedOf(String kind) => [
        for (var i = 0; i < settings.fixedCosts.length; i++)
          if (settings.fixedCosts[i].split('|').first == kind)
            (
              i,
              settings.fixedCosts[i].split('|').elementAtOrNull(1) ?? '',
              double.tryParse(settings.fixedCosts[i].split('|').elementAtOrNull(2) ?? '') ?? 0,
            ),
      ];

  double fixedTotal([String? kind]) => [
        if (kind == null) ...[...fixedOf('abonnement'), ...fixedOf('charge')] else ...fixedOf(kind),
      ].fold(0.0, (a, f) => a + f.$3);

  /// Ajoute (index null), modifie ou supprime (nom vide) un frais fixe.
  Future<void> setFixedCost(int? index, String kind, String name, double amount) async {
    final line = '$kind|${name.replaceAll('|', ' ')}|$amount';
    if (index == null) {
      if (name.trim().isNotEmpty) settings.fixedCosts.add(line);
    } else if (name.trim().isEmpty) {
      settings.fixedCosts.removeAt(index);
    } else {
      settings.fixedCosts[index] = line;
    }
    await commit();
  }

  Future<void> applyFixedPlan() async {
    settings.fixedCosts = List<String>.from(Expense.fixedPlan);
    await commit();
  }

  /// Applique le plan : enveloppes par catégorie et budget du mois = leur somme.
  Future<void> applyBudgetPlan() async {
    settings.envelopes = Map<String, double>.from(Expense.plan);
    if (settings.fixedCosts.isEmpty) settings.fixedCosts = List<String>.from(Expense.fixedPlan);
    settings.monthlyBudget = Expense.plan.values.fold(0.0, (a, v) => a + v);
    await commit();
  }

  Future<void> addExpense(Expense e) async {
    expenses.add(e);
    await commit();
  }

  Future<void> removeExpense(Expense e) async {
    e.removed = true;
    await commit();
  }

  // ---------- Mode occupée ----------

  Pause? get activePause {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final p in pauses) {
      if (p.activeAt(now)) return p;
    }
    return null;
  }

  Future<void> startPause(String label, DateTime? until) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final p in pauses) {
      if (p.activeAt(now)) p.end = now;
    }
    pauses.add(Pause(start: now, end: until?.millisecondsSinceEpoch ?? 0, label: label));
    await commit();
  }

  Future<void> stopPause() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final p in pauses) {
      if (p.activeAt(now)) p.end = now;
    }
    await commit();
  }

  /// Vrai si un check-in à cette heure tombe pendant une pause.
  bool pausedAt(DateTime t) {
    final ts = t.millisecondsSinceEpoch;
    return pauses.any((p) => p.activeAt(ts));
  }

  // ---------- Carnet manuscrit ----------

  List<NoteMeta> get liveNotes => notes.where((n) => !n.removed).toList()..sort((a, b) => b.mod.compareTo(a.mod));

  NoteMeta noteFor(String day, String kind) {
    for (final n in notes) {
      if (n.day == day && n.kind == kind && !n.removed) return n;
    }
    // ajoutée au carnet seulement quand on écrit dessus
    return NoteMeta(day: day, kind: kind, title: '${NoteMeta.kinds[kind] ?? 'Page'} du ${parseDay(day).day}/${parseDay(day).month}');
  }
}
