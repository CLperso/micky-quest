import 'dart:math';

import 'package:flutter/material.dart';

import '../model.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

const trackerGroups = {'corps': 'Corps', 'tete': 'Tête', 'travail': 'Travail', 'moi': 'Moi'};
const trackerTypes = {
  'yesno': 'oui / non',
  'scale': '1 à 5',
  'faces': 'visages',
  'number': 'nombre',
  'duration': 'durée',
  'text': 'une ligne',
};
const trackerColors = [0xFFD7A6A8, 0xFFB0707A, 0xFFA9B8A0, 0xFFB9A7C2, 0xFFC6A26A, 0xFFA9BCD3];
const moodColors = [Color(0xFFC9B8D8), Color(0xFFD7C3B6), Color(0xFFEADCC0), Color(0xFFDDB3B6), Color(0xFFA9B8A0)];
const moodNames = ['dure', 'bof', 'neutre', 'bien', 'super'];

// =====================================================================
// Code couleur
// =====================================================================
const levelColors = [Color(0xFFD9CFCB), Color(0xFFEBA982), Color(0xFFE2C46B), Color(0xFF8FB58A)];
const levelNames = ['pas fait', 'un peu', 'bien · avancé', 'parfait · atteint'];

/// Une question du soir : une clé (suivi, h:habitude, wgoal), un titre, et des réponses.
class _Opt {
  final String label;
  final String? sub;
  final int? lvl; // couleur
  final Future<void> Function() pick;
  final bool on;
  _Opt(this.label, this.lvl, this.pick, {this.sub, this.on = false});
}

class _Q {
  final String key, title;
  final String? sub;
  final List<_Opt> opts;
  final Tracker? text; // question texte
  _Q(this.key, this.title, this.opts, {this.sub, this.text});
}

List<_Q> eveningQuestions(Store store, String day) {
  final qs = <_Q>[];
  final d = parseDay(day);
  final goal = store.weekGoal(d);
  if (goal.trim().isNotEmpty) {
    final cur = store.level(day, 'wgoal');
    qs.add(_Q('wgoal', 'Objectif de la semaine', sub: goal, [
      _Opt('atteint 🌿', 3, () => store.setWeekGoalDay(day, 3), on: cur == 3),
      _Opt('avancé', 2, () => store.setWeekGoalDay(day, 2), on: cur == 2),
      _Opt('pas aujourd’hui', 0, () => store.setWeekGoalDay(day, 0), on: cur == 0),
    ]));
  }
  for (final t in store.activeTrackers) {
    final name = store.text('trk.n.${t.id}', t.name);
    final v = store.tval(day, t.id);
    int iv() => v is num ? v.toInt() : -1;
    Future<void> set(dynamic x) => store.setTval(day, t.id, x);
    int lv(int n) {
      final m = t.low ? 6 - n : n;
      return m >= 4 ? 3 : (m == 3 ? 2 : (m == 2 ? 1 : 0));
    }

    switch (t.type) {
      case 'faces':
        qs.add(_Q(t.id, '$name aujourd’hui ?', [for (var n = 5; n >= 1; n--) _Opt(moodNames[n - 1], lv(n), () => set(n), on: iv() == n)]));
      case 'scale':
        final words = t.id == 'energy'
            ? ['à plat', 'basse', 'moyenne', 'bonne', 'à fond']
            : t.id == 'anxiety'
                ? ['calme', 'un peu', 'moyenne', 'tendue', 'très tendue']
                : ['1', '2', '3', '4', '5'];
        final order = t.low ? [1, 2, 3, 4, 5] : [5, 4, 3, 2, 1];
        qs.add(_Q(t.id, '$name ?', [for (final n in order) _Opt(words[n - 1], lv(n), () => set(n), on: iv() == n)]));
      case 'period':
        qs.add(_Q(t.id, '$name ?', [
          for (final (i, w) in const [(0, 'rien'), (1, 'léger'), (2, 'moyen'), (3, 'abondant')]) _Opt(w, null, () => set(i), on: iv() == i && (i > 0 || store.logs[day]?.vals['ans:period'] == true))
        ]));
      case 'yesno':
        qs.add(_Q(t.id, '$name ?', [_Opt('oui', 3, () => set(true), on: v == true), _Opt('non', 0, () => set(false), on: v == false)]));
      case 'number':
      case 'duration':
        final g = store.goalOf(t);
        final dur = t.type == 'duration';
        String f(int x) => dur ? fmtMin(x) : '$x';
        final u = dur ? '' : (t.unit.isEmpty ? '' : ' ${t.unit}');
        final a = max(1, (g * .6).ceil()), b = max(1, (g * .3).round());
        final cur = store.level(day, t.id);
        qs.add(_Q(t.id, '$name ?', [
          _Opt('${f(g)}$u et plus', 3, () => set(g), on: cur == 3),
          if (a < g) _Opt(a == g - 1 ? '${f(a)}$u' : '${f(a)} à ${f(dur ? g - 5 : g - 1)}$u', 2, () => set(a), on: cur == 2),
          if (b < a) _Opt(b == a - 1 || b == 1 && a <= 2 ? '${f(b)}$u' : 'un peu (${f(b)})', 1, () => set(b), on: cur == 1),
          _Opt(dur ? 'pas du tout' : 'presque rien', 0, () => set(0), on: cur == 0),
        ]));
      default:
        qs.add(_Q(t.id, '$name ?', const [], text: t));
    }
  }
  for (final h in store.activeHabits) {
    final cur = store.level(day, 'h:${h.id}');
    qs.add(_Q('h:${h.id}', '${h.emoji} ${h.name} ?', [
      _Opt('oui', 3, () => store.setHabitAnswer(day, h.id, true), on: cur == 3),
      _Opt('non', 0, () => store.setHabitAnswer(day, h.id, false), on: cur == 0),
    ]));
  }
  return qs;
}

