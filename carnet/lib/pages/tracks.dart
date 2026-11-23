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
// Page de gauche : les suivis du soir, en 30 secondes
// =====================================================================
class TonightPage extends StatelessWidget {
  final String day;
  const TonightPage({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final d = parseDay(day);
    final list = store.activeTrackers;
    final habits = store.activeHabits;
    final filled = list.where((t) {
          final v = store.tval(day, t.id);
          return v != null && v != 0 && v != '';
        }).length +
        habits.where((h) => store.log(day).habits.contains(h.id)).length;
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageTitle(
          id: 'trk.L',
          over: 'suivis · {jour} {n}',
          title: 'Comment ça va ?',
          vars: dayVars(d),
        ),
        Row(children: [
          Expanded(child: Text('$filled sur ${list.length + habits.length} · touche ce qui compte, laisse le reste vide', style: body(11.5, pal.soft, w: FontWeight.w700))),
          TextButton.icon(onPressed: () => manageTrackers(context), icon: const Icon(Icons.tune_rounded, size: 16), label: const Text('mes suivis')),
        ]),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, box) {
          final w = (box.maxWidth - 10) / 2;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final t in list) SizedBox(width: t.type == 'text' ? box.maxWidth : w, child: TrackerCard(day: day, t: t)),
            for (final h in habits)
              SizedBox(
                width: w,
                child: _Card(
                  name: '${h.emoji} ${h.name}',
                  color: Color(trackerColors[(h.order.toInt()) % trackerColors.length]),
                  note: '${store.habitDaysBetween(h.id, mondayOf(d), 7)}/${h.perWeek} sem.',
                  child: _YesNo(
                    value: store.log(day).habits.contains(h.id) ? true : null,
                    color: Color(trackerColors[(h.order.toInt()) % trackerColors.length]),
                    onChanged: (v) => store.setPetal(day, 'h:${h.id}', v == true),
                  ),
                ),
              ),
          ]);
        }),
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  final String name;
  final Color color;
  final Widget child;
  final String? note;
  const _Card({required this.name, required this.color, required this.child, this.note});
  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: BoxDecoration(color: pal.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: pal.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(name, style: hand(19, pal.ink), overflow: TextOverflow.ellipsis)),
          if (note != null) Text(note!, style: body(10.5, pal.soft, w: FontWeight.w800)),
          const SizedBox(width: 6),
          Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        ]),
        const SizedBox(height: 6),
        child,
      ]),
    );
  }
}

class TrackerCard extends StatelessWidget {
  final String day;
  final Tracker t;
  const TrackerCard({super.key, required this.day, required this.t});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final v = store.tval(day, t.id);
    final c = Color(t.color);
    void set(dynamic x) => store.setTval(day, t.id, x);
    int iv() => v is num ? v.toInt() : 0;
    Widget child;
    String? note;
    switch (t.type) {
      case 'faces':
        child = FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Faces(value: iv(), onChanged: set));
      case 'scale':
        child = Dots(value: iv(), color: c, onChanged: set);
      case 'period':
        final cd = iv() > 0 ? store.cycleDay(day) : null;
        note = cd == null ? null : 'J$cd';
        child = Dots(value: iv(), n: 3, color: c, onChanged: set);
      case 'yesno':
        child = _YesNo(value: v is bool ? v : null, color: c, onChanged: set);
      case 'number':
        child = _Stepper(label: '${iv()}${t.unit.isEmpty ? '' : ' ${t.unit}'}', onMinus: () => set(max(0, iv() - 1)), onPlus: () => set(iv() + 1));
        if (t.unit == 'verres') {
          child = Wrap(spacing: 2, children: [
            for (var i = 1; i <= t.max; i++)
              GestureDetector(
                onTap: () => set(iv() == i ? i - 1 : i),
                child: Icon(i <= iv() ? Icons.local_drink_rounded : Icons.local_drink_outlined, size: 24, color: c),
              ),
          ]);
        }
      case 'duration':
        final step = t.max <= 0 ? 15 : t.max;
        child = _Stepper(label: iv() == 0 ? '—' : fmtMin(iv()), onMinus: () => set(max(0, iv() - step)), onPlus: () => set(iv() + step));
      default:
        child = HandField(value: v is String ? v : '', hint: '…', size: 22, maxLines: 2, onChanged: set);
    }
    return _Card(name: store.text('trk.n.${t.id}', t.name), color: c, note: note, child: child);
  }
}

