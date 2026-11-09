import 'package:flutter/material.dart';

import '../model.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

int isoWeek(DateTime d) {
  final thursday = d.add(Duration(days: 4 - d.weekday));
  final first = DateTime(thursday.year, 1, 1);
  return ((thursday.difference(first).inDays) / 7).floor() + 1;
}

/// Page de gauche de la semaine : la grille des trackers, remplie depuis le feu de camp.
class WeekGrid extends StatelessWidget {
  final DateTime monday;
  final void Function(String day) onOpenDay;
  const WeekGrid({super.key, required this.monday, required this.onOpenDay});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final days = [for (var i = 0; i < 7; i++) dayKey(monday.add(Duration(days: i)))];
    final logs = [for (final d in days) store.logs[d]];
    final today = store.todayKey;
    const faces = Faces.faces;

    Widget cell(Widget? w) => SizedBox(height: 30, child: Center(child: w ?? Text('·', style: body(14, pal.line))));
    Widget box(bool on, Color c) => Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(color: on ? c : Colors.transparent, borderRadius: BorderRadius.circular(5), border: Border.all(color: c, width: 2)),
        );

    final rows = <(String, List<Widget?>, String)>[];
    final per = logs.where((l) => (l?.period ?? 0) > 0).length;
    rows.add(('🩸 Règles', [for (final l in logs) (l?.period ?? 0) > 0 ? Text('🩸' * 1, style: TextStyle(fontSize: 10.0 + 4 * (l!.period))) : null], per == 0 ? '' : '$per j'));
    final moods = logs.where((l) => (l?.mood ?? 0) > 0).map((l) => l!.mood).toList();
    rows.add(('Humeur', [for (final l in logs) (l?.mood ?? 0) > 0 ? Text(faces[l!.mood - 1], style: const TextStyle(fontSize: 18)) : null],
        moods.isEmpty ? '' : 'plutôt ${faces[(moods.reduce((a, b) => a + b) / moods.length).round() - 1]}'));
    final ens = logs.where((l) => (l?.energy ?? 0) > 0).map((l) => l!.energy).toList();
    rows.add((
      'Énergie',
      [
        for (final l in logs)
          (l?.energy ?? 0) > 0
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 1; i <= 5; i++)
                    Container(width: 5, height: 5, margin: const EdgeInsets.all(0.6), decoration: BoxDecoration(shape: BoxShape.circle, color: i <= l!.energy ? pal.acc3 : pal.line)),
                ])
              : null
      ],
      ens.isEmpty ? '' : 'moy. ${(ens.reduce((a, b) => a + b) / ens.length).toStringAsFixed(1)}/5'
    ));
    final pro = store.proBetween(monday, 7);
    rows.add((
      'Temps pro',
      [
        for (final l in logs)
          (l?.proMin ?? 0) > 0
              ? Container(width: 14, height: (4 + (l!.proMin / 300) * 22).clamp(4, 26).toDouble(), decoration: BoxDecoration(color: pal.acc2, borderRadius: BorderRadius.circular(3)))
              : null
      ],
      pro == 0 ? '' : fmtMin(pro)
    ));
    for (final h in store.activeHabits) {
      rows.add(('${h.emoji} ${h.name}', [for (final l in logs) l == null ? null : box(l.habits.contains(h.id), pal.acc)], '${store.habitDaysBetween(h.id, monday, 7)}/${h.perWeek}'));
    }
    for (final g in store.activeGoals) {
      rows.add(('${g.emoji} ${g.title}', [for (final l in logs) l == null ? null : box(l.goals.contains(g.id), Color(g.color))], '${store.goalStepsBetween(g.id, monday, 7)}/${g.perWeek}'));
    }

    final wins = [for (var i = 0; i < 7; i++) if ((logs[i]?.win ?? '').trim().isNotEmpty) (dayShort[i], logs[i]!.win.trim())];
    final note = store.log('w:${days.first}');

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageTitle(over: 'semaine ${isoWeek(monday)} · ${monday.day} → ${monday.add(const Duration(days: 6)).day} ${monthNames[monday.add(const Duration(days: 6)).month - 1]}', title: 'Ma semaine'),
        Text('tout se remplit depuis le feu de camp', style: hand(20, pal.soft)),
        const SizedBox(height: 10),
        Table(
          columnWidths: const {0: FixedColumnWidth(122), 8: FixedColumnWidth(78)},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(children: [
              const SizedBox(),
              for (var i = 0; i < 7; i++)
                GestureDetector(
                  onTap: () => onOpenDay(days[i]),
                  child: Column(children: [
                    Text(dayShort[i], style: body(12, days[i] == today ? pal.acc : pal.soft, w: FontWeight.w900)),
                    Text('${monday.add(Duration(days: i)).day}', style: body(11, days[i] == today ? pal.acc : pal.soft)),
                  ]),
                ),
              Text('BILAN', style: body(10, pal.soft, w: FontWeight.w900)),
            ]),
            for (final r in rows)
              TableRow(children: [
                Text(r.$1, style: body(13, pal.ink, w: FontWeight.w800), overflow: TextOverflow.ellipsis),
                for (final w in r.$2) cell(w),
                Text(r.$3, style: hand(19, pal.ink)),
              ]),
          ],
        ),
        Label('Victoires de la semaine', pal.soft),
        if (wins.isEmpty) Text('elles apparaîtront ici, depuis tes soirs', style: hand(20, pal.soft)),
        for (final w in wins) Text('${w.$1} · ${w.$2}', style: hand(23, pal.ink)),
        Label('Un mot pour cette semaine', pal.soft),
        HandField(
          value: note.journal,
          hint: 'protéger mes matinées…',
          size: 26,
          color: pal.acc,
          onChanged: (v) {
            note.journal = v;
            store.touchLog(note);
          },
        ),
      ]),
    );
  }
}