bool _answered(Store store, String day, _Q q) {
  if (q.text != null) return '${store.tval(day, q.key) ?? ''}'.trim().isNotEmpty;
  return q.opts.any((o) => o.on);
}

// =====================================================================
// Page de gauche : les questions du soir, une à la fois
// =====================================================================
class EveningQuestions extends StatefulWidget {
  final String day;
  const EveningQuestions({super.key, required this.day});
  @override
  State<EveningQuestions> createState() => _EveningQuestionsState();
}

class _EveningQuestionsState extends State<EveningQuestions> {
  int? _i;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final d = parseDay(widget.day);
    final qs = eveningQuestions(store, widget.day);
    final done = [for (final q in qs) _answered(store, widget.day, q)];
    final firstOpen = done.indexWhere((x) => !x);
    _i ??= firstOpen < 0 ? qs.length : firstOpen;
    final i = _i!.clamp(0, qs.length);

    final bar = Row(children: [
      for (var k = 0; k < qs.length; k++)
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _i = k),
            child: Container(
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: k == i ? pal.acc : (store.level(widget.day, qs[k].key) is int ? levelColors[store.level(widget.day, qs[k].key)!] : (done[k] ? pal.acc2.withValues(alpha: .6) : pal.line)),
              ),
            ),
          ),
        ),
    ]);

    Widget head(String over, String title) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(over.toUpperCase(), style: body(11, pal.soft, w: FontWeight.w800).copyWith(letterSpacing: 2)),
          const SizedBox(height: 4),
          Text(title, style: titleFont(34, pal.ink)),
        ]);

    final top = Row(children: [
      Expanded(child: Text('${niceDay(d)} · le soir', style: body(11, pal.acc, w: FontWeight.w800))),
      TextButton.icon(onPressed: () => manageTrackers(context), icon: const Icon(Icons.tune_rounded, size: 16), label: const Text('mes suivis')),
    ]);

    if (i >= qs.length) {
      return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          top,
          head('${done.where((x) => x).length} sur ${qs.length}', 'Ta journée en couleurs'),
          const SizedBox(height: 10),
          bar,
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var k = 0; k < qs.length; k++)
              ActionChip(
                onPressed: () => setState(() => _i = k),
                avatar: CircleAvatar(backgroundColor: store.level(widget.day, qs[k].key) is int ? levelColors[store.level(widget.day, qs[k].key)!] : (done[k] ? pal.acc2 : Colors.transparent)),
                label: Text(qs[k].key == 'wgoal' ? 'objectif' : qs[k].title.replaceAll(' aujourd’hui ?', '').replaceAll(' ?', ''), style: hand(18, pal.ink)),
                backgroundColor: pal.card,
                side: BorderSide(color: pal.line),
              ),
          ]),
          const SizedBox(height: 18),
          Text('Touche un suivi pour changer ta réponse. Tu peux aussi tout raconter à Micky : elle répond à ta place et tu valides.', style: body(12, pal.soft, w: FontWeight.w700)),
        ]),
      );
    }

    final q = qs[i];
    Future<void> next() async {
      if (mounted) setState(() => _i = i + 1);
    }

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        top,
        head('${i + 1} sur ${qs.length}', q.title),
        if (q.sub != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(q.sub!, style: hand(22, pal.acc))),
        const SizedBox(height: 10),
        bar,
        const SizedBox(height: 16),
        if (q.text != null)
          HandField(
            value: '${store.tval(widget.day, q.key) ?? ''}',
            hint: 'une ligne…',
            size: 24,
            maxLines: 3,
            onChanged: (v) => store.setTval(widget.day, q.key, v),
          ),
        for (final o in q.opts)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                await o.pick();
                await Future.delayed(const Duration(milliseconds: 180));
                await next();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: o.on ? (o.lvl == null ? pal.tint : levelColors[o.lvl!]) : pal.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: o.lvl == null ? pal.line : levelColors[o.lvl!], width: 2),
                ),
                child: Row(children: [
                  Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, color: o.lvl == null ? pal.tint : levelColors[o.lvl!], border: Border.all(color: Colors.white, width: 2))),
                  const SizedBox(width: 12),
                  Expanded(child: Text(o.label, style: hand(23, pal.ink))),
                  if (o.lvl != null) Text(['pas fait', 'un peu', 'bien', 'parfait'][o.lvl!], style: body(11, pal.soft, w: FontWeight.w800)),
                ]),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Row(children: [
          if (i > 0) TextButton(onPressed: () => setState(() => _i = i - 1), child: const Text('← retour')),
          const Spacer(),
          TextButton(onPressed: next, child: Text(q.text != null ? 'suivant →' : 'passer')),
        ]),
      ]),
    );
  }
}