class _YesNo extends StatelessWidget {
  final bool? value;
  final Color color;
  final ValueChanged<bool?> onChanged;
  const _YesNo({required this.value, required this.color, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    Widget b(String t, bool v) => GestureDetector(
          onTap: () => onChanged(value == v ? null : v),
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: value == v ? color : pal.tint.withValues(alpha: .5), borderRadius: BorderRadius.circular(999)),
            child: Text(t, style: body(13, value == v ? Colors.white : pal.ink, w: FontWeight.w800)),
          ),
        );
    return Row(children: [b('oui', true), b('non', false)]);
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final VoidCallback onMinus, onPlus;
  const _Stepper({required this.label, required this.onMinus, required this.onPlus});
  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    Widget r(IconData i, VoidCallback f) => InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: f,
          child: Container(width: 30, height: 30, decoration: BoxDecoration(color: pal.tint.withValues(alpha: .6), shape: BoxShape.circle), child: Icon(i, size: 18, color: pal.ink)),
        );
    return Row(children: [
      r(Icons.remove_rounded, onMinus),
      Expanded(child: Center(child: FittedBox(child: Text(label, style: titleFont(24, pal.ink))))),
      r(Icons.add_rounded, onPlus),
    ]);
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
          Text('Active ce qui t’aide. La fleur 🌸 : le suivi a ses pétales à colorier dans la semaine.', style: body(12, pal.soft, w: FontWeight.w700)),
          for (final g in trackerGroups.entries) ...[
            const SizedBox(height: 10),
            Label(g.value, pal.acc),
            for (final t in all.where((t) => t.group == g.key))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Container(width: 12, height: 12, decoration: BoxDecoration(color: Color(t.color), shape: BoxShape.circle)),
                title: Text(t.name, style: hand(20, pal.ink)),
                subtitle: Text(trackerTypes[t.type] ?? (t.type == 'period' ? 'flux 0 à 3' : t.type), style: body(11, pal.soft)),
                onTap: () async {
                  await editTracker(ctx, t);
                  setS(() {});
                },
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'Dans les fleurs',
                    onPressed: () async {
                      t.flower = !t.flower;
                      await store.touchTracker(t);
                      setS(() {});
                    },
                    icon: Icon(Icons.local_florist_rounded, color: t.flower ? Color(t.color) : pal.line),
                  ),
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
    ..active = true;
  await store.touchTracker(x);
}

// =====================================================================
// Page de droite : les fleurs à colorier (semaine ou mois)
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

class _Petal {
  final String key; // suivi (ou h:habitude, journal, mood)
  final String day;
  final Path path;
  final Color color;
  final bool on;
  final int mood;
  _Petal(this.key, this.day, this.path, this.color, this.on, {this.mood = 0});
}

class _Flower {
  final String name;
  final Offset c;
  final double r0, r1, w;
  final List<String> labels;
  final List<_Petal> petals;
  final int count;
  _Flower(this.name, this.c, this.r0, this.r1, this.w, this.labels, this.petals, this.count);
}

/// Les fleurs : un pétale par jour, à colorier au stylet (ou d'un toucher).
class FlowersPage extends StatefulWidget {
  final String day;
  final String pageKey; // pour lire l'encre de la page
  final bool month;
  final ValueChanged<bool> onView;
  const FlowersPage({super.key, required this.day, required this.pageKey, required this.month, required this.onView});
  @override
  State<FlowersPage> createState() => _FlowersPageState();
}

class _FlowersPageState extends State<FlowersPage> {
  static const top = 96.0; // hauteur réservée au titre
  static const pad = Offset(34, 30 + top); // décalage contenu → page (marges de PageSheet)
  int _lastInk = -1;
  Set<int> _covered = {};

  List<(String, String, Color)> _items(Store store) {
    final l = <(String, String, Color)>[];
    for (final t in store.activeTrackers.where((t) => t.flower && t.type != 'faces' && t.type != 'scale' && t.type != 'period')) {
      l.add((t.id, store.text('trk.n.${t.id}', t.name), Color(t.color)));
    }
    for (final h in store.activeHabits) {
      l.add(('h:${h.id}', h.name, Color(trackerColors[h.order.toInt() % trackerColors.length])));
    }
    l.add(('journal', 'Journal', const Color(0xFFB9A7C2)));
    return l.take(9).toList();
  }