/// Page de droite de la semaine : les jours et leurs lignes.
class WeekList extends StatelessWidget {
  final DateTime monday;
  final void Function(String day) onOpenDay;
  const WeekList({super.key, required this.monday, required this.onOpenDay});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < 7; i++)
          Builder(builder: (context) {
            final d = monday.add(Duration(days: i));
            final k = dayKey(d);
            final items = store.dayEntries(k);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                InkWell(
                  onTap: () => onOpenDay(k),
                  child: Text('${cap(dayNames[i])} ${d.day}', style: hand(26, k == store.todayKey ? pal.acc : pal.ink)),
                ),
                BulletList(items: items, onAdd: (t, kind) async => store.addEntry(t, when: k, kind: kind), hint: '+'),
              ]),
            );
          }),
      ]),
    );
  }
}

// ============================================================ semaine façon bullet journal

Map<String, String> weekVars(DateTime monday) {
  final sunday = monday.add(const Duration(days: 6));
  return {
    'semaine': '${isoWeek(monday)}',
    'Mois': cap(monthNames[monday.month - 1]),
    'mois': monthNames[monday.month - 1],
    'du': '${monday.day}',
    'au': '${sunday.day} ${monthNames[sunday.month - 1]}',
    'annee': '${monday.year}',
  };
}

/// Cadre « dessiné à la main ».
class SketchBox extends CustomPainter {
  final Color c;
  SketchBox(this.c);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..color = c.withValues(alpha: 0.75)
      ..strokeWidth = 1.4;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(1, 1, size.width - 2, size.height - 2), const Radius.circular(6)), p);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(2.5, 0.2, size.width - 4, size.height - 1.5), const Radius.circular(8)),
        p
          ..strokeWidth = 0.7
          ..color = c.withValues(alpha: 0.3));
  }

  @override
  bool shouldRepaint(SketchBox o) => o.c != c;
}

