import 'package:flutter/material.dart';

import '../model.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Page de gauche du jour : le briefing et la liste.
class DayMorning extends StatelessWidget {
  final String day;
  const DayMorning({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final log = store.log(day);
    final d = parseDay(day);
    final isToday = day == store.todayKey;
    final left = isToday ? store.leftovers() : <Entry>[];
    final monthOpen = isToday ? store.monthOpen(monthKey(d)) : <Entry>[];
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageTitle(over: '${niceDay(d)} · matin', title: 'Briefing'),
        Label('Aujourd’hui je veux surtout…', pal.soft),
        HandField(
          value: log.intention,
          hint: 'une intention, une envie…',
          size: 32,
          color: pal.acc,
          onChanged: (v) {
            log.intention = v;
            store.touchLog(log);
          },
        ),
        if (left.isNotEmpty || monthOpen.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (left.isNotEmpty)
              ActionChip(
                avatar: const Text('↺'),
                label: Text('${left.length} chose${left.length > 1 ? 's' : ''} d’avant · trier'),
                onPressed: () => _triage(context, left, 'Des jours d’avant'),
              ),
            if (monthOpen.isNotEmpty)
              ActionChip(
                avatar: const Text('🗓'),
                label: Text('${monthOpen.length} prévue${monthOpen.length > 1 ? 's' : ''} ce mois-ci'),
                onPressed: () => _triage(context, monthOpen, 'Prévu en ${monthNames[d.month - 1]}'),
              ),
          ]),
        ],
        Label('Ce qui compte', pal.soft),
        BulletList(
          items: store.dayEntries(day),
          onAdd: (t, k) async {
            await store.addEntry(t, when: day, kind: k);
          },
        ),
      ]),
    );
  }

  /// Trier sans culpabilité : aujourd'hui, plus tard, ou on laisse tomber.
  Future<void> _triage(BuildContext context, List<Entry> list, String title) async {
    final store = StoreScope.read(context);
    final pal = Pal.byId(store.settings.theme);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StoreScope(
        store: store,
        child: StatefulBuilder(builder: (ctx, setState) {
          final items = list.where((e) => !e.done && !e.dropped && e.when != store.todayKey).toList();
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
              child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(20), children: [
                Text(title, style: titleFont(22, pal.ink)),
                Text('Rien n’est en retard : tu choisis ce qui compte encore.', style: body(13, pal.soft)),
                const SizedBox(height: 10),
                if (items.isEmpty) Text('Tout est trié ✨', style: hand(26, pal.acc)),
                for (final e in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.text, style: body(15, pal.ink)),
                      Wrap(spacing: 6, children: [
                        ActionChip(
                            label: const Text('Aujourd’hui'),
                            onPressed: () async {
                              await store.moveEntry(e, store.todayKey);
                              setState(() {});
                            }),
                        ActionChip(
                            label: const Text('Un jour'),
                            onPressed: () async {
                              await store.moveEntry(e, 'someday');
                              setState(() {});
                            }),
                        ActionChip(
                            label: const Text('C’est fait'),
                            onPressed: () async {
                              await store.toggleDone(e);
                              setState(() {});
                            }),
                        ActionChip(
                            label: const Text('Laisser tomber'),
                            onPressed: () async {
                              await store.dropEntry(e);
                              setState(() {});
                            }),
                      ]),
                    ]),
                  ),
              ]),
            ),
          );
        }),
      ),
    );
  }
}