// =====================================================================
// Gérer la bibliothèque de suivis
// =====================================================================
Future<void> manageTrackers(BuildContext context) async {
  final store = StoreScope.read(context);
  final pal = Pal.byId(store.settings.theme);
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: pal.paper,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      final all = store.allTrackers;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        builder: (ctx, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(20, 16, 20, 30), children: [
          Text('Ce que je suis', style: titleFont(30, pal.ink)),
          Text('Active ce qui t’aide : chaque suivi actif est demandé le soir et a sa fleur. Touche un suivi pour régler ce qui est « parfait » pour toi.', style: body(12, pal.soft, w: FontWeight.w700)),
          for (final g in trackerGroups.entries) ...[
            const SizedBox(height: 10),
            Label(g.value, pal.acc),
            for (final t in all.where((t) => t.group == g.key))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Container(width: 12, height: 12, decoration: BoxDecoration(color: Color(t.color), shape: BoxShape.circle)),
                title: Text(t.name, style: hand(20, pal.ink)),
                subtitle: Text('${trackerTypes[t.type] ?? (t.type == 'period' ? 'flux 0 à 3' : t.type)}${t.type == 'number' ? ' · parfait : ${store.goalOf(t)} ${t.unit}' : t.type == 'duration' ? ' · parfait : ${fmtMin(store.goalOf(t))}' : ''}', style: body(11, pal.soft)),
                onTap: () async {
                  await editTracker(ctx, t);
                  setS(() {});
                },
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Switch(
                    value: t.active,
                    onChanged: (v) async {
                      t.active = v;
                      await store.touchTracker(t);
                      setS(() {});
                    },
                  ),
                ]),
              ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await editTracker(ctx, null);
              setS(() {});
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Créer un suivi'),
          ),
          const SizedBox(height: 6),
          Text('Les habitudes (Kannada…) se règlent dans Réglages et ont aussi leur fleur.', style: body(11.5, pal.soft, w: FontWeight.w600)),
        ]),
      );
    }),
  );
}

