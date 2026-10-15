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
  int plannedAt; // créneau prévu (ms), 0 = pas placé dans la journée
  int plannedMin; // durée du bloc prévu
  String condition; // « seulement quand… »
  int postponed; // nombre de reports du rappel
  String calEventId; // événement écrit dans l'agenda du téléphone
  int bossProgress; // boss : avancement déclaré, 0 à 100
  int progress; // avancement déclaré d'une tâche ou étape, 0 à 100
  bool inQuest; // étape de la quête du jour (sinon simple tâche pro ou perso)
  String hiddenDay; // « pas aujourd'hui » : masquée de « À caser » ce jour-là
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
    this.plannedAt = 0,
    this.plannedMin = 0,
    this.condition = '',
    this.postponed = 0,
    this.calEventId = '',
    this.bossProgress = 0,
    this.progress = 0,
    this.inQuest = false,
    this.hiddenDay = '',
    this.mod = 0,
  })  : id = id ?? newId(),
        createdDay = createdDay ?? day;

  int get blockMin => plannedMin > 0 ? plannedMin : (estimateMin > 0 ? estimateMin : 30);

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
        plannedAt: _i(j['at']),
        plannedMin: _i(j['atMin']),
        condition: _s(j['cond']),
        postponed: _i(j['post']),
        calEventId: _s(j['calEv']),
        bossProgress: _i(j['bossP']),
        progress: _i(j['prog']),
        // avant ce champ, toute tâche pro ou perso était une étape de quête
        inQuest: j.containsKey('inQ') ? _b(j['inQ']) : _s(j['category']).isNotEmpty,
        hiddenDay: _s(j['hid']),
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
        'at': plannedAt,
        'atMin': plannedMin,
        'cond': condition,
        'post': postponed,
        'calEv': calEventId,
        'bossP': bossProgress,
        'prog': progress,
        'inQ': inQuest,
        'hid': hiddenDay,
        'mod': mod,
      };
}

/// Un rappel « c'est l'heure » et la réponse donnée (corrigeable dans le journal).
class Remind {
  String id;
  String taskId;
  String title;
  int ts; // heure du rappel
  String answer; // go, +5, +10, +15, +30, plustard, demain, agenda, condition, bloque, annule, '' (sans réponse)
  String detail;
  int mod;

  Remind({String? id, required this.taskId, required this.title, required this.ts, this.answer = '', this.detail = '', this.mod = 0})
      : id = id ?? newId();

  static const labels = {
    '': 'Sans réponse',
    'go': 'Lancée',
    '+5': '+5 min',
    '+10': '+10 min',
    '+15': '+15 min',
    '+30': '+30 min',
    'plustard': 'Plus tard aujourd\'hui',
    'demain': 'Demain',
    'agenda': 'Agenda',
    'condition': 'Seulement quand…',
    'bloque': 'Ça bloque',
    'annule': 'Annulée',
  };

  factory Remind.fromJson(Map<String, dynamic> j) => Remind(
        id: _s(j['id']),
        taskId: _s(j['task']),
        title: _s(j['title']),
        ts: _i(j['ts']),
        answer: _s(j['answer']),
        detail: _s(j['detail']),
        mod: _i(j['mod']),
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'task': taskId, 'title': title, 'ts': ts, 'answer': answer, 'detail': detail, 'mod': mod};
}

class SessionRec {
  String id;
  String taskId;
  String title;
  int start;
  int end; // 0 = en cours
  int predictedMin;
  bool finished; // étape terminée (sinon interrompue)
  String category; // pro ou perso, vide = selon la tâche
  bool silent; // pas de check-in pendant la session
  int difficulty; // 0 = non évaluée, 1 facile, 2 correct, 3 dur
  int feeling; // 0 = non évalué, 1 pénible, 2 neutre, 3 agréable
  String helped;
  int interrupted; // -1 = pas demandé, 0 = non, 1 = une fois, 2 = plusieurs
  String hardWhat; // débrief : c'était dur en quoi
  String worthWhy; // débrief : pourquoi ça valait le coup
  String stim; // condition : '', seule, body, bruit, musique
  String atts; // réponses « où est ton attention » pendant la session : '0'..'3' (à fond → ailleurs)
  int focus; // concentration ressentie 1..5, 0 = pas dite
  int progFrom, progTo; // avancement de l'étape avant/après (0..100), -1 = non dit
  String target; // « à la fin de cette session, j'aurai… »
  int targetMet; // -1 = non dit, 0 non, 1 en partie, 2 oui
  String boosts; // relances « ça flotte » choisies, séparées par des virgules
  String stopWhy; // arrêtée pour un impératif pro (réunion…) : pas un décrochage
  int mod;

