import 'dart:math';

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDay(String k) {
  final p = k.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

final _rnd = Random();
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rnd.nextInt(1 << 20).toRadixString(36)}';

int _i(Object? v, [int d = 0]) => (v as num?)?.toInt() ?? d;
String _s(Object? v, [String d = '']) => (v as String?) ?? d;
bool _b(Object? v) => v == true;

/// Cases de la matrice d'Eisenhower.
class Quad {
  static const inbox = 'inbox';
  static const doNow = 'do';
  static const plan = 'plan';
  static const light = 'light';
  static const drop = 'drop';
  static const all = [doNow, plan, light, drop];
  static const titles = {
    doNow: 'Faire maintenant',
    plan: 'Planifier',
    light: 'Alléger',
    drop: 'Laisser tomber',
    inbox: 'À trier',
  };
  static const hints = {
    doNow: 'urgent et important',
    plan: 'important, pas urgent',
    light: 'vite fait ou à déléguer',
    drop: 'ni urgent ni important',
  };
}

class Task {
  String id;
  String title;
  String quad;
  String category; // pro, perso ou ''
  int estimateMin;
  bool done;
  int doneAt;
  String day; // jour où la tâche est prévue
  String createdDay;
  bool deferred; // reportée depuis la veille
  bool isBoss;
  int bossHp;
  bool removed;
  int order;
  int mod;

  Task({
    String? id,
    required this.title,
    this.quad = Quad.inbox,
    this.category = '',
    this.estimateMin = 0,
    this.done = false,
    this.doneAt = 0,
    required this.day,
    String? createdDay,
    this.deferred = false,
    this.isBoss = false,
    this.bossHp = 100,
    this.removed = false,
    this.order = 0,
    this.mod = 0,
  })  : id = id ?? newId(),
        createdDay = createdDay ?? day;

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: _s(j['id']),
        title: _s(j['title']),
        quad: _s(j['quad'], Quad.inbox),
        category: _s(j['category']),
        estimateMin: _i(j['est']),
        done: _b(j['done']),
        doneAt: _i(j['doneAt']),
        day: _s(j['day']),
        createdDay: _s(j['created']),
        deferred: _b(j['deferred']),
        isBoss: _b(j['boss']),
        bossHp: _i(j['hp'], 100),
        removed: _b(j['removed']),
        order: _i(j['order']),
        mod: _i(j['mod']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'quad': quad,
        'category': category,
        'est': estimateMin,
        'done': done,
        'doneAt': doneAt,
        'day': day,
        'created': createdDay,
        'deferred': deferred,
        'boss': isBoss,
        'hp': bossHp,
        'removed': removed,
        'order': order,
        'mod': mod,
      };
}

class SessionRec {
  String id;
  String taskId;
  String title;
  int start;
  int end; // 0 = en cours
  int predictedMin;
  bool finished; // étape terminée (sinon interrompue)
  int mod;

  SessionRec({
    String? id,
    required this.taskId,
    required this.title,
    required this.start,
    this.end = 0,
    required this.predictedMin,
    this.finished = false,
    this.mod = 0,
  }) : id = id ?? newId();

  double get actualMin => end == 0 ? 0 : (end - start) / 60000.0;
  bool get running => end == 0;

  /// Rapport réel ÷ prévu (1 = parfait).
  double get ratio => predictedMin <= 0 || end == 0 ? 0 : actualMin / predictedMin;
  bool get onTarget => finished && ratio >= 0.8 && ratio <= 1.2;

  factory SessionRec.fromJson(Map<String, dynamic> j) => SessionRec(
        id: _s(j['id']),
        taskId: _s(j['task']),
        title: _s(j['title']),
        start: _i(j['start']),
        end: _i(j['end']),
        predictedMin: _i(j['pred']),
        finished: _b(j['fin']),
        mod: _i(j['mod']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'task': taskId,
        'title': title,
        'start': start,
        'end': end,
        'pred': predictedMin,
        'fin': finished,
        'mod': mod,
      };
}

/// Activités proposées au check-in.
class Act {
  static const quest = 'quest';
  static const other = 'other';
  static const pause = 'pause';
  static const phone = 'phone';
  static const nothing = 'none';
  static const labels = {
    quest: 'Ma quête',
    other: 'Autre tâche',
    pause: 'Pause',
    phone: 'Téléphone, écrans',
    nothing: 'Rien de précis',
  };
  static const reasons = [
    'Ennui',
    'Bloquée',
    'Émotion pénible',
    'Téléphone',
    'Quelqu\'un',
    'Fatigue',
    'Faim',
    'Oubli',
  ];
}

class CheckIn {
  int ts;
  String activity;
  String reason;
  int mood; // 0 = non renseignée, 1 à 5
  int energy; // -1 = non renseignée, 0 à 100
  String note;
  int mod;