/// L'étiquette d'un jour, dans le style choisi.
class DayTag extends StatelessWidget {
  final String text;
  final Color color;
  const DayTag(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final caps = body(11.5, pal.ink, w: FontWeight.w800).copyWith(letterSpacing: 2.2);
    switch (store.settings.labelStyle) {
      case 'washi':
        return Transform.rotate(
          angle: -0.03,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.75),
              gradient: LinearGradient(colors: [color.withValues(alpha: .85), color.withValues(alpha: .55), color.withValues(alpha: .85)], stops: const [0, .5, 1]),
            ),
            child: Text(text.toUpperCase(), style: caps),
          ),
        );
      case 'souligne':
        return Container(
          padding: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: color, width: 3))),
          child: Text(text.toUpperCase(), style: caps),
        );
      case 'cadre':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: pal.paper, borderRadius: BorderRadius.circular(999), border: Border.all(color: color, width: 1.8)),
          child: Text(text.toUpperCase(), style: caps),
        );
      case 'script':
        return Container(color: pal.paper, padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(text, style: script(26, pal.ink)));
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: color,
          child: Text(text.toUpperCase(), style: caps),
        );
    }
  }
}

/// Une case de jour : étiquette, date, lignes du jour.
class DayBox extends StatelessWidget {
  final DateTime date;
  final Color color;
  final void Function(String day) onOpenDay;
  const DayBox({super.key, required this.date, required this.color, required this.onOpenDay});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final k = dayKey(date);
    final items = store.dayEntries(k);
    final isToday = k == store.todayKey;
    final name = store.text('week.day.${date.weekday}', dayNames[date.weekday - 1]);
    return InkTarget(
      onLines: (l) async {
        for (final t in l) {
          await store.addEntry(t, when: k);
        }
      },
      child: Stack(clipBehavior: Clip.none, children: [
      Positioned.fill(child: CustomPaint(painter: SketchBox(isToday ? pal.acc : pal.ink))),
      Positioned(
        left: 10,
        right: 34,
        top: 30,
        bottom: 4,
        child: ListView(padding: EdgeInsets.zero, children: [
          for (final e in items)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  GestureDetector(
                    onTap: () => store.toggleDone(e),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2, right: 6),
                      child: Text(e.done ? '×' : (e.kind == 'event' ? '○' : (e.kind == 'note' ? '–' : '•')), style: hand(22, e.done ? pal.acc : pal.ink)),
                    ),
                  ),
                  Expanded(
                    child: EntryText(
                        key: ValueKey('t${e.id}'),
                        e: e,
                        style: hand(21, e.done ? pal.soft : pal.ink).copyWith(decoration: e.done ? TextDecoration.lineThrough : null, decorationColor: pal.acc)),
                  ),
                  GestureDetector(
                    onTap: () => entryMenu(context, e),
                    child: Padding(padding: const EdgeInsets.only(top: 4), child: Icon(Icons.more_horiz_rounded, size: 16, color: pal.soft.withValues(alpha: .7))),
                  ),
                ]),
              ),
          AddLine(hint: '', onAdd: (t, kind) async => store.addEntry(t, when: k, kind: kind)),
        ]),
      ),
      Positioned(
        left: -6,
        top: -12,
        child: GestureDetector(
          onTap: () => onOpenDay(k),
          onLongPress: () => editTexts(context, [('week.day.${date.weekday}', 'Nom du jour', dayNames[date.weekday - 1])]),
          child: DayTag(name, color),
        ),
      ),
      Positioned(
        right: 8,
        top: 6,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(shape: BoxShape.circle, color: isToday ? pal.acc : pal.tint),
          child: Center(child: Text('${date.day}', style: hand(18, isToday ? Colors.white : pal.ink))),
        ),
      ),
    ]));
  }
}