  static const attLabels = ['à fond', 'ça va', 'ça flotte', 'ailleurs'];

  /// Concentration suggérée d'après les réponses pendant la session (1..5), 0 si aucune.
  int get suggestedFocus {
    if (atts.isEmpty) return 0;
    final avg = atts.split('').map((c) => int.tryParse(c) ?? 1).reduce((a, b) => a + b) / atts.length;
    return (5 - avg * 4 / 3).round().clamp(1, 5);
  }

  int get progGain => progFrom < 0 || progTo < 0 ? 0 : (progTo - progFrom).clamp(0, 100);

  SessionRec({
    String? id,
    required this.taskId,
    required this.title,
    required this.start,
    this.end = 0,
    required this.predictedMin,
    this.finished = false,
    this.category = '',
    this.silent = true,
    this.difficulty = 0,
    this.feeling = 0,
    this.helped = '',
    this.interrupted = -1,
    this.hardWhat = '',
    this.worthWhy = '',
    this.stim = '',
    this.atts = '',
    this.focus = 0,
    this.progFrom = -1,
    this.progTo = -1,
    this.target = '',
    this.targetMet = -1,
    this.boosts = '',
    this.stopWhy = '',
    this.mod = 0,
  }) : id = id ?? newId();

  /// Minutes de vrai focus : 100 % sans interruption, 50 % une fois, 0 sinon.
  /// Les sessions d'avant le débrief comptent en entier.
  double get focusMin {
    if (end == 0) return 0;
    if (interrupted == 1) return actualMin / 2;
    if (interrupted >= 2) return 0;
    return actualMin;
  }

  static const stims = {'seule': 'Seule, silence', 'body': 'Avec quelqu\'un', 'bruit': 'Bruit blanc', 'musique': 'Musique'};

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
        category: _s(j['cat']),
        silent: j['silent'] != false,
        difficulty: _i(j['diff']),
        feeling: _i(j['feel']),
        helped: _s(j['helped']),
        interrupted: _i(j['intr'], -1),
        hardWhat: _s(j['hard']),
        worthWhy: _s(j['worth']),
        stim: _s(j['stim']),
        atts: _s(j['atts']),
        focus: _i(j['focus']),
        progFrom: _i(j['pFrom'], -1),
        progTo: _i(j['pTo'], -1),
        target: _s(j['target']),
        targetMet: _i(j['tMet'], -1),
        boosts: _s(j['boosts']),
        stopWhy: _s(j['stop']),
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
        'cat': category,
        'silent': silent,
        'diff': difficulty,
        'feel': feeling,
        'helped': helped,
        'intr': interrupted,
        'hard': hardWhat,
        'worth': worthWhy,
        'stim': stim,
        'atts': atts,
        'focus': focus,
        'pFrom': progFrom,
        'pTo': progTo,
        'target': target,
        'tMet': targetMet,
        'boosts': boosts,
        'stop': stopWhy,
        'mod': mod,
      };
}