  List<_Flower> _build(Store store) {
    final d = parseDay(widget.day);
    if (widget.month) {
      final first = DateTime(d.year, d.month, 1);
      final n = DateTime(d.year, d.month + 1, 0).day;
      const c = Offset(266, 330);
      final petals = <_Petal>[];
      var count = 0;
      for (var i = 0; i < n; i++) {
        final k = dayKey(first.add(Duration(days: i)));
        final m = store.logs[k]?.mood ?? 0;
        if (m > 0) count++;
        petals.add(_Petal('mood', k, petalPath(c, 44, 210, -90 + i * 360 / n, 180 / n * .9), m > 0 ? moodColors[m - 1] : Colors.transparent, m > 0, mood: m));
      }
      return [_Flower(niceMonth(monthKey(d)).toLowerCase(), c, 44, 210, 180 / n * .9, [for (var i = 0; i < n; i++) (i == 0 || (i + 1) % 5 == 0) ? '${i + 1}' : ''], petals, count)];
    }
    final mon = mondayOf(d);
    final items = _items(store);
    final out = <_Flower>[];
    for (var k = 0; k < items.length; k++) {
      final (key, name, color) = items[k];
      final c = Offset(89 + (k % 3) * 177.0, 92 + (k ~/ 3) * 228.0);
      final petals = <_Petal>[];
      var count = 0;
      for (var i = 0; i < 7; i++) {
        final dk = dayKey(mon.add(Duration(days: i)));
        final on = store.petalOn(dk, key);
        if (on) count++;
        petals.add(_Petal(key, dk, petalPath(c, 15, 68, -90 + i * 360 / 7, 22), color, on));
      }
      out.add(_Flower(name, c, 15, 68, 22, dayShort, petals, count));
    }
    return out;
  }

  /// Regarde l'encre de la page : un pétale colorié à la main devient « fait ».
  void _readInk(Store store, List<_Flower> fl) {
    final ink = store.inks[widget.pageKey];
    final mod = ink?.mod ?? 0;
    if (mod == _lastInk) return;
    _lastInk = mod;
    final covered = <int>{};
    final todo = <Future<void> Function()>[];
    var idx = 0;
    for (final f in fl) {
      for (final p in f.petals) {
        final i = idx++;
        if (ink == null) continue;
        var hits = 0;
        final colors = <int>[];
        for (final s in ink.strokes) {
          for (var j = 0; j + 2 < s.pts.length; j += 3) {
            final o = Offset(s.pts[j], s.pts[j + 1]) - pad;
            if (p.path.contains(o)) {
              hits++;
              colors.add(s.color);
            }
          }
        }
        for (final fill in ink.fills) {
          final b = p.path.getBounds().center;
          if (fill.contains(b + pad)) {
            hits += 10;
            colors.add(fill.color);
          }
        }
        if (hits >= 4) {
          covered.add(i);
          if (p.key == 'mood') {
            if (p.mood == 0) {
              final m = _nearestMood(colors);
              todo.add(() => store.setTval(p.day, 'mood', m));
            }
          } else if (!p.on) {
            todo.add(() => store.setPetal(p.day, p.key, true));
          }
        }
      }
    }
    _covered = covered;
    if (todo.isNotEmpty) {
      Future.microtask(() async {
        for (final f in todo) {
          await f();
        }
      });
    }
  }

  int _nearestMood(List<int> cols) {
    if (cols.isEmpty) return 3;
    final counts = <int, int>{};
    for (final c in cols) {
      final col = Color(c);
      var best = 0;
      var bd = double.infinity;
      for (var m = 0; m < moodColors.length; m++) {
        final mc = moodColors[m];
        final dd = pow(col.r - mc.r, 2) + pow(col.g - mc.g, 2) + pow(col.b - mc.b, 2);
        if (dd < bd) {
          bd = dd.toDouble();
          best = m;
        }
      }
      counts[best] = (counts[best] ?? 0) + 1;
    }
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return best + 1;
  }