  CheckIn({
    required this.ts,
    required this.activity,
    this.reason = '',
    this.mood = 0,
    this.energy = -1,
    this.note = '',
    this.mod = 0,
  });

  String get id => '$ts';

  factory CheckIn.fromJson(Map<String, dynamic> j) => CheckIn(
        ts: _i(j['ts']),
        activity: _s(j['act']),
        reason: _s(j['why']),
        mood: _i(j['mood']),
        energy: _i(j['energy'], -1),
        note: _s(j['note']),
        mod: _i(j['mod']),
      );

  Map<String, dynamic> toJson() => {
        'mod': mod,
        'ts': ts,
        'act': activity,
        'why': reason,
        'mood': mood,
        'energy': energy,
        'note': note,
      };
}

/// Repas, boissons et entrées libres.
class LogKind {
  static const meal = 'meal';
  static const energy = 'energy';
  static const coffee = 'coffee';
  static const free = 'free';
  static const labels = {
    meal: 'Repas',
    energy: 'Energy drink',
    coffee: 'Café',
    free: 'Note libre',
  };
}

class LogEntry {
  String id;
  int ts;
  String kind;
  String note;
  String photo;
  int mod;

  LogEntry({String? id, required this.ts, required this.kind, this.note = '', this.photo = '', this.mod = 0})
      : id = id ?? newId();

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
        id: _s(j['id']),
        ts: _i(j['ts']),
        kind: _s(j['kind']),
        note: _s(j['note']),
        photo: _s(j['photo']),
        mod: _i(j['mod']),
      );

  Map<String, dynamic> toJson() => {'id': id, 'ts': ts, 'kind': kind, 'note': note, 'photo': photo, 'mod': mod};
}

class DayPlan {
  String day;
  String pro;
  String perso;
  String planIf;
  String planThen;
  bool briefingDone;
  bool eveningDone;
  String win;
  String brake;
  String tomorrow;
  int sleepH; // heures de sommeil × 2 (demi-heures), 0 = non renseigné
  int mod;

  DayPlan({
    required this.day,
    this.pro = '',
    this.perso = '',
    this.planIf = '',
    this.planThen = '',
    this.briefingDone = false,
    this.eveningDone = false,
    this.win = '',
    this.brake = '',
    this.tomorrow = '',
    this.sleepH = 0,
    this.mod = 0,
  });

  factory DayPlan.fromJson(Map<String, dynamic> j) => DayPlan(
        day: _s(j['day']),
        pro: _s(j['pro']),
        perso: _s(j['perso']),
        planIf: _s(j['if']),
        planThen: _s(j['then']),
        briefingDone: _b(j['brief']),
        eveningDone: _b(j['eve']),
        win: _s(j['win']),
        brake: _s(j['brake']),
        tomorrow: _s(j['tomorrow']),
        sleepH: _i(j['sleep']),
        mod: _i(j['mod']),
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'pro': pro,
        'perso': perso,
        'if': planIf,
        'then': planThen,
        'brief': briefingDone,
        'eve': eveningDone,
        'win': win,
        'brake': brake,
        'tomorrow': tomorrow,
        'sleep': sleepH,
        'mod': mod,
      };
}

class XpEvent {
  int ts;
  int amount;
  String reason;
  XpEvent({required this.ts, required this.amount, required this.reason});
  String get id => '$ts|$reason|$amount';

  factory XpEvent.fromJson(Map<String, dynamic> j) =>
      XpEvent(ts: _i(j['ts']), amount: _i(j['xp']), reason: _s(j['why']));
  Map<String, dynamic> toJson() => {'ts': ts, 'xp': amount, 'why': reason};
}

class Settings {
  int startHour;
  int endHour;
  int intervalMin;
  bool checkinsDuringSession;
  int briefingHour;
  int briefingMinute;
  int eveningHour;
  String cycleStart; // premier jour des dernières règles
  int cycleLength;
  String notionToken;
  String notionDb;
  String notionTitleProp;
  String notionDateProp;
  String syncRepo; // propriétaire/dépôt
  String syncToken;
  int lastSync;
  bool stylusOnly;