class WeekLeft extends StatelessWidget {
  final DateTime monday;
  final void Function(String day) onOpenDay;
  const WeekLeft({super.key, required this.monday, required this.onOpenDay});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final tabs = pal.tabs;
    DateTime d(int i) => monday.add(Duration(days: i));
    final note = store.log('w:${dayKey(monday)}');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageTitle(id: 'week.L', over: 'semaine {semaine} · {du} – {au}', title: '{Mois}', vars: weekVars(monday)),
      const SizedBox(height: 22),
      Expanded(
        child: Row(children: [
          Expanded(child: DayBox(date: d(0), color: tabs[0], onOpenDay: onOpenDay)),
          const SizedBox(width: 14),
          Expanded(child: DayBox(date: d(1), color: tabs[1], onOpenDay: onOpenDay)),
        ]),
      ),
      const SizedBox(height: 22),
      Expanded(child: DayBox(date: d(2), color: tabs[2], onOpenDay: onOpenDay)),
      if (!store.isHidden('week.focus')) ...[
        const SizedBox(height: 16),
        Expanded(
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: SketchBox(pal.acc2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const ELabel('week.focus', 'Cette semaine', part: 'week.focus'),
                Expanded(
                  child: HandField(
                    value: note.journal,
                    hint: '…',
                    size: 23,
                    maxLines: 8,
                    onChanged: (v) {
                      note.journal = v;
                      store.touchLog(note);
                    },
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ],
    ]);
  }
}

class WeekRight extends StatelessWidget {
  final DateTime monday;
  final void Function(String day) onOpenDay;
  const WeekRight({super.key, required this.monday, required this.onOpenDay});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final tabs = pal.tabs;
    DateTime d(int i) => monday.add(Duration(days: i));
    final days = [for (var i = 0; i < 7; i++) dayKey(d(i))];
    final logs = [for (final k in days) store.logs[k]];

    Widget dot(bool on, Color c) => Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(shape: BoxShape.circle, color: on ? c : Colors.transparent, border: Border.all(color: on ? c : pal.ink.withValues(alpha: .35), width: 1.2)),
        );
    final rows = <(String, List<bool>, Color)>[
      if (!store.isHidden('trk.mood')) (store.text('trk.mood', 'Humeur'), [for (final l in logs) (l?.mood ?? 0) >= 4], pal.acc),
      if (!store.isHidden('trk.energy')) (store.text('trk.energy', 'Énergie'), [for (final l in logs) (l?.energy ?? 0) >= 3], pal.acc3),
      if (!store.isHidden('trk.pro')) (store.text('trk.pro', 'Travail'), [for (final l in logs) (l?.proMin ?? 0) > 0], pal.acc2),
      for (final h in store.activeHabits)
        if (!store.isHidden('trk.h.${h.id}')) (store.text('trk.h.${h.id}', '${h.emoji} ${h.name}'), [for (final l in logs) l?.habits.contains(h.id) ?? false], pal.acc),
      for (final g in store.activeGoals.where((g) => g.kind == 'perso'))
        if (!store.isHidden('trk.g.${g.id}')) (store.text('trk.g.${g.id}', '${g.emoji} ${g.title}'), [for (final l in logs) l?.goals.contains(g.id) ?? false], Color(g.color)),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageTitle(id: 'week.R', over: '', title: '', vars: weekVars(monday)),
      const SizedBox(height: 22),
      Expanded(
        child: Row(children: [
          Expanded(child: DayBox(date: d(3), color: tabs[3], onOpenDay: onOpenDay)),
          const SizedBox(width: 14),
          Expanded(child: DayBox(date: d(4), color: tabs[4], onOpenDay: onOpenDay)),
        ]),
      ),
      const SizedBox(height: 22),
      Expanded(
        child: Row(children: [
          Expanded(child: DayBox(date: d(5), color: tabs[5], onOpenDay: onOpenDay)),
          const SizedBox(width: 14),
          Expanded(child: DayBox(date: d(6), color: tabs[6], onOpenDay: onOpenDay)),
        ]),
      ),
      if (!store.isHidden('week.trackers')) ...[
        const SizedBox(height: 16),
        Expanded(
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: SketchBox(pal.ink))),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const ELabel('week.trackers', 'Trackers', part: 'week.trackers'),
                  Row(children: [
                    const SizedBox(width: 120),
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => onOpenDay(days[i]),
                          child: Center(child: Text(dayShort[i].substring(0, 1).toUpperCase(), style: body(11, pal.soft, w: FontWeight.w800))),
                        ),
                      ),
                  ]),
                  for (final r in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        SizedBox(width: 120, child: Text(r.$1, overflow: TextOverflow.ellipsis, style: hand(19, pal.ink))),
                        for (final on in r.$2) Expanded(child: Center(child: dot(on, r.$3))),
                      ]),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ],
    ]);
  }
}