/// Activités proposées au check-in.
class Act {
  static const pro = 'pro';
  static const perso = 'perso';
  static const quest = 'quest'; // ancien : quête (pro)
  static const other = 'other'; // ancien : autre tâche
  static const pause = 'pause';
  static const phone = 'phone';
  static const nothing = 'none';
  static const labels = {
    pro: 'Pro',
    perso: 'Perso',
    quest: 'Une quête',
    other: 'Autre tâche',
    pause: 'Pause',
    phone: 'Téléphone, écrans',
    nothing: 'Rien de précis',
  };
  static const choices = [pro, perso, pause, phone, nothing];
  static const hints = {
    pro: 'thèse, cours, mails de boulot…',
    perso: 'se préparer, ménage, courses, soi…',
  };
  static const presets = {
    pro: ['Rédaction', 'Analyses', 'Lecture', 'Mails', 'Réunion', 'Cours', 'Admin pro'],
    perso: ['Se préparer', 'Transport', 'Repas, cuisine', 'Ménage, courses', 'Sport', 'Repos', 'Social', 'Admin perso', 'Rendez-vous', 'Projet'],
  };

  /// Travail (pro) ou vie perso : du temps sur quelque chose de choisi.
  static bool isWork(String a) => a == pro || a == quest || a == other;
  static bool isOnTask(String a) => isWork(a) || a == perso;
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
  String taskId; // quête ou tâche en cours, si précisée
  String label; // activité libre (se préparer, transport…)
  int sinceMin; // depuis combien de minutes, -1 = non précisé
  String emotion; // le mot le plus juste (grille des émotions)
  String cause; // la tâche, mon corps, quelqu'un, je ne sais pas
  int mod;

  CheckIn({
    required this.ts,
    required this.activity,
    this.reason = '',
    this.mood = 0,
    this.energy = -1,
    this.note = '',
    this.taskId = '',
    this.label = '',
    this.sinceMin = -1,
    this.emotion = '',
    this.cause = '',
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
        taskId: _s(j['task']),
        label: _s(j['label']),
        sinceMin: _i(j['since'], -1),
        emotion: _s(j['emo']),
        cause: _s(j['cause']),
        mod: _i(j['mod']),
      );

  Map<String, dynamic> toJson() => {
        'mod': mod,
        'task': taskId,
        'label': label,
        'since': sinceMin,
        'emo': emotion,
        'cause': cause,
        'ts': ts,
        'act': activity,
        'why': reason,
        'mood': mood,
        'energy': energy,
        'note': note,
      };
}

/// Un créneau noté après coup (« de 9 h à 12 h, j'ai été improductive »).
class Slot {
  String id;
  int start;
  int end;
  String kind; // pro, perso, pause, phone, idle
  String title;
  int mood; // 0 = non renseignée, 1 à 5 (désagréable → agréable)
  int energy; // -1 = non renseignée, 0 à 100
  String emotion;
  String why;
  bool removed;
  int mod;

  Slot({
    String? id,
    required this.start,
    required this.end,
    required this.kind,
    this.title = '',
    this.mood = 0,
    this.energy = -1,
    this.emotion = '',
    this.why = '',
    this.removed = false,
    this.mod = 0,
  }) : id = id ?? newId();

  static const kinds = ['pro', 'perso', 'pause', 'phone', 'idle'];
  static const labels = {'pro': 'Pro', 'perso': 'Perso', 'pause': 'Pause', 'phone': 'Téléphone', 'idle': 'Improductive'};
  static const whys = ['Fatigue', 'Flou', 'Évitement', 'Quelqu\'un', 'Émotion', 'Je ne sais pas'];

  double get minutes => (end - start) / 60000.0;

  /// Catégorie pour les stats de temps (improductive = « rien de précis », jamais un échec).
  String get category => kind == 'idle' ? Act.nothing : kind;

  factory Slot.fromJson(Map<String, dynamic> j) => Slot(
        id: _s(j['id']),
        start: _i(j['start']),
        end: _i(j['end']),
        kind: _s(j['kind'], 'idle'),
        title: _s(j['title']),
        mood: _i(j['mood']),
        energy: _i(j['energy'], -1),
        emotion: _s(j['emo']),
        why: _s(j['why']),
        removed: _b(j['removed']),
        mod: _i(j['mod']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start,
        'end': end,
        'kind': kind,
        'title': title,
        'mood': mood,
        'energy': energy,
        'emo': emotion,
        'why': why,
        'removed': removed,
        'mod': mod,
      };
}

/// Un passage dans la cabane : avant / après, ce qui pesait, l'angle et le geste.
class CabinVisit {
  String id;
  int ts;
  int mood; // 1 à 5
  int energy; // 0 à 100, -1
  String emotion;
  int before; // intensité 0-10
  int after; // -1 = pas re-noté
  List<String> weights; // « culpabilité:pas assez avancé », « tristesse »
  String body;
  String origin; // corps, pensée, situation
  String angle;
  String gesture;
  String notes;
  int mod;