  Settings({
    this.startHour = 9,
    this.endHour = 21,
    this.intervalMin = 30,
    this.checkinsDuringSession = false,
    this.briefingHour = 8,
    this.briefingMinute = 30,
    this.eveningHour = 21,
    this.cycleStart = '',
    this.cycleLength = 28,
    this.notionToken = '',
    this.notionDb = '',
    this.notionTitleProp = 'Name',
    this.notionDateProp = 'Date',
    this.syncRepo = '',
    this.syncToken = '',
    this.lastSync = 0,
    this.stylusOnly = true,
  });

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        startHour: _i(j['start'], 9),
        endHour: _i(j['end'], 21),
        intervalMin: _i(j['interval'], 30),
        checkinsDuringSession: _b(j['duringSession']),
        briefingHour: _i(j['briefH'], 8),
        briefingMinute: _i(j['briefM'], 30),
        eveningHour: _i(j['eveH'], 21),
        cycleStart: _s(j['cycle']),
        cycleLength: _i(j['cycleLen'], 28),
        notionToken: _s(j['nToken']),
        notionDb: _s(j['nDb']),
        notionTitleProp: _s(j['nTitle'], 'Name'),
        notionDateProp: _s(j['nDate'], 'Date'),
        syncRepo: _s(j['syncRepo']),
        syncToken: _s(j['syncToken']),
        lastSync: _i(j['lastSync']),
        stylusOnly: j['stylusOnly'] != false,
      );

  Map<String, dynamic> toJson() => {
        'start': startHour,
        'end': endHour,
        'interval': intervalMin,
        'duringSession': checkinsDuringSession,
        'briefH': briefingHour,
        'briefM': briefingMinute,
        'eveH': eveningHour,
        'cycle': cycleStart,
        'cycleLen': cycleLength,
        'nToken': notionToken,
        'nDb': notionDb,
        'nTitle': notionTitleProp,
        'nDate': notionDateProp,
        'syncRepo': syncRepo,
        'syncToken': syncToken,
        'lastSync': lastSync,
        'stylusOnly': stylusOnly,
      };
}

/// Butin des coffres.
class Loot {
  static const items = [
    'Nœud papillon rose',
    'Couronne de chaton',
    'Lunettes de soleil',
    'Bonnet de laine',
    'Cape de sorcière',
    'Pelote dorée',
    'Coussin moelleux',
    'Souris en peluche',
    'Plume arc-en-ciel',
    'Collier à clochette',
    'Écharpe rayée',
    'Chapeau de pirate',
    'Plaid à carreaux',
    'Médaille d\'exploratrice',
    'Sac de croquettes de luxe',
    'Carton de rêve',
  ];
  static const rewards = [
    'Joker de série',
    'Thème doré pour 24 h',
    '+50 XP bonus',
  ];
}

/// Phase du cycle selon le jour.
String cyclePhase(int dayOfCycle, int length) {
  if (dayOfCycle <= 5) return 'règles';
  final ovulation = length - 14;
  if (dayOfCycle < ovulation - 1) return 'folliculaire';
  if (dayOfCycle <= ovulation + 1) return 'ovulation';
  return 'lutéale';
}

/// Période sans check-in (cours, sortie…), sans pénalité.
class Pause {
  String id;
  int start;
  int end; // 0 = jusqu'à réactivation
  String label;
  int mod;

  Pause({String? id, required this.start, this.end = 0, required this.label, this.mod = 0}) : id = id ?? newId();

  bool activeAt(int ts) => ts >= start && (end == 0 || ts < end);

  static const labels = ['Cours', 'Sortie', 'Rendez-vous', 'Repos', 'Sport', 'Autre'];

  factory Pause.fromJson(Map<String, dynamic> j) =>
      Pause(id: _s(j['id']), start: _i(j['start']), end: _i(j['end']), label: _s(j['label']), mod: _i(j['mod']));

  Map<String, dynamic> toJson() => {'id': id, 'start': start, 'end': end, 'label': label, 'mod': mod};
}

/// Page manuscrite (les traits sont stockés à part, fichier par page).
class NoteMeta {
  String id;
  String day;
  String kind; // briefing, soir, libre
  String title;
  int mod;
  bool removed;

  NoteMeta({String? id, required this.day, required this.kind, this.title = '', this.mod = 0, this.removed = false})
      : id = id ?? newId();

  static const kinds = {'briefing': 'Briefing', 'soir': 'Journal du soir', 'libre': 'Page libre'};

  factory NoteMeta.fromJson(Map<String, dynamic> j) => NoteMeta(
        id: _s(j['id']),
        day: _s(j['day']),
        kind: _s(j['kind'], 'libre'),
        title: _s(j['title']),
        mod: _i(j['mod']),
        removed: _b(j['removed']),
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'day': day, 'kind': kind, 'title': title, 'mod': mod, 'removed': removed};
}

/// Un trait de stylet : coordonnées normalisées par la largeur de la page, et pression.
class Stroke {
  int color;
  double width;
  bool highlighter;
  List<double> pts; // x, y, pression, x, y, pression…

  Stroke({required this.color, required this.width, this.highlighter = false, List<double>? pts}) : pts = pts ?? [];

  factory Stroke.fromJson(Map<String, dynamic> j) => Stroke(
        color: _i(j['c']),
        width: (j['w'] as num?)?.toDouble() ?? 2,
        highlighter: _b(j['h']),
        pts: ((j['p'] as List?) ?? []).map((e) => (e as num).toDouble()).toList(),
      );

  Map<String, dynamic> toJson() => {
        'c': color,
        'w': width,
        if (highlighter) 'h': true,
        'p': pts.map((v) => (v * 10000).round() / 10000).toList(),
      };
}
