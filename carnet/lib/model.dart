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
  String tool; // stylo, plume, feutre, pinceau, crayon, surligneur
  List<double> pts; // x, y, pression (triplets)
  Stroke({required this.color, required this.width, String? tool, bool hl = false, List<double>? pts})
      : tool = tool ?? (hl ? 'surligneur' : 'stylo'),
        pts = pts ?? [];

  bool get hl => tool == 'surligneur';

  factory Stroke.fromJson(Map<String, dynamic> j) => Stroke(
        color: _i(j['c'], 0xFF3B3346),
        width: _d(j['w'], 2.4),
        tool: j['t'] is String ? j['t'] as String : (_b(j['h']) ? 'surligneur' : 'stylo'),
        pts: j['p'] is List ? (j['p'] as List).map((e) => (e as num).toDouble()).toList() : [],
      );

  Map<String, dynamic> toJson() => {'c': color, 'w': width, 't': tool, 'h': hl, 'p': pts.map((e) => (e * 10).roundToDouble() / 10).toList()};

  Stroke copy() => Stroke(color: color, width: width, tool: tool, pts: [...pts]);
}

/// Un calque d'aide posé sur une page (calligraphie, lettrage, grille, image…), qu'on peut cacher ou retirer.
class Guide {
  String page;
  String type; // calligraphie, lettrage, grille, iso, points, mandala, image
  double opacity;
  bool visible;
  String text, font; // lettrage
  double size, y, angle, spacing; // taille du lettrage / position / pente / interligne
  String img;
  int mod;
  bool del;
  Guide(
      {required this.page,
      this.type = 'calligraphie',
      this.opacity = 0.35,
      this.visible = true,
      this.text = 'Bonjour',
      this.font = 'script',
      this.size = 110,
      this.y = 0.3,
      this.angle = 55,
      this.spacing = 1,
      this.img = '',
      int? mod,
      this.del = false})
      : mod = mod ?? nowMs();

  factory Guide.fromJson(Map<String, dynamic> j) => Guide(
        page: _s(j['page']),
        type: _s(j['type'], 'calligraphie'),
        opacity: _d(j['op'], 0.35),
        visible: j['vis'] == null ? true : _b(j['vis']),
        text: _s(j['text'], 'Bonjour'),
        font: _s(j['font'], 'script'),
        size: _d(j['size'], 110),
        y: _d(j['y'], 0.3),
        angle: _d(j['angle'], 55),
        spacing: _d(j['sp'], 1),
        img: _s(j['img']),
        mod: _i(j['mod']),
        del: _b(j['del']),
      );
  Map<String, dynamic> toJson() =>
      {'page': page, 'type': type, 'op': opacity, 'vis': visible, 'text': text, 'font': font, 'size': size, 'y': y, 'angle': angle, 'sp': spacing, 'img': img, 'mod': mod, 'del': del};
}

/// Une page libre du carnet (journal, dessin, mind map…).
class FreePage {
  String id;
  String title;
  String paper; // dots, grid, lines, plain
  double order;
  int mod;
  bool del;
  FreePage({String? id, this.title = '', this.paper = 'dots', double? order, int? mod, this.del = false})
      : id = id ?? newId(),
        order = order ?? nowMs().toDouble(),
        mod = mod ?? nowMs();