  CabinVisit({
    String? id,
    required this.ts,
    this.mood = 0,
    this.energy = -1,
    this.emotion = '',
    this.before = -1,
    this.after = -1,
    List<String>? weights,
    this.body = '',
    this.origin = '',
    this.angle = '',
    this.gesture = '',
    this.notes = '',
    this.mod = 0,
  })  : id = id ?? newId(),
        weights = weights ?? [];

  factory CabinVisit.fromJson(Map<String, dynamic> j) => CabinVisit(
        id: _s(j['id']),
        ts: _i(j['ts']),
        mood: _i(j['mood']),
        energy: _i(j['energy'], -1),
        emotion: _s(j['emo']),
        before: _i(j['before'], -1),
        after: _i(j['after'], -1),
        weights: ((j['weights'] as List?) ?? []).map((e) => e.toString()).toList(),
        body: _s(j['body']),
        origin: _s(j['origin']),
        angle: _s(j['angle']),
        gesture: _s(j['gesture']),
        notes: _s(j['notes']),
        mod: _i(j['mod']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ts': ts,
        'mood': mood,
        'energy': energy,
        'emo': emotion,
        'before': before,
        'after': after,
        'weights': weights,
        'body': body,
        'origin': origin,
        'angle': angle,
        'gesture': gesture,
        'notes': notes,
        'mod': mod,
      };
}

/// Repas, boissons et entrées libres.
class LogKind {
  static const meal = 'meal';
  static const energy = 'energy';
  static const coffee = 'coffee';
  static const pill = 'pill';
  static const free = 'free';
  static const calm = 'calm'; // geste de régulation (respiration, porte, exercice)
  static const labels = {
    meal: 'Repas',
    energy: 'Energy drink',
    coffee: 'Café',
    pill: 'Pilule',
    free: 'Note libre',
    calm: 'Coup de pouce',
  };
  static const qtyChoices = [0.25, 0.5, 0.75, 1.0];
  static String qtyLabel(double q) {
    if (q == 0.25) return '¼';
    if (q == 0.5) return '½';
    if (q == 0.75) return '¾';
    return q == q.roundToDouble() ? '${q.round()}' : '$q';
  }
}

class LogEntry {
  String id;
  int ts;
  String kind;
  String note;
  String photo;
  double qty; // quantité : 1 par défaut, ¼ ½ ¾ pour une pilule ou une canette
  int mod;

  LogEntry({String? id, required this.ts, required this.kind, this.note = '', this.photo = '', this.qty = 1, this.mod = 0})
      : id = id ?? newId();

  String get label => '${LogKind.labels[kind] ?? kind}${qty != 1 ? ' ${LogKind.qtyLabel(qty)}' : ''}';

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
        id: _s(j['id']),
        ts: _i(j['ts']),
        kind: _s(j['kind']),
        note: _s(j['note']),
        photo: _s(j['photo']),
        qty: (j['qty'] as num?)?.toDouble() ?? 1,
        mod: _i(j['mod']),
      );

  Map<String, dynamic> toJson() => {'id': id, 'ts': ts, 'kind': kind, 'note': note, 'photo': photo, 'qty': qty, 'mod': mod};
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
  int proGoalMin; // objectif de temps pro du jour, 0 = pas fixé
  String persoGoal; // objectif perso du jour (aller courir…)
  bool persoGoalDone;
  String spawn; // point de spawn de demain : le geste préparé ce soir
  int skin; // peau : -1 = non noté, 0 nette → 4 poussée
  String skinZones;
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
    this.proGoalMin = 0,
    this.persoGoal = '',
    this.persoGoalDone = false,
    this.spawn = '',
    this.skin = -1,
    this.skinZones = '',
    this.mod = 0,
  });

