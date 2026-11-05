import 'dart:math';

String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36) + Random().nextInt(1 << 30).toRadixString(36);
int nowMs() => DateTime.now().millisecondsSinceEpoch;

String two(int n) => n.toString().padLeft(2, '0');
String dayKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
String monthKey(DateTime d) => '${d.year}-${two(d.month)}';
DateTime parseDay(String k) => DateTime.parse(k);
DateTime parseMonth(String k) => DateTime.parse('$k-01');
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime mondayOf(DateTime d) => dateOnly(d).subtract(Duration(days: d.weekday - 1));

const monthNames = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
const dayNames = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const dayShort = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
String niceDay(DateTime d) => '${dayNames[d.weekday - 1]} ${d.day} ${monthNames[d.month - 1]}';
String niceMonth(String k) {
  final d = parseMonth(k);
  return '${cap(monthNames[d.month - 1])}${d.year != DateTime.now().year ? ' ${d.year}' : ''}';
}

String fmtMin(int m) => m >= 60 ? '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${two(m % 60)}'}' : '$m min';

String _s(dynamic v, [String d = '']) => v is String ? v : d;
int _i(dynamic v, [int d = 0]) => v is num ? v.toInt() : d;
double _d(dynamic v, [double d = 0]) => v is num ? v.toDouble() : d;
bool _b(dynamic v) => v == true;
List<String> _ls(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];

/// Une ligne du carnet : tâche (•), événement (○) ou note (–).
/// when : 'AAAA-MM-JJ' (un jour), 'AAAA-MM' (un mois), 'someday' (un jour / bientôt) ou '' (seulement dans une collection).
class Entry {
  String id;
  String text;
  String kind; // task, event, note
  bool done;
  bool dropped;
  String when;
  String coll;
  String goal;
  double order;
  int created;
  int mod;
  bool del;

  Entry({
    String? id,
    required this.text,
    this.kind = 'task',
    this.done = false,
    this.dropped = false,
    this.when = '',
    this.coll = '',
    this.goal = '',
    double? order,
    int? created,
    int? mod,
    this.del = false,
  })  : id = id ?? newId(),
        order = order ?? nowMs().toDouble(),
        created = created ?? nowMs(),
        mod = mod ?? nowMs();

  bool get isDay => when.length == 10;
  bool get isMonth => when.length == 7;
  bool get isSomeday => when == 'someday';
  String get symbol => kind == 'event' ? '○' : (kind == 'note' ? '–' : (done ? '✕' : '•'));

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        id: _s(j['id']),
        text: _s(j['text']),
        kind: _s(j['kind'], 'task'),
        done: _b(j['done']),
        dropped: _b(j['drop']),
        when: _s(j['when']),
        coll: _s(j['coll']),
        goal: _s(j['goal']),
        order: _d(j['order']),
        created: _i(j['created']),
        mod: _i(j['mod']),
        del: _b(j['del']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'kind': kind,
        'done': done,
        'drop': dropped,
        'when': when,
        'coll': coll,
        'goal': goal,
        'order': order,
        'created': created,
        'mod': mod,
        'del': del,
      };
}

/// Une journée : le matin, le soir, les trackers.
class DayLog {
  String id; // AAAA-MM-JJ, ou « w:AAAA-MM-JJ » pour le mot de la semaine (lundi)
  String intention;
  String win;
  String journal;
  int mood; // 0 = non dit, 1..5
  int energy; // 0..5
  int period; // 0 rien, 1 léger, 2 moyen, 3 abondant
  int proMin;
  List<String> habits; // habitudes faites
  List<String> goals; // objectifs avancés (un pas)
  int mod;
  bool del;

  DayLog({
    required this.id,
    this.intention = '',
    this.win = '',
    this.journal = '',
    this.mood = 0,
    this.energy = 0,
    this.period = 0,
    this.proMin = 0,
    List<String>? habits,
    List<String>? goals,
    int? mod,
    this.del = false,
  })  : habits = habits ?? [],
        goals = goals ?? [],
        mod = mod ?? 0;

  bool get empty => intention.isEmpty && win.isEmpty && journal.isEmpty && mood == 0 && energy == 0 && period == 0 && proMin == 0 && habits.isEmpty && goals.isEmpty;