  factory FreePage.fromJson(Map<String, dynamic> j) =>
      FreePage(id: _s(j['id']), title: _s(j['title']), paper: _s(j['paper'], 'dots'), order: _d(j['order']), mod: _i(j['mod']), del: _b(j['del']));
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'paper': paper, 'order': order, 'mod': mod, 'del': del};
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
  PaperStyle({required this.id, this.color = 0, this.pattern = 'dots', int? mod}) : mod = mod ?? nowMs();

  factory PaperStyle.fromJson(Map<String, dynamic> j) => PaperStyle(id: _s(j['id']), color: _i(j['color'], 0), pattern: _s(j['pat'], 'dots'), mod: _i(j['mod']));
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
  String theme; // rose, sauge, lavande, nuit
  List<int> palette;
  String syncRepo;
  String syncToken;
  int lastSync;
  bool stylusOnly;
  String titleStyle; // elegant, lettering, manuscrit
  double decoLevel; // 0 épuré · 1 doux · 2 kawaii
  String coverTitle, coverSub, coverStyle;
  String mickyTone; // discrete, douce, taquine, coach
  String labelStyle; // étiquettes des jours : tag, washi, souligne, cadre
  Map<String, String> labels; // textes personnalisés (titres, sous-titres…)
  List<String> hidden; // parties masquées
  int mod;

  static const defaultPalette = [0xFF4A3F3C, 0xFFB0707A, 0xFFD7A6A8, 0xFF7E9471, 0xFFA9B8A0, 0xFF8E7BA0, 0xFFC6A26A, 0xFF7C93AE, 0xFFE3B7A0, 0xFFFFFFFF];

  Settings(
      {this.theme = 'rose',
      List<int>? palette,
      this.syncRepo = '',
      this.syncToken = '',
      this.lastSync = 0,
      this.stylusOnly = true,
      this.titleStyle = 'elegant',
      this.decoLevel = 1,
      this.coverTitle = '2026 — 2027',
      this.coverSub = 'thèse, kannada & le reste',
      this.coverStyle = 'rose',
      this.mickyTone = 'taquine',
      this.labelStyle = 'tag',
      Map<String, String>? labels,
      List<String>? hidden,
      int? mod})
      : labels = labels ?? {},
        hidden = hidden ?? [],
        palette = palette ?? [...defaultPalette],
        mod = mod ?? 0;

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        theme: const ['rose', 'sauge', 'lavande', 'nuit'].contains(j['theme']) ? j['theme'] as String : 'rose',
        palette: j['pal'] is List && (j['pal'] as List).length >= 10 ? (j['pal'] as List).map((e) => (e as num).toInt()).toList() : null,
        syncRepo: _s(j['repo']),
        syncToken: _s(j['tok']),
        lastSync: _i(j['last']),
        stylusOnly: j['stylus'] == null ? true : _b(j['stylus']),
        titleStyle: _s(j['ts'], 'elegant'),
        decoLevel: _d(j['deco'], 1),
        coverTitle: _s(j['ct'], '2026 — 2027'),
        coverSub: _s(j['cs'], 'thèse, kannada & le reste'),
        coverStyle: _s(j['cv'], 'rose'),
        mickyTone: _s(j['mt'], 'taquine'),
        labelStyle: _s(j['ls'], 'tag'),
        labels: j['lb'] is Map ? (j['lb'] as Map).map((k, v) => MapEntry('$k', '$v')) : null,
        hidden: j['hd'] is List ? (j['hd'] as List).map((e) => '$e').toList() : null,
        mod: _i(j['mod']),
      );

  Map<String, dynamic> toJson() => {...syncJson(), 'repo': syncRepo, 'tok': syncToken, 'last': lastSync, 'stylus': stylusOnly};

  /// Ce qui se synchronise (pas le jeton ni l'état local).
  Map<String, dynamic> syncJson() => {
        'theme': theme,
        'pal': palette,
        'ts': titleStyle,
        'deco': decoLevel,
        'ct': coverTitle,
        'cs': coverSub,
        'cv': coverStyle,
        'mt': mickyTone,
        'ls': labelStyle,
        'lb': labels,
        'hd': hidden,
        'mod': mod,
      };

  void applySync(Map<String, dynamic> j) {
    final s = Settings.fromJson({...toJson(), ...j});
    theme = s.theme;
    palette = s.palette;
    titleStyle = s.titleStyle;
    decoLevel = s.decoLevel;
    coverTitle = s.coverTitle;
    coverSub = s.coverSub;
    coverStyle = s.coverStyle;
    mickyTone = s.mickyTone;
    labelStyle = s.labelStyle;
    labels = s.labels;
    hidden = s.hidden;
    mod = s.mod;
  }
}