  static const skinLabels = ['nette', 'quelques boutons', 'moyen', 'beaucoup', 'poussée'];

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
        proGoalMin: _i(j['proGoal']),
        persoGoal: _s(j['persoGoal']),
        persoGoalDone: _b(j['persoDone']),
        spawn: _s(j['spawn']),
        skin: _i(j['skin'], -1),
        skinZones: _s(j['skinZ']),
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
        'proGoal': proGoalMin,
        'persoGoal': persoGoal,
        'persoDone': persoGoalDone,
        'spawn': spawn,
        'skin': skin,
        'skinZ': skinZones,
        'mod': mod,
      };
}

class XpEvent {
  int ts;
  int amount;
  String reason;
  XpEvent({required this.ts, required this.amount, required this.reason});
  // le feu de camp a changé de libellé (« · jour ») : même identifiant pour ne pas le compter deux fois
  String get id => '$ts|${reason.startsWith('Feu de camp') ? 'Feu de camp' : reason}|$amount';

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
  double monthlyBudget;
  List<String> projects; // projets perso précisés dans les check-ins (« ces apps »…)
  List<String> books; // pile de philo : « Titre|pages »
  String goodDaysLetter;
  List<String> contacts; // personnes à qui en parler
  List<String> library; // phrases gardées dans la cabane
  List<String> favAngles;
  String calendarId; // agenda du téléphone où écrire les blocs ('' = pas connecté)
  String calendarName;
  bool calendarRead; // afficher les événements de tous les agendas dans « Ma journée »

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
    this.monthlyBudget = 0,
    List<String>? projects,
    List<String>? books,
    this.goodDaysLetter = '',
    List<String>? contacts,
    List<String>? library,
    List<String>? favAngles,
    this.calendarId = '',
    this.calendarName = '',
    this.calendarRead = true,
  })  : projects = projects ?? [],
        books = books ?? [],
        contacts = contacts ?? [],
        library = library ?? [],
        favAngles = favAngles ?? [];

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
        monthlyBudget: (j['budget'] as num?)?.toDouble() ?? 0,
        projects: ((j['projects'] as List?) ?? []).map((e) => e.toString()).toList(),
        books: ((j['books'] as List?) ?? []).map((e) => e.toString()).toList(),
        goodDaysLetter: _s(j['letter']),
        contacts: ((j['contacts'] as List?) ?? []).map((e) => e.toString()).toList(),
        library: ((j['library'] as List?) ?? []).map((e) => e.toString()).toList(),
        favAngles: ((j['favAngles'] as List?) ?? []).map((e) => e.toString()).toList(),
        calendarId: _s(j['calId']),
        calendarName: _s(j['calName']),
        calendarRead: j['calRead'] != false,
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
        'budget': monthlyBudget,
        'projects': projects,
        'books': books,
        'letter': goodDaysLetter,
        'contacts': contacts,
        'library': library,
        'favAngles': favAngles,
        'calId': calendarId,
        'calName': calendarName,
        'calRead': calendarRead,
      };
}

/// Un objet de la maison de Micky (ou un accessoire qu'elle porte).
class GameObject {
  final String id;
  final String name;
  final String series; // salon, chambre, micky
  final String asset; // vide = illustration à venir
  final int rarity; // 1 commun, 2 rare, 3 épique
  final bool wall; // s'accroche au mur du fond
  final String flavor;
  const GameObject(this.id, this.name, this.series, this.asset, this.rarity, {this.wall = false, this.flavor = ''});

  bool get accessory => series == 'micky';
  String get rarityLabel => rarity == 3 ? 'ÉPIQUE' : rarity == 2 ? 'RARE' : 'COMMUN';
}