  factory DayLog.fromJson(Map<String, dynamic> j) => DayLog(
        id: _s(j['id']),
        intention: _s(j['int']),
        win: _s(j['win']),
        journal: _s(j['jour']),
        mood: _i(j['mood']),
        energy: _i(j['en']),
        period: _i(j['per']),
        proMin: _i(j['pro']),
        habits: _ls(j['hab']),
        goals: _ls(j['goals']),
        mod: _i(j['mod']),
        del: _b(j['del']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'int': intention,
        'win': win,
        'jour': journal,
        'mood': mood,
        'en': energy,
        'per': period,
        'pro': proMin,
        'hab': habits,
        'goals': goals,
        'mod': mod,
        'del': del,
      };
}

class Goal {
  String id;
  String title;
  String why;
  String emoji;
  int color;
  String kind; // pro, perso
  int perWeek;
  double order;
  bool archived;
  int mod;
  bool del;

  Goal({String? id, required this.title, this.why = '', this.emoji = '🎯', this.color = 0xFF7FA99B, this.kind = 'perso', this.perWeek = 3, double? order, this.archived = false, int? mod, this.del = false})
      : id = id ?? newId(),
        order = order ?? nowMs().toDouble(),
        mod = mod ?? nowMs();

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: _s(j['id']),
        title: _s(j['title']),
        why: _s(j['why']),
        emoji: _s(j['emoji'], '🎯'),
        color: _i(j['color'], 0xFF7FA99B),
        kind: _s(j['kind'], 'perso'),
        perWeek: _i(j['pw'], 3),
        order: _d(j['order']),
        archived: _b(j['arch']),
        mod: _i(j['mod']),
        del: _b(j['del']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'why': why,
        'emoji': emoji,
        'color': color,
        'kind': kind,
        'pw': perWeek,
        'order': order,
        'arch': archived,
        'mod': mod,
        'del': del,
      };
}

class Habit {
  String id;
  String name;
  String emoji;
  int perWeek;
  double order;
  bool archived;
  int mod;
  bool del;

  Habit({String? id, required this.name, this.emoji = '🌱', this.perWeek = 7, double? order, this.archived = false, int? mod, this.del = false})
      : id = id ?? newId(),
        order = order ?? nowMs().toDouble(),
        mod = mod ?? nowMs();

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: _s(j['id']),
        name: _s(j['name']),
        emoji: _s(j['emoji'], '🌱'),
        perWeek: _i(j['pw'], 7),
        order: _d(j['order']),
        archived: _b(j['arch']),
        mod: _i(j['mod']),
        del: _b(j['del']),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'emoji': emoji, 'pw': perWeek, 'order': order, 'arch': archived, 'mod': mod, 'del': del};
}

class Collection {
  String id;
  String title;
  String emoji;
  int color;
  String note;
  double order;
  int mod;
  bool del;

  Collection({String? id, required this.title, this.emoji = '📒', this.color = 0xFFE8896B, this.note = '', double? order, int? mod, this.del = false})
      : id = id ?? newId(),
        order = order ?? nowMs().toDouble(),
        mod = mod ?? nowMs();

  factory Collection.fromJson(Map<String, dynamic> j) => Collection(
        id: _s(j['id']),
        title: _s(j['title']),
        emoji: _s(j['emoji'], '📒'),
        color: _i(j['color'], 0xFFE8896B),
        note: _s(j['note']),
        order: _d(j['order']),
        mod: _i(j['mod']),
        del: _b(j['del']),
      );

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'emoji': emoji, 'color': color, 'note': note, 'order': order, 'mod': mod, 'del': del};
}

/// Un élément de décoration posé librement sur une page (coordonnées de page : 600 × 860).
class Deco {
  String id;
  String page;
  String type; // washi, sticker, image, emoji, frame, text
  double x, y, w, h, rot;
  int z;
  Map<String, dynamic> style;
  int mod;
  bool del;

  Deco({String? id, required this.page, required this.type, this.x = 300, this.y = 300, this.w = 120, this.h = 120, this.rot = 0, this.z = 0, Map<String, dynamic>? style, int? mod, this.del = false})
      : id = id ?? newId(),
        style = style ?? {},
        mod = mod ?? nowMs();

  Deco copyTo(String page, {double dx = 0, double dy = 0}) =>
      Deco(page: page, type: type, x: x + dx, y: y + dy, w: w, h: h, rot: rot, z: z, style: Map<String, dynamic>.from(style));

  factory Deco.fromJson(Map<String, dynamic> j) => Deco(
        id: _s(j['id']),
        page: _s(j['page']),
        type: _s(j['type'], 'emoji'),
        x: _d(j['x'], 300),
        y: _d(j['y'], 300),
        w: _d(j['w'], 120),
        h: _d(j['h'], 120),
        rot: _d(j['rot']),
        z: _i(j['z']),
        style: j['style'] is Map ? Map<String, dynamic>.from(j['style'] as Map) : {},
        mod: _i(j['mod']),
        del: _b(j['del']),
      );