  Future<void> _tap(Store store, List<_Flower> fl, Offset o) async {
    for (final f in fl) {
      for (final p in f.petals) {
        if (!p.path.contains(o)) continue;
        if (p.key == 'mood') {
          final m = await _pickMood(context, p.mood);
          if (m != null) await store.setTval(p.day, 'mood', m);
        } else {
          await store.setPetal(p.day, p.key, !p.on);
        }
        return;
      }
    }
  }

  Future<int?> _pickMood(BuildContext context, int cur) => showModalBottomSheet<int>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(spacing: 10, runSpacing: 10, children: [
              for (var m = 1; m <= 5; m++)
                ActionChip(
                  avatar: CircleAvatar(backgroundColor: moodColors[m - 1]),
                  label: Text(moodNames[m - 1]),
                  onPressed: () => Navigator.pop(ctx, m),
                ),
              if (cur > 0) ActionChip(label: const Text('effacer'), onPressed: () => Navigator.pop(ctx, 0)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final fl = _build(store);
    _readInk(store, fl);
    final d = parseDay(widget.day);
    final mon = mondayOf(d);
    return Stack(children: [
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        height: top,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            (widget.month ? 'humeur · ${niceMonth(monthKey(d)).toLowerCase()}' : 'semaine du ${mon.day} au ${mon.add(const Duration(days: 6)).day} ${monthNames[mon.add(const Duration(days: 6)).month - 1]}').toUpperCase(),
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
        ]),
      ),
      Positioned(
        left: 0,
        top: top,
        width: 532,
        height: 700,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (e) => _tap(store, fl, e.localPosition),
          child: CustomPaint(painter: _FlowerPainter(fl, _covered, pal, widget.month)),
        ),
      ),
      if (widget.month)
        Positioned(
          left: 0,
          right: 0,
          bottom: 44,
          child: Wrap(spacing: 14, runSpacing: 6, children: [
            for (var m = 0; m < 5; m++)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 14, height: 14, decoration: BoxDecoration(color: moodColors[m], shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(moodNames[m], style: hand(18, pal.ink)),
              ]),
          ]),
        )
      else
        Positioned(
          left: 0,
          right: 0,
          bottom: 44,
          child: Text('Colorie un pétale par jour au stylet (mode ✏️), ou touche-le. Ton suivi se remplit tout seul.', style: body(11.5, pal.soft, w: FontWeight.w700)),
        ),
    ]);
  }
}

class _FlowerPainter extends CustomPainter {
  final List<_Flower> fl;
  final Set<int> covered;
  final Pal pal;
  final bool month;
  _FlowerPainter(this.fl, this.covered, this.pal, this.month);

  void _text(Canvas c, String t, Offset at, TextStyle st) {
    final tp = TextPainter(text: TextSpan(text: t, style: st), textDirection: TextDirection.ltr, textAlign: TextAlign.center)..layout();
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = pal.ink.withValues(alpha: .55);
    var idx = 0;
    for (final f in fl) {
      for (var i = 0; i < f.petals.length; i++) {
        final p = f.petals[i];
        final cov = covered.contains(idx++);
        if (p.on && !cov) canvas.drawPath(p.path, Paint()..color = p.color.withValues(alpha: .6));
        canvas.drawPath(p.path, line);
        final lab = f.labels[i % f.labels.length];
        if (lab.isNotEmpty) {
          final a = (-90 + i * 360 / f.petals.length) * pi / 180;
          _text(canvas, lab, f.c + Offset(cos(a), sin(a)) * (f.r1 + 11), body(month ? 10 : 9, pal.soft, w: FontWeight.w800));
        }
      }
      canvas.drawCircle(f.c, f.r0 + 1, Paint()..color = pal.paper);
      canvas.drawCircle(f.c, f.r0 + 1, line);
      if (month) {
        _text(canvas, f.name, f.c - const Offset(0, 8), script(20, pal.acc));
        _text(canvas, '${f.count} / ${f.petals.length}', f.c + const Offset(0, 14), body(10, pal.soft, w: FontWeight.w800));
      } else {
        _text(canvas, '${f.count}', f.c, titleFont(15, pal.ink));
        _text(canvas, f.name, f.c + Offset(0, f.r1 + 32), hand(20, pal.ink));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FlowerPainter old) => true;
}