/// Page de droite du jour : le feu de camp et les trackers.
class DayEvening extends StatelessWidget {
  final String day;
  const DayEvening({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final log = store.log(day);
    final d = parseDay(day);
    final monday = mondayOf(d);
    final cycle = log.period > 0 ? store.cycleDay(day) : null;
    final running = store.timerStart != 0 && day == store.todayKey;
    final perso = store.activeGoals.where((g) => g.kind == 'perso').toList();
    final pro = store.activeGoals.where((g) => g.kind != 'perso').toList();

    void save() => store.touchLog(log);

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageTitle(over: '${niceDay(d)} · soir', title: 'Feu de camp'),
        Label('Mes trackers', pal.soft),
        TrackRow(
          '🩸 Règles',
          Dots(
              value: log.period,
              n: 3,
              color: const Color(0xFFD9667A),
              onChanged: (v) {
                log.period = v;
                save();
              }),
          note: cycle == null ? null : 'jour $cycle',
        ),
        TrackRow(
          'Humeur',
          Faces(
              value: log.mood,
              onChanged: (v) {
                log.mood = v;
                save();
              }),
        ),
        TrackRow(
          'Énergie',
          Dots(
              value: log.energy,
              color: pal.acc3,
              onChanged: (v) {
                log.energy = v;
                save();
              }),
        ),
        TrackRow(
          'Temps pro',
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(minHeight: 12, value: (log.proMin / 300).clamp(0, 1), backgroundColor: pal.line, color: pal.acc2),
              ),
            ),
            const SizedBox(width: 8),
            Text(fmtMin(log.proMin + (running ? store.timerMinutes : 0)), style: body(13, pal.ink, w: FontWeight.w800)),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () {
                log.proMin = (log.proMin - 15).clamp(0, 1440);
                save();
              },
              icon: const Icon(Icons.remove_rounded, size: 18),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () {
                log.proMin += 15;
                save();
              },
              icon: const Icon(Icons.add_rounded, size: 18),
            ),
            if (day == store.todayKey)
              IconButton(
                tooltip: running ? 'Arrêter la session' : 'Lancer une session',
                visualDensity: VisualDensity.compact,
                onPressed: () => running ? store.stopTimer() : store.startTimer(),
                icon: Icon(running ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded, color: pal.acc2, size: 26),
              ),
          ]),
        ),
        for (final h in store.activeHabits)
          TrackRow(
            '${h.emoji} ${h.name}',
            Align(
              alignment: Alignment.centerLeft,
              child: CheckBoxy(
                on: log.habits.contains(h.id),
                color: pal.acc,
                onTap: () {
                  log.habits.contains(h.id) ? log.habits.remove(h.id) : log.habits.add(h.id);
                  save();
                },
              ),
            ),
            note: '${store.habitDaysBetween(h.id, monday, 7)}/${h.perWeek} cette sem.',
          ),
        for (final g in perso)
          TrackRow(
            '${g.emoji} ${g.title}',
            Align(
              alignment: Alignment.centerLeft,
              child: CheckBoxy(
                on: log.goals.contains(g.id),
                color: Color(g.color),
                onTap: () {
                  log.goals.contains(g.id) ? log.goals.remove(g.id) : log.goals.add(g.id);
                  save();
                },
              ),
            ),
            note: '${store.goalStepsBetween(g.id, monday, 7)}/${g.perWeek} cette sem.',
          ),
        if (pro.isNotEmpty) ...[
          Label('Un pas vers mes objectifs ?', pal.soft),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final g in pro)
              FilterChip(
                label: Text('${g.emoji} ${g.title}'),
                selected: log.goals.contains(g.id),
                selectedColor: Color(g.color).withValues(alpha: 0.35),
                onSelected: (_) {
                  log.goals.contains(g.id) ? log.goals.remove(g.id) : log.goals.add(g.id);
                  save();
                },
              ),
          ]),
        ],
        Label('Victoire du jour', pal.soft),
        HandField(
          value: log.win,
          hint: 'même petite…',
          size: 28,
          onChanged: (v) {
            log.win = v;
            save();
          },
        ),
        Label('Une ligne de journal', pal.soft),
        HandField(
          value: log.journal,
          hint: 'ce que je veux garder de ce jour',
          size: 24,
          color: pal.soft,
          maxLines: 8,
          onChanged: (v) {
            log.journal = v;
            save();
          },
        ),
      ]),
    );
  }
}