class Objects {
  static const all = [
    GameObject('panier', 'Panier douillet', 'salon', 'assets/objects/panier.png', 1, flavor: 'Micky y fait la sieste pendant tes sessions.'),
    GameObject('tapis', 'Tapis zigzag', 'salon', 'assets/objects/tapis.png', 1, flavor: 'Pour les roulades.'),
    GameObject('aquarium', 'Aquarium', 'salon', 'assets/objects/aquarium.png', 2, flavor: 'Le poisson s\'appelle Nathalie.'),
    GameObject('neon', 'Néon MICKY', 'salon', 'assets/objects/neon.png', 2, wall: true, flavor: 'Il clignote quand tu gagnes un pari.'),
    GameObject('disco', 'Boule disco', 'salon', 'assets/objects/disco.png', 2, wall: true, flavor: 'Soirée dansante après une journée parfaite.'),
    GameObject('canape', 'Canapé bleu', 'salon', 'assets/objects/canape.png', 1, flavor: 'Deux coussins, zéro poil. Pour l\'instant.'),
    GameObject('lampe', 'Lampe champignon', 'salon', 'assets/objects/lampe.png', 1, flavor: 'Lumière douce pour les soirs de feu de camp.'),
    GameObject('arbre', 'Arbre à chat', 'salon', 'assets/objects/arbre.png', 3, flavor: 'Le trône d\'observation.'),
    GameObject('chateau', 'Château en carton', 'salon', 'assets/objects/chateau.png', 3, flavor: 'Avec un drapeau. Évidemment.'),
    GameObject('lampe_etoile', 'Veilleuse étoile', 'chambre', 'assets/objects/lampe_etoile.png', 1, flavor: 'Pour les nuits de 7 h et plus.'),
    GameObject('lit', 'Lit à baldaquin', 'chambre', 'assets/objects/lit.png', 2, flavor: 'Un lit de princesse. Elle le mérite.'),
    GameObject('biblio', 'Bibliothèque', 'chambre', '', 2, wall: true, flavor: 'Tes articles préférés, en couleur.'),
    GameObject('noeud', 'Nœud papillon', 'micky', 'assets/objects/noeud.png', 1, flavor: 'Rose à pois. Chic.'),
    GameObject('lunettes', 'Lunettes de soleil', 'micky', '', 1, flavor: 'Pour les jours de zone d\'or.'),
    GameObject('echarpe', 'Écharpe rayée', 'micky', '', 2, flavor: 'Cyan et lime, comme l\'appli.'),
    GameObject('couronne', 'Couronne dorée', 'micky', 'assets/objects/couronne.png', 3, flavor: 'Réservée aux journées parfaites.'),
  ];

  static const seriesNames = {'salon': 'Salon', 'chambre': 'Chambre', 'micky': 'Garde-robe de Micky'};
  static const seriesOrder = ['salon', 'chambre', 'micky'];

  static GameObject? byId(String id) {
    for (final o in all) {
      if (o.id == id) return o;
    }
    return null;
  }

  static List<GameObject> inSeries(String s) => all.where((o) => o.series == s).toList();
}

/// Où est posé un objet dans la maison (case de la grille isométrique).
class Placement {
  String id; // identifiant de l'objet
  String room;
  int gx;
  int gy;
  int mod;
  Placement({required this.id, required this.room, required this.gx, required this.gy, this.mod = 0});

  factory Placement.fromJson(Map<String, dynamic> j) =>
      Placement(id: _s(j['id']), room: _s(j['room'], 'salon'), gx: _i(j['gx']), gy: _i(j['gy']), mod: _i(j['mod']));
  Map<String, dynamic> toJson() => {'id': id, 'room': room, 'gx': gx, 'gy': gy, 'mod': mod};
}