  Map<String, dynamic> toJson() => {'id': id, 'page': page, 'type': type, 'x': x, 'y': y, 'w': w, 'h': h, 'rot': rot, 'z': z, 'style': style, 'mod': mod, 'del': del};
}

/// Un trait d'encre : points x, y, pression à la suite (coordonnées de page).
class Stroke {
  int color;
  double width;
  bool hl;
  List<double> pts;
  Stroke({required this.color, required this.width, this.hl = false, List<double>? pts}) : pts = pts ?? [];

  factory Stroke.fromJson(Map<String, dynamic> j) => Stroke(
        color: _i(j['c'], 0xFF3B3346),
        width: _d(j['w'], 2.4),
        hl: _b(j['h']),
        pts: j['p'] is List ? (j['p'] as List).map((e) => (e as num).toDouble()).toList() : [],
      );

  Map<String, dynamic> toJson() => {'c': color, 'w': width, 'h': hl, 'p': pts.map((e) => (e * 10).roundToDouble() / 10).toList()};
}

/// L'encre d'une page.
class InkPage {
  String id; // la clé de page
  List<Stroke> strokes;
  int mod;
  InkPage({required this.id, List<Stroke>? strokes, int? mod})
      : strokes = strokes ?? [],
        mod = mod ?? nowMs();

  factory InkPage.fromJson(Map<String, dynamic> j) => InkPage(
        id: _s(j['id']),
        strokes: j['s'] is List ? (j['s'] as List).map((e) => Stroke.fromJson(Map<String, dynamic>.from(e as Map))).toList() : [],
        mod: _i(j['mod']),
      );

  Map<String, dynamic> toJson() => {'id': id, 's': strokes.map((e) => e.toJson()).toList(), 'mod': mod};
}

/// Le papier d'une page (couleur et motif), ou « default ».
class PaperStyle {
  String id;
  int color;
  String pattern; // dots, lines, grid, plain
  int mod;
  PaperStyle({required this.id, this.color = 0xFFFBF7EF, this.pattern = 'dots', int? mod}) : mod = mod ?? nowMs();

  factory PaperStyle.fromJson(Map<String, dynamic> j) => PaperStyle(id: _s(j['id']), color: _i(j['color'], 0xFFFBF7EF), pattern: _s(j['pat'], 'dots'), mod: _i(j['mod']));
  Map<String, dynamic> toJson() => {'id': id, 'color': color, 'pat': pattern, 'mod': mod};
}

/// Modèle de décoration enregistré (favori : un seul élément ; modèle : une page entière).
class DecoTemplate {
  String id;
  String name;
  bool favorite;
  List<Map<String, dynamic>> items;
  int mod;
  bool del;
  DecoTemplate({String? id, required this.name, this.favorite = false, List<Map<String, dynamic>>? items, int? mod, this.del = false})
      : id = id ?? newId(),
        items = items ?? [],
        mod = mod ?? nowMs();

  factory DecoTemplate.fromJson(Map<String, dynamic> j) => DecoTemplate(
        id: _s(j['id']),
        name: _s(j['name']),
        favorite: _b(j['fav']),
        items: j['items'] is List ? (j['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList() : [],
        mod: _i(j['mod']),
        del: _b(j['del']),
      );
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'fav': favorite, 'items': items, 'mod': mod, 'del': del};
}

class Settings {
  String theme; // creme, nuit, sauge, rose
  List<int> palette;
  String syncRepo;
  String syncToken;
  int lastSync;
  bool stylusOnly;
  int mod;

  Settings({this.theme = 'creme', List<int>? palette, this.syncRepo = '', this.syncToken = '', this.lastSync = 0, this.stylusOnly = true, int? mod})
      : palette = palette ?? [0xFF3B3346, 0xFFE8896B, 0xFF7FA99B, 0xFFE9B949, 0xFFB9A7FF, 0xFFD9667A, 0xFF6FA8FF, 0xFFFFFFFF],
        mod = mod ?? 0;

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        theme: _s(j['theme'], 'creme'),
        palette: j['pal'] is List ? (j['pal'] as List).map((e) => (e as num).toInt()).toList() : null,
        syncRepo: _s(j['repo']),
        syncToken: _s(j['tok']),
        lastSync: _i(j['last']),
        stylusOnly: j['stylus'] == null ? true : _b(j['stylus']),
        mod: _i(j['mod']),
      );

  Map<String, dynamic> toJson() => {'theme': theme, 'pal': palette, 'repo': syncRepo, 'tok': syncToken, 'last': lastSync, 'stylus': stylusOnly, 'mod': mod};

  /// Ce qui se synchronise (pas le jeton ni l'état local).
  Map<String, dynamic> syncJson() => {'theme': theme, 'pal': palette, 'mod': mod};
}