Future<void> editTracker(BuildContext context, Tracker? t) async {
  final store = StoreScope.read(context);
  final name = TextEditingController(text: t?.name ?? '');
  final unit = TextEditingController(text: t?.unit ?? '');
  final goal = TextEditingController(text: t == null ? '' : (t.type == 'duration' ? '${store.goalOf(t)}' : '${store.goalOf(t)}'));
  var type = t?.type ?? 'yesno';
  var group = t?.group ?? 'moi';
  var color = t?.color ?? trackerColors.first;
  final core = t != null && const ['mood', 'energy', 'period', 'work'].contains(t.id);
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(t == null ? 'Un nouveau suivi' : 'Modifier le suivi'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: name, autofocus: t == null, decoration: const InputDecoration(labelText: 'Nom')),
            const SizedBox(height: 10),
            if (!core) ...[
              const Text('Type'),
              Wrap(spacing: 6, children: [for (final e in trackerTypes.entries) ChoiceChip(label: Text(e.value), selected: type == e.key, onSelected: (_) => setS(() => type = e.key))]),
              if (type == 'number') TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unité (verres, pages…)')),
            ],
            if (type == 'number' || type == 'duration' || (t != null && (t.type == 'number' || t.type == 'duration')))
              TextField(
                controller: goal,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: (t?.type ?? type) == 'duration' ? 'Parfait = combien de minutes ?' : 'Parfait = combien ?', helperText: 'vert si atteint, jaune à 60 %, orange en dessous'),
              ),
            const SizedBox(height: 8),
            const Text('Famille'),
            Wrap(spacing: 6, children: [for (final e in trackerGroups.entries) ChoiceChip(label: Text(e.value), selected: group == e.key, onSelected: (_) => setS(() => group = e.key))]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final c in trackerColors)
                GestureDetector(
                  onTap: () => setS(() => color = c),
                  child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: Border.all(color: c == color ? Colors.black54 : Colors.transparent, width: 2))),
                ),
            ]),
          ]),
        ),
        actions: [
          if (t != null && !core) TextButton(onPressed: () => Navigator.pop(ctx, 'del'), child: const Text('Supprimer')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'ok'), child: const Text('OK')),
        ],
      ),
    ),
  );
  if (r == null) return;
  if (r == 'del' && t != null) {
    t.del = true;
    await store.touchTracker(t);
    return;
  }
  if (name.text.trim().isEmpty) return;
  final x = t ?? Tracker(name: '', flower: true);
  x
    ..name = name.text.trim()
    ..type = core ? x.type : type
    ..group = group
    ..color = color
    ..unit = unit.text.trim()
    ..max = type == 'duration' ? 15 : (type == 'number' ? 8 : x.max)
    ..goal = int.tryParse(goal.text.trim()) ?? x.goal
    ..active = true;
  await store.touchTracker(x);
}

// =====================================================================
// Page de droite : les fleurs, coloriées par tes réponses (code couleur)
// =====================================================================
/// Pétale en goutte entre r0 et r1, à l'angle a (degrés), demi-largeur w (degrés).
Path petalPath(Offset c, double r0, double r1, double a, double w) {
  double rad(double d) => d * pi / 180;
  Offset pol(double r, double deg) => c + Offset(r * cos(rad(deg)), r * sin(rad(deg)));
  final p0 = pol(r0, a), tip = pol(r1, a);
  final rm = (r0 + r1) * .62;
  final c1 = pol(rm, a - w), c2 = pol(rm, a + w);
  return Path()
    ..moveTo(p0.dx, p0.dy)
    ..quadraticBezierTo(c1.dx, c1.dy, tip.dx, tip.dy)
    ..quadraticBezierTo(c2.dx, c2.dy, p0.dx, p0.dy)
    ..close();
}


