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
