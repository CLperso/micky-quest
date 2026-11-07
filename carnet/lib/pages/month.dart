import 'package:flutter/material.dart';

import '../model.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

const moodColors = [Color(0xFFC9B8D8), Color(0xFFD7C3B6), Color(0xFFF1E3C2), Color(0xFFBFD8C9), Color(0xFF8CC5A8)];

/// Page de gauche du mois : calendrier, humeur en pixels, règles, rendez-vous.
class MonthCalendar extends StatelessWidget {
  final String month;
  final void Function(String day) onOpenDay;
  const MonthCalendar({super.key, required this.month, required this.onOpenDay});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final first = parseMonth(month);
    final n = DateTime(first.year, first.month + 1, 0).day;
    final today = store.todayKey;
    final cells = <Widget>[
      for (final d in dayShort) Center(child: Text(d, style: body(11, pal.soft, w: FontWeight.w900))),
      for (var i = 1; i < first.weekday; i++) const SizedBox(),
    ];
    for (var i = 1; i <= n; i++) {
      final k = dayKey(DateTime(first.year, first.month, i));
      final l = store.logs[k];
      final events = store.dayEntries(k).where((e) => e.kind == 'event').length;
      final tasks = store.dayEntries(k).where((e) => e.kind == 'task').length;
      cells.add(GestureDetector(
        onTap: () => onOpenDay(k),
        child: Container(
          decoration: BoxDecoration(
            color: (l?.mood ?? 0) > 0 ? moodColors[l!.mood - 1] : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: k == today ? pal.acc : pal.line, width: k == today ? 2.5 : 1),
          ),
          padding: const EdgeInsets.all(3),
          child: Stack(children: [
            Text('$i', style: body(11, pal.ink, w: FontWeight.w800)),
            if ((l?.period ?? 0) > 0) const Positioned(right: 0, top: 0, child: Text('🩸', style: TextStyle(fontSize: 10))),
            if (events + tasks > 0)
              Positioned(
                left: 0,
                bottom: 0,
                child: Row(children: [
                  for (var j = 0; j < events.clamp(0, 3); j++)
                    Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 2), decoration: BoxDecoration(color: pal.acc2, shape: BoxShape.circle)),
                  for (var j = 0; j < tasks.clamp(0, 3); j++)
                    Container(width: 5, height: 5, margin: const EdgeInsets.only(right: 2), decoration: BoxDecoration(color: pal.acc, borderRadius: BorderRadius.circular(1))),
                ]),
              ),
          ]),
        ),
      ));
    }
    // temps pro par semaine
    final weeks = <(String, int)>[];
    var m = mondayOf(first);
    while (m.isBefore(DateTime(first.year, first.month + 1, 1))) {
      weeks.add(('${m.day}/${m.month}', store.proBetween(m, 7)));
      m = m.add(const Duration(days: 7));
    }
    final maxPro = weeks.fold(60, (a, w) => w.$2 > a ? w.$2 : a);

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageTitle(id: 'month.L', over: '{annee}', title: '{Mois}', vars: dayVars(first)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 1.1,
          children: cells,
        ),
        const SizedBox(height: 6),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
          for (final c in moodColors) Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          Text(' humeur, dure → super   🩸 règles   ', style: body(11, pal.soft)),
          Container(width: 6, height: 6, decoration: BoxDecoration(color: pal.acc2, shape: BoxShape.circle)),
          Text(' rendez-vous', style: body(11, pal.soft)),
        ]),
        if (!store.isHidden('month.pro')) ELabel('month.pro', 'Temps de travail', part: 'month.pro'),
        if (!store.isHidden('month.pro')) SizedBox(
          height: 110,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final w in weeks)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(w.$2 == 0 ? '' : fmtMin(w.$2), style: body(11, pal.ink, w: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Container(height: 4 + 64 * w.$2 / maxPro, decoration: BoxDecoration(color: w.$2 == 0 ? pal.line : pal.acc2, borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 3),
                    Text(w.$1, style: body(10, pal.soft)),
                  ]),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Page de droite du mois : la liste du mois et les bilans.
class MonthList extends StatelessWidget {
  final String month;
  const MonthList({super.key, required this.month});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final first = parseMonth(month);
    final n = DateTime(first.year, first.month + 1, 0).day;
    final tiles = <Widget>[
      Tile(fmtMin(store.proBetween(first, n)), 'de travail', pal.acc2),
      for (final h in store.activeHabits) Tile('${store.habitDaysBetween(h.id, first, n)}', '${h.emoji} ${h.name}', pal.acc),
      for (final g in store.activeGoals) Tile('${store.goalStepsBetween(g.id, first, n)}', '${g.emoji} pas · ${g.title}', Color(g.color)),
    ];
    // début des règles ce mois-ci
    final starts = <int>[];
    for (var i = 1; i <= n; i++) {
      final k = dayKey(DateTime(first.year, first.month, i));
      if (store.cycleDay(k) == 1 && (store.logs[k]?.period ?? 0) > 0) starts.add(i);
    }
    if (starts.isNotEmpty) tiles.add(Tile(starts.map((d) => '$d').join(', '), '🩸 début des règles', const Color(0xFFD9667A)));

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageTitle(id: 'month.R', over: '', title: 'Ce mois-ci', vars: dayVars(first)),
        const SizedBox(height: 6),
        BulletList(items: store.monthEntries(month), onAdd: (t, k) async => store.addEntry(t, when: month, kind: k)),
        Part('month.stats', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [ELabel('month.stats', 'Bilan', part: 'month.stats'), Wrap(spacing: 8, runSpacing: 8, children: tiles)])),
      ]),
    );
  }
}