/// Les éléments qui ont une fleur : objectif de la semaine, suivis, habitudes, journal.
List<(String, String)> flowerItems(Store store, DateTime day) {
  final l = <(String, String)>[];
  if (store.weekGoal(day).trim().isNotEmpty) l.add(('wgoal', 'Objectif'));
  for (final t in store.activeTrackers.where((t) => t.type != 'period')) {
    l.add((t.id, store.text('trk.n.${t.id}', t.name)));
  }
  for (final h in store.activeHabits) {
    l.add(('h:${h.id}', h.name));
  }
  l.add(('journal', 'Journal'));
  return l;
}

class FlowersPage extends StatefulWidget {
  final String day;
  final bool month;
  final ValueChanged<bool> onView;
  const FlowersPage({super.key, required this.day, required this.month, required this.onView});
  @override
  State<FlowersPage> createState() => _FlowersPageState();
}

class _FlowersPageState extends State<FlowersPage> {
  String _monthKey = 'mood';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final d = parseDay(widget.day);
    final mon = mondayOf(d);
    final items = flowerItems(store, d);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
        (widget.month ? niceMonth(monthKey(d)).toLowerCase() : 'semaine du ${mon.day} au ${mon.add(const Duration(days: 6)).day} ${monthNames[mon.add(const Duration(days: 6)).month - 1]}').toUpperCase(),
        style: body(11, pal.soft, w: FontWeight.w800).copyWith(letterSpacing: 2),
      ),
      Row(children: [
        Text(widget.month ? 'Ma fleur du mois' : 'Mes fleurs', style: titleFont(32, pal.ink)),
        const SizedBox(width: 14),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [ButtonSegment(value: false, label: Text('Semaine')), ButtonSegment(value: true, label: Text('Mois'))],
          selected: {widget.month},
          onSelectionChanged: (v) => widget.onView(v.first),
        ),
      ]),
      if (widget.month)
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final (k, n) in items)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(label: Text(n), selected: _monthKey == k, onSelected: (_) => setState(() => _monthKey = k), visualDensity: VisualDensity.compact),
              ),
          ]),
        ),
      const SizedBox(height: 6),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          final List<_Flower> fl;
          if (widget.month) {
            final first = DateTime(d.year, d.month, 1);
            final n = DateTime(d.year, d.month + 1, 0).day;
            final r1 = min(box.maxWidth, box.maxHeight) / 2 - 22;
            final c = Offset(box.maxWidth / 2, box.maxHeight / 2);
            final name = items.firstWhere((e) => e.$1 == _monthKey, orElse: () => (_monthKey, '')).$2;
            fl = [
              _Flower(name, c, r1 * .2, r1, 180 / n * .9, [for (var i = 0; i < n; i++) (i == 0 || (i + 1) % 5 == 0) ? '${i + 1}' : ''], [
                for (var i = 0; i < n; i++) _Petal(store.level(dayKey(first.add(Duration(days: i))), _monthKey), petalPath(c, r1 * .2, r1, -90 + i * 360 / n, 180 / n * .9)),
              ]),
            ];
          } else {
            final shown = items.take(12).toList();
            final rows = max(1, (shown.length / 3).ceil());
            final cw = box.maxWidth / 3, ch = box.maxHeight / rows;
            final r1 = min(cw * .36, ch * .3);
            fl = [
              for (var k = 0; k < shown.length; k++)
                () {
                  final c = Offset(cw * (k % 3) + cw / 2, ch * (k ~/ 3) + ch * .42);
                  return _Flower(shown[k].$2, c, r1 * .24, r1, 22, dayShort, [
                    for (var i = 0; i < 7; i++) _Petal(store.level(dayKey(mon.add(Duration(days: i))), shown[k].$1), petalPath(c, r1 * .24, r1, -90 + i * 360 / 7, 22)),
                  ]);
                }(),
            ];
          }
          return CustomPaint(size: Size(box.maxWidth, box.maxHeight), painter: _FlowerPainter(fl, pal, widget.month));
        }),
      ),
      Wrap(spacing: 14, runSpacing: 4, children: [
        for (var lv = 3; lv >= 0; lv--)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 13, height: 13, decoration: BoxDecoration(color: levelColors[lv], shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(levelNames[lv], style: hand(17, pal.ink)),
          ]),
      ]),
      const SizedBox(height: 40),
    ]);
  }
}

