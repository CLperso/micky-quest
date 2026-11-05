import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model.dart';

const _key = 'carnet_v1';
const _imgKey = 'carnet_img_v1';

class Store extends ChangeNotifier {
  late SharedPreferences _prefs;
  Settings settings = Settings();
  final Map<String, Entry> entries = {};
  final Map<String, DayLog> logs = {};
  final Map<String, Goal> goals = {};
  final Map<String, Habit> habits = {};
  final Map<String, Collection> colls = {};
  final Map<String, Deco> decos = {};
  final Map<String, InkPage> inks = {};
  final Map<String, PaperStyle> papers = {};
  final Map<String, DecoTemplate> templates = {};
  final Map<String, String> images = {}; // id → base64 (jpeg)
  final Map<String, int> imageMod = {};
  int timerStart = 0; // session de travail en cours (local)

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      final raw = _prefs.getString(_key);
      if (raw != null) _apply(jsonDecode(raw) as Map<String, dynamic>, replace: true);
      final s = _prefs.getString('${_key}_settings');
      if (s != null) settings = Settings.fromJson(jsonDecode(s) as Map<String, dynamic>);
      final im = _prefs.getString(_imgKey);
      if (im != null) {
        final m = jsonDecode(im) as Map<String, dynamic>;
        for (final e in m.entries) {
          final v = e.value as Map;
          images[e.key] = v['d'] as String;
          imageMod[e.key] = (v['mod'] as num).toInt();
        }
      }
      timerStart = _prefs.getInt('${_key}_timer') ?? 0;
    } catch (e) {
      debugPrint('Chargement : $e');
    }
    if (habits.isEmpty && goals.isEmpty && entries.isEmpty) _seed();
  }

  void _seed() {
    habits['h-kannada'] = Habit(id: 'h-kannada', name: 'Kannada', emoji: '🗣', perWeek: 5, order: 1);
    goals['g-these'] = Goal(id: 'g-these', title: 'Avancer la thèse', why: 'apporter quelque chose de juste sur l’alimentation émotionnelle', emoji: '🎓', color: 0xFF7FA99B, kind: 'pro', perWeek: 5, order: 1);
    goals['g-corps'] = Goal(id: 'g-corps', title: 'Courir', why: 'prendre soin de mon corps', emoji: '🏃', color: 0xFFE9B949, kind: 'perso', perWeek: 3, order: 2);
    colls['c-colloques'] = Collection(id: 'c-colloques', title: 'Colloques & candidatures', emoji: '🎤', color: 0xFFE8896B, order: 1);
    colls['c-sante'] = Collection(id: 'c-sante', title: 'Santé', emoji: '🌿', color: 0xFF7FA99B, order: 2);
    colls['c-idees'] = Collection(id: 'c-idees', title: 'Thèse · idées', emoji: '💡', color: 0xFFE9B949, order: 3);
    save();
  }

  Map<String, dynamic> _dump({bool withImages = false}) => {
        'v': 1,
        'entries': entries.values.map((e) => e.toJson()).toList(),
        'logs': logs.values.map((e) => e.toJson()).toList(),
        'goals': goals.values.map((e) => e.toJson()).toList(),
        'habits': habits.values.map((e) => e.toJson()).toList(),
        'colls': colls.values.map((e) => e.toJson()).toList(),
        'decos': decos.values.map((e) => e.toJson()).toList(),
        'inks': inks.values.map((e) => e.toJson()).toList(),
        'papers': papers.values.map((e) => e.toJson()).toList(),
        'tpl': templates.values.map((e) => e.toJson()).toList(),
        if (withImages) 'imgs': {for (final k in images.keys) k: {'d': images[k], 'mod': imageMod[k] ?? 0}},
        if (withImages) 'settings': settings.syncJson(),
      };

  List<Map<String, dynamic>> _list(Map<String, dynamic> j, String k) =>
      j[k] is List ? (j[k] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList() : [];

  /// Applique des données (chargement, ou fusion avec la synchro : le plus récent gagne).
  void _apply(Map<String, dynamic> j, {bool replace = false}) {
    void merge<T>(Map<String, T> into, List<Map<String, dynamic>> list, T Function(Map<String, dynamic>) from, String Function(T) id, int Function(T) mod) {
      for (final m in list) {
        final x = from(m);
        final cur = into[id(x)];
        if (replace || cur == null || mod(x) > mod(cur)) into[id(x)] = x;
      }
    }

    merge<Entry>(entries, _list(j, 'entries'), Entry.fromJson, (e) => e.id, (e) => e.mod);
    merge<DayLog>(logs, _list(j, 'logs'), DayLog.fromJson, (e) => e.id, (e) => e.mod);
    merge<Goal>(goals, _list(j, 'goals'), Goal.fromJson, (e) => e.id, (e) => e.mod);
    merge<Habit>(habits, _list(j, 'habits'), Habit.fromJson, (e) => e.id, (e) => e.mod);
    merge<Collection>(colls, _list(j, 'colls'), Collection.fromJson, (e) => e.id, (e) => e.mod);
    merge<Deco>(decos, _list(j, 'decos'), Deco.fromJson, (e) => e.id, (e) => e.mod);
    merge<InkPage>(inks, _list(j, 'inks'), InkPage.fromJson, (e) => e.id, (e) => e.mod);
    merge<PaperStyle>(papers, _list(j, 'papers'), PaperStyle.fromJson, (e) => e.id, (e) => e.mod);
    merge<DecoTemplate>(templates, _list(j, 'tpl'), DecoTemplate.fromJson, (e) => e.id, (e) => e.mod);
    if (j['imgs'] is Map) {
      for (final e in (j['imgs'] as Map).entries) {
        final v = e.value as Map;
        final m = (v['mod'] as num).toInt();
        if ((imageMod[e.key] ?? -1) < m) {
          images[e.key as String] = v['d'] as String;
          imageMod[e.key as String] = m;
        }
      }
    }
    if (j['settings'] is Map) {
      final s = Map<String, dynamic>.from(j['settings'] as Map);
      final m = (s['mod'] as num?)?.toInt() ?? 0;
      if (m > settings.mod) {
        settings.theme = (s['theme'] as String?) ?? settings.theme;
        if (s['pal'] is List) settings.palette = (s['pal'] as List).map((e) => (e as num).toInt()).toList();
        settings.mod = m;
      }
    }
  }

  Future<void> save() async {
    await _prefs.setString(_key, jsonEncode(_dump()));
    await _prefs.setString('${_key}_settings', jsonEncode(settings.toJson()));
    await _prefs.setInt('${_key}_timer', timerStart);
  }

  Future<void> saveImages() async {
    await _prefs.setString(_imgKey, jsonEncode({for (final k in images.keys) k: {'d': images[k], 'mod': imageMod[k] ?? 0}}));
  }

  Future<void> commit() async {
    notifyListeners();
    await save();
  }

  Map<String, dynamic> syncPayload() => _dump(withImages: true);

  Future<void> mergeRemote(Map<String, dynamic> j) async {
    _apply(j);
    await save();
    await saveImages();
    notifyListeners();
  }

  void refresh() => notifyListeners();

  // ---------- dates ----------
  String get todayKey => dayKey(DateTime.now());

  // ---------- lignes ----------
  List<Entry> _sorted(Iterable<Entry> l) => l.toList()..sort((a, b) => a.order.compareTo(b.order));

  List<Entry> dayEntries(String day) => _sorted(entries.values.where((e) => !e.del && e.when == day));
  List<Entry> monthEntries(String month) => _sorted(entries.values.where((e) => !e.del && e.when == month));
  List<Entry> somedayEntries() => _sorted(entries.values.where((e) => !e.del && e.isSomeday && !e.dropped));
  List<Entry> collEntries(String c) => _sorted(entries.values.where((e) => !e.del && e.coll == c));
  List<Entry> goalEntries(String g) => _sorted(entries.values.where((e) => !e.del && e.goal == g));

  /// Tâches d'avant restées ouvertes (à reprendre, sans dette : on choisit).
  List<Entry> leftovers() {
    final t = todayKey;
    return _sorted(entries.values.where((e) => !e.del && !e.done && !e.dropped && e.kind == 'task' && e.isDay && e.when.compareTo(t) < 0));
  }

  /// Ce qui était prévu pour ce mois-ci et pas encore fait.
  List<Entry> monthOpen(String month) => monthEntries(month).where((e) => !e.done && !e.dropped && e.kind == 'task').toList();

  Future<Entry> addEntry(String text, {String when = '', String kind = 'task', String coll = '', String goal = ''}) async {
    final e = Entry(text: text.trim(), when: when, kind: kind, coll: coll, goal: goal);
    entries[e.id] = e;
    await commit();
    return e;
  }

  Future<void> updateEntry(Entry e) async {
    e.mod = nowMs();
    await commit();
  }

  Future<void> toggleDone(Entry e) async {
    e.done = !e.done;
    if (e.done) e.dropped = false;
    await updateEntry(e);
  }

  Future<void> moveEntry(Entry e, String when) async {
    e.when = when;
    e.dropped = false;
    e.order = nowMs().toDouble();
    await updateEntry(e);
  }

  Future<void> dropEntry(Entry e) async {
    e.dropped = true;
    await updateEntry(e);
  }

  Future<void> deleteEntry(Entry e) async {
    e.del = true;
    await updateEntry(e);
  }

  Future<void> reorder(List<Entry> list, int from, int to) async {
    final l = [...list];
    final x = l.removeAt(from);
    l.insert(to.clamp(0, l.length), x);
    for (var i = 0; i < l.length; i++) {
      l[i].order = i.toDouble();
      l[i].mod = nowMs();
    }
    await commit();
  }

  // ---------- journées ----------
  DayLog log(String id) => logs.putIfAbsent(id, () => DayLog(id: id));

  Future<void> touchLog(DayLog l) async {
    l.mod = nowMs();
    await commit();
  }

  /// Jour du cycle (1 = premier jour des règles), ou null si pas de repère récent.
  int? cycleDay(String day) {
    var d = parseDay(day);
    for (var i = 0; i < 45; i++) {
      final k = dayKey(d);
      final prev = dayKey(d.subtract(const Duration(days: 1)));
      if ((logs[k]?.period ?? 0) > 0 && (logs[prev]?.period ?? 0) == 0) return i + 1;
      d = d.subtract(const Duration(days: 1));
    }
    return null;
  }

  // ---------- objectifs, habitudes, collections ----------
  List<Goal> get activeGoals => goals.values.where((g) => !g.del && !g.archived).toList()..sort((a, b) => a.order.compareTo(b.order));
  List<Habit> get activeHabits => habits.values.where((h) => !h.del && !h.archived).toList()..sort((a, b) => a.order.compareTo(b.order));
  List<Collection> get activeColls => colls.values.where((c) => !c.del).toList()..sort((a, b) => a.order.compareTo(b.order));

  int goalStepsBetween(String goalId, DateTime from, int days) {
    var n = 0;
    for (var i = 0; i < days; i++) {
      if (logs[dayKey(from.add(Duration(days: i)))]?.goals.contains(goalId) ?? false) n++;
    }
    return n;
  }

  int habitDaysBetween(String hid, DateTime from, int days) {
    var n = 0;
    for (var i = 0; i < days; i++) {
      if (logs[dayKey(from.add(Duration(days: i)))]?.habits.contains(hid) ?? false) n++;
    }
    return n;
  }

  int proBetween(DateTime from, int days) {
    var n = 0;
    for (var i = 0; i < days; i++) {
      n += logs[dayKey(from.add(Duration(days: i)))]?.proMin ?? 0;
    }
    return n;
  }

  // ---------- minuteur ----------
  int get timerMinutes => timerStart == 0 ? 0 : ((nowMs() - timerStart) / 60000).floor();

  Future<void> startTimer() async {
    timerStart = nowMs();
    await commit();
  }

  Future<int> stopTimer() async {
    final m = timerMinutes;
    final start = DateTime.fromMillisecondsSinceEpoch(timerStart);
    timerStart = 0;
    if (m > 0) {
      final l = log(dayKey(start));
      l.proMin += m;
      l.mod = nowMs();
    }
    await commit();
    return m;
  }

  // ---------- décoration ----------
  List<Deco> pageDecos(String page) => decos.values.where((d) => !d.del && d.page == page).toList()..sort((a, b) => a.z.compareTo(b.z));
  int topZ(String page) => pageDecos(page).fold(0, (a, d) => max(a, d.z)) + 1;

  final List<(String, String, String)> _undo = []; // (page, decos json, encre json)

  void snapshot(String page) {
    _undo.add((page, jsonEncode(pageDecos(page).map((d) => d.toJson()).toList()), jsonEncode(inks[page]?.toJson())));
    if (_undo.length > 60) _undo.removeAt(0);
  }

  bool get canUndo => _undo.isNotEmpty;

  Future<void> undo() async {
    if (_undo.isEmpty) return;
    final (page, dj, ij) = _undo.removeLast();
    final keep = (jsonDecode(dj) as List).map((e) => Deco.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final ids = keep.map((d) => d.id).toSet();
    for (final d in pageDecos(page)) {
      if (!ids.contains(d.id)) {
        d.del = true;
        d.mod = nowMs();
      }
    }
    for (final d in keep) {
      d.mod = nowMs();
      decos[d.id] = d;
    }
    final ink = jsonDecode(ij);
    if (ink is Map) {
      final p = InkPage.fromJson(Map<String, dynamic>.from(ink));
      p.mod = nowMs();
      inks[page] = p;
    } else if (inks[page] != null) {
      inks[page]!.strokes = [];
      inks[page]!.mod = nowMs();
    }
    await commit();
  }

  Future<Deco> addDeco(Deco d) async {
    snapshot(d.page);
    d.z = topZ(d.page);
    d.mod = nowMs();
    decos[d.id] = d;
    await commit();
    return d;
  }

  Future<void> touchDeco(Deco d, {bool save = true}) async {
    d.mod = nowMs();
    if (save) {
      await commit();
    } else {
      notifyListeners();
    }
  }

  Future<void> removeDeco(Deco d) async {
    snapshot(d.page);
    d.del = true;
    await touchDeco(d);
  }

  Future<void> toFront(Deco d, bool front) async {
    snapshot(d.page);
    final l = pageDecos(d.page);
    d.z = front ? l.fold(0, (a, x) => max(a, x.z)) + 1 : l.fold(0, (a, x) => min(a, x.z)) - 1;
    await touchDeco(d);
  }

  Future<String> addImage(String b64) async {
    final id = newId();
    images[id] = b64;
    imageMod[id] = nowMs();
    await saveImages();
    notifyListeners();
    return id;
  }

  // ---------- encre ----------
  InkPage ink(String page) => inks.putIfAbsent(page, () => InkPage(id: page));

  Future<void> touchInk(String page) async {
    ink(page).mod = nowMs();
    await commit();
  }

  // ---------- papier ----------
  PaperStyle paper(String page) {
    final p = papers[page];
    if (p != null) return p;
    final base = page.split(':').first;
    return papers['kind:$base'] ?? papers['default'] ?? PaperStyle(id: 'default');
  }

  Future<void> setPaper(String id, {int? color, String? pattern}) async {
    final cur = paper(id);
    final p = papers.putIfAbsent(id, () => PaperStyle(id: id, color: cur.color, pattern: cur.pattern));
    if (color != null) p.color = color;
    if (pattern != null) p.pattern = pattern;
    p.mod = nowMs();
    await commit();
  }

  // ---------- modèles et favoris ----------
  List<DecoTemplate> get favorites => templates.values.where((t) => !t.del && t.favorite).toList()..sort((a, b) => b.mod.compareTo(a.mod));
  List<DecoTemplate> get pageTemplates => templates.values.where((t) => !t.del && !t.favorite).toList()..sort((a, b) => a.name.compareTo(b.name));

  Future<void> saveFavorite(Deco d) async {
    final t = DecoTemplate(name: d.type, favorite: true, items: [d.toJson()]);
    templates[t.id] = t;
    await commit();
  }

  Future<void> saveTemplate(String name, String page) async {
    final t = DecoTemplate(name: name, items: pageDecos(page).map((d) => d.toJson()).toList());
    templates[t.id] = t;
    await commit();
  }

  Future<void> applyTemplate(DecoTemplate t, String page) async {
    snapshot(page);
    var z = topZ(page);
    for (final m in t.items) {
      final d = Deco.fromJson(m).copyTo(page, dx: t.favorite ? 20 : 0, dy: t.favorite ? 20 : 0);
      d.z = z++;
      decos[d.id] = d;
    }
    await commit();
  }

  Future<void> deleteTemplate(DecoTemplate t) async {
    t.del = true;
    t.mod = nowMs();
    await commit();
  }

  Future<void> touchSettings() async {
    settings.mod = nowMs();
    await commit();
  }
}

class StoreScope extends InheritedNotifier<Store> {
  const StoreScope({super.key, required Store store, required super.child}) : super(notifier: store);
  static Store of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
  static Store read(BuildContext c) => c.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