/// Butin des coffres : récompenses annexes (les objets viennent de [Objects]).
class Loot {
  static const rewards = [
    'Joker de série',
    'Thème doré pour 24 h',
    '+30 XP bonus',
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

/// Habitude à ancrer : un déclencheur, une version complète et une version mini.
class Habit {
  String id;
  String name;
  String cue; // « après mon café »
  String mini; // version minimale qui compte les jours difficiles
  int color;
  int reminderMin; // minutes depuis minuit, -1 = pas de rappel
  bool archived;
  String created;
  int order;
  int mod;

  Habit({
    String? id,
    required this.name,
    this.cue = '',
    this.mini = '',
    this.color = 0xFFB8FF3C,
    this.reminderMin = -1,
    this.archived = false,
    required this.created,
    this.order = 0,
    this.mod = 0,
  }) : id = id ?? newId();

  static const maxActive = 3;

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: _s(j['id']),
        name: _s(j['name']),
        cue: _s(j['cue']),
        mini: _s(j['mini']),
        color: _i(j['color'], 0xFFB8FF3C),
        reminderMin: _i(j['remind'], -1),
        archived: _b(j['archived']),
        created: _s(j['created']),
        order: _i(j['order']),
        mod: _i(j['mod']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cue': cue,
        'mini': mini,
        'color': color,
        'remind': reminderMin,
        'archived': archived,
        'created': created,
        'order': order,
        'mod': mod,
      };
}

/// Une coche d'habitude pour un jour : 0 = rien, 1 = version mini, 2 = complète.
class HabitLog {
  String habitId;
  String day;
  int level;
  int mod;

  HabitLog({required this.habitId, required this.day, required this.level, this.mod = 0});

  String get id => '$habitId|$day';

  factory HabitLog.fromJson(Map<String, dynamic> j) =>
      HabitLog(habitId: _s(j['habit']), day: _s(j['day']), level: _i(j['level']), mod: _i(j['mod']));

  Map<String, dynamic> toJson() => {'habit': habitId, 'day': day, 'level': level, 'mod': mod};
}

/// Retour sur un décrochage ou une tâche pas faite, sans jugement.
class Reflection {
  String id;
  int ts;
  String taskId;
  String title;
  String kind; // decroche, pasfaite
  List<String> reasons;
  String text;
  String ifCue;
  String thenDo;
  int mod;

  Reflection({
    String? id,
    required this.ts,
    this.taskId = '',
    this.title = '',
    required this.kind,
    List<String>? reasons,
    this.text = '',
    this.ifCue = '',
    this.thenDo = '',
    this.mod = 0,
  })  : id = id ?? newId(),
        reasons = reasons ?? [];

  static const suggestions = [
    'Trop flou, je ne savais pas par où commencer',
    'Trop gros d\'un coup',
    'Peur de mal faire',
    'Ennui, pas assez stimulant',
    'Pas l\'énergie',
    'Interrompue',
    'Je l\'ai oubliée',
    'Autre chose est devenu urgent',
    'Pas vraiment important finalement',
    'Émotion difficile',
  ];

  factory Reflection.fromJson(Map<String, dynamic> j) => Reflection(
        id: _s(j['id']),
        ts: _i(j['ts']),
        taskId: _s(j['task']),
        title: _s(j['title']),
        kind: _s(j['kind']),
        reasons: ((j['reasons'] as List?) ?? []).map((e) => e.toString()).toList(),
        text: _s(j['text']),
        ifCue: _s(j['if']),
        thenDo: _s(j['then']),
        mod: _i(j['mod']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ts': ts,
        'task': taskId,
        'title': title,
        'kind': kind,
        'reasons': reasons,
        'text': text,
        'if': ifCue,
        'then': thenDo,
        'mod': mod,
      };
}

/// Une dépense : montant, pourquoi, catégorie.
class Expense {
  String id;
  int ts;
  double amount;
  String why;
  String category;
  bool removed;
  int mod;

  Expense({String? id, required this.ts, required this.amount, this.why = '', this.category = 'autre', this.removed = false, this.mod = 0})
      : id = id ?? newId();

  static const categories = ['courses', 'resto', 'transport', 'loisirs', 'santé', 'maison', 'vêtements', 'autre'];
  static const labels = {
    'courses': 'Courses',
    'resto': 'Resto, café',
    'transport': 'Transport',
    'loisirs': 'Loisirs',
    'santé': 'Santé',
    'maison': 'Maison',
    'vêtements': 'Vêtements, soin',
    'autre': 'Autre',
  };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: _s(j['id']),
        ts: _i(j['ts']),
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        why: _s(j['why']),
        category: _s(j['cat'], 'autre'),
        removed: _b(j['removed']),
        mod: _i(j['mod']),
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'ts': ts, 'amount': amount, 'why': why, 'cat': category, 'removed': removed, 'mod': mod};
}