class _Petal {
  final int? lvl;
  final Path path;
  _Petal(this.lvl, this.path);
}

class _Flower {
  final String name;
  final Offset c;
  final double r0, r1, w;
  final List<String> labels;
  final List<_Petal> petals;
  _Flower(this.name, this.c, this.r0, this.r1, this.w, this.labels, this.petals);
}

class _FlowerPainter extends CustomPainter {
  final List<_Flower> fl;
  final Pal pal;
  final bool month;
  _FlowerPainter(this.fl, this.pal, this.month);

  void _text(Canvas c, String t, Offset at, TextStyle st) {
    final tp = TextPainter(text: TextSpan(text: t, style: st), textDirection: TextDirection.ltr, textAlign: TextAlign.center)..layout(maxWidth: 170);
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = pal.ink.withValues(alpha: .7);
    for (final f in fl) {
      for (var i = 0; i < f.petals.length; i++) {
        final p = f.petals[i];
        if (p.lvl != null) canvas.drawPath(p.path, Paint()..color = levelColors[p.lvl!.clamp(0, 3)]);
        canvas.drawPath(p.path, line);
        final lab = f.labels[i % f.labels.length];
        if (lab.isNotEmpty) {
          final a = (-90 + i * 360 / f.petals.length) * pi / 180;
          _text(canvas, month ? lab : lab.substring(0, 1).toUpperCase(), f.c + Offset(cos(a), sin(a)) * (f.r1 + 10), body(month ? 10 : 9, pal.soft, w: FontWeight.w800));
        }
      }
      canvas.drawCircle(f.c, f.r0 + 1, Paint()..color = pal.paper);
      canvas.drawCircle(f.c, f.r0 + 1, line);
      if (month) {
        _text(canvas, f.name, f.c, script(20, pal.acc));
      } else {
        _text(canvas, f.name, f.c + Offset(0, f.r1 + 26), hand(19, pal.ink));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FlowerPainter old) => true;
}

/// Grille « ma semaine en couleurs » (page semaine).
class WeekColorGrid extends StatelessWidget {
  final DateTime monday;
  final void Function(String day) onOpenDay;
  const WeekColorGrid({super.key, required this.monday, required this.onOpenDay});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final days = [for (var i = 0; i < 7; i++) dayKey(monday.add(Duration(days: i)))];
    final items = flowerItems(store, monday).where((e) => e.$1 != 'journal').toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const SizedBox(width: 110),
        for (var i = 0; i < 7; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onOpenDay(days[i]),
              child: Center(child: Text(dayShort[i].substring(0, 1).toUpperCase(), style: body(11, pal.soft, w: FontWeight.w800))),
            ),
          ),
      ]),
      for (final (k, n) in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Row(children: [
            SizedBox(width: 110, child: Text(n, overflow: TextOverflow.ellipsis, style: hand(18, pal.ink))),
            for (final dk in days)
              Expanded(
                child: Center(
                  child: Builder(builder: (_) {
                    final lv = store.level(dk, k);
                    return Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: lv == null ? Colors.transparent : levelColors[lv.clamp(0, 3)],
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: lv == null ? pal.ink.withValues(alpha: .3) : levelColors[lv.clamp(0, 3)]),
                      ),
                    );
                  }),
                ),
              ),
          ]),
        ),
    ]);
  }
}
