import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'deroule.dart';
import 'task_panel.dart' show showTaskPanel;
import 'timetable.dart' show askNewTask, fmtMin;

/// Préparer demain = la semaine, ouverte sur demain.
class TomorrowScreen extends StatelessWidget {
  const TomorrowScreen({super.key});

  @override
  Widget build(BuildContext context) => const WeekScreen(initial: 1);
}

/// Ma semaine : un jour à la fois (choisi en haut), sa liste à réordonner, des tâches à ajouter ou décaler.
class WeekScreen extends StatefulWidget {
  final int initial; // 0 = aujourd'hui, 1 = demain…
  const WeekScreen({super.key, this.initial = 1});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  late int _sel = widget.initial;

  static const _names = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  DateTime _date(int i) {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).add(Duration(days: i));
  }

  Future<void> _move(BuildContext context, Task t) async {
    final store = AppScope.read(context);
    final to = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Décaler « ${t.title} » à…', style: K.display(17)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (var i = 0; i < 14; i++)
                if (i != _sel)
                  ActionChip(
                    label: Text(i == 0 ? 'Aujourd\'hui' : (i == 1 ? 'Demain' : '${_names[_date(i).weekday - 1]} ${_date(i).day}')),
                    backgroundColor: K.raised,
                    side: BorderSide.none,
                    onPressed: () => Navigator.pop(ctx, i),
                  ),
              ActionChip(label: const Text('Plus tard (sans jour)'), backgroundColor: K.raised, side: BorderSide.none, onPressed: () => Navigator.pop(ctx, -1)),
            ]),
          ]),
        ),
      ),
    );
    if (to == null) return;
    if (to < 0) {
      await store.laterTask(t);
    } else {
      await store.setDay(t, dayKey(_date(to)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final key = dayKey(_date(_sel));
    final seq = store.daySequence(day: key).where((t) => !t.done).toList();
    final total = seq.fold(0, (a, t) => a + t.blockMin);
    return Scaffold(
      appBar: AppBar(title: const Text('Ma semaine')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
          children: [
            // les 7 jours : nombre de tâches et heures prévues
            SizedBox(
              height: 74,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (var i = 0; i < 7; i++)
                  Builder(builder: (context) {
                    final k = dayKey(_date(i));
                    final l = store.daySequence(day: k).where((t) => !t.done).toList();
                    final h = l.fold(0, (a, t) => a + t.blockMin);
                    final on = i == _sel;
                    final heavy = h > store.settings.dirProDefault + 120;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => _sel = i),
                        child: Container(
                          width: 64,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: on ? K.gold : K.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: heavy && !on ? K.coral : Colors.transparent, width: 2),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(i == 0 ? 'Auj.' : (i == 1 ? 'Dem.' : _names[_date(i).weekday - 1]), style: K.body(12, color: on ? K.bg : K.ink, w: FontWeight.w900)),
                            Text('${_date(i).day}', style: K.display(16, color: on ? K.bg : K.ink)),
                            Text(l.isEmpty ? '—' : '${l.length} · ${fmtMin(h)}', style: K.body(10, color: on ? K.bg : K.muted, w: FontWeight.w800)),
                          ]),
                        ),
                      ),
                    );
                  }),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Text(
                  _sel == 0 ? 'Aujourd\'hui' : (_sel == 1 ? 'Demain' : '${['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'][_date(_sel).weekday - 1]} ${_date(_sel).day}'),
                  style: K.display(20),
                ),
              ),
              if (seq.isNotEmpty) Text('${seq.length} tâche${seq.length > 1 ? 's' : ''} · ${fmtMin(total)}', style: K.body(12, color: K.muted, w: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (seq.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text('Rien de prévu ce jour-là.', style: K.body(13, color: K.muted))),
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorder: (a, b) => store.reorderDay(a, b > a ? b - 1 : b, day: key),
                  children: [
                    for (var i = 0; i < seq.length; i++)
                      Container(
                        key: ValueKey(seq[i].id),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          SizedBox(
                            width: 24,
                            child: Text('${i + 1}',
                                textAlign: TextAlign.right,
                                style: K.display(15, color: seq[i].category == 'perso' ? K.pink : (seq[i].category == 'pro' ? K.lime : K.gold))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => showTaskPanel(context, seq[i]),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(seq[i].title, style: K.body(14, w: FontWeight.w800)),
                                Text(
                                  [
                                    fmtMin(seq[i].blockMin),
                                    if (seq[i].plannedAt > 0) '📌 ${hm(DateTime.fromMillisecondsSinceEpoch(seq[i].plannedAt))}',
                                    if (store.subStepsOf(seq[i]).isNotEmpty) '${store.subStepsOf(seq[i]).length} sous-étapes',
                                  ].join(' · '),
                                  style: K.body(11, color: K.muted),
                                ),
                              ]),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Décaler',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _move(context, seq[i]),
                            icon: const Icon(Icons.arrow_forward_rounded, color: K.cyan, size: 20),
                          ),
                          ReorderableDragStartListener(
                            index: i,
                            child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.drag_handle_rounded, color: K.line)),
                          ),
                        ]),
                      ),
                  ],
                ),
                Row(children: [
                  TextButton.icon(
                    onPressed: () async {
                      final n = await askNewTask(context);
                      if (n == null) return;
                      final t = await store.addTask(n.title, category: n.category, estimate: n.minutes, quad: Quad.doNow);
                      await store.setDay(t, key);
                    },
                    icon: const Icon(Icons.add_rounded, color: K.lime, size: 18),
                    label: Text('Tâche', style: K.body(13, color: K.lime, w: FontWeight.w800)),
                  ),
                  const Spacer(),
                  if (seq.isNotEmpty && _sel < 6)
                    TextButton(
                      onPressed: () async {
                        for (final t in [...seq]) {
                          await store.setDay(t, dayKey(_date(_sel + 1)));
                        }
                        setState(() => _sel = _sel + 1);
                      },
                      child: Text('Tout décaler d\'un jour', style: K.body(12, color: K.cyan, w: FontWeight.w800)),
                    ),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            DerouleView(key: ValueKey(key), day: key),
          ],
        ),
      ),
    );
  }
}
