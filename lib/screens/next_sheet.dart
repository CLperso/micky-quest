import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'block.dart' show SimpleTimer;
import 'today.dart' show TodayScreen;
import 'timetable.dart' show launchTask;

/// Après une tâche ou une session : un petit mot, et la suite proposée en un tap.
Future<void> showNextSheet(BuildContext context, String message) async {
  final store = AppScope.read(context);
  final cands = <Task>[];
  void add(Task? t) {
    if (t != null && !t.done && !cands.any((c) => c.id == t.id)) cands.add(t);
  }

  // la suite, dans l'ordre de la liste du jour
  for (final t in store.daySequence()) {
    if (cands.length >= 3) break;
    final subs = store.subStepsOf(t).where((x) => !x.done).toList();
    add(subs.isNotEmpty ? subs.first : t);
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ClipOval(child: Image.asset(K.micky['happy']!, width: 44, height: 44, fit: BoxFit.cover)),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: K.display(19))),
          ]),
          const SizedBox(height: 14),
          if (cands.isNotEmpty) ...[
            Text('ENSUITE ?', style: K.body(11, color: K.muted, w: FontWeight.w900)),
            const SizedBox(height: 6),
            for (final t in cands)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: t.category == 'perso' ? K.pink : K.lime, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.title, style: K.body(14, w: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text(
                        [
                          if (t.plannedAt > 0) '📌 ${hm(DateTime.fromMillisecondsSinceEpoch(t.plannedAt))}',
                          if (t.category.isNotEmpty) t.category,
                          if (t.estimateMin > 0) '${t.estimateMin} min',
                        ].join(' · '),
                        style: K.body(11, color: K.muted),
                      ),
                    ]),
                  ),
                  Material(
                    color: t.category == 'perso' ? K.pink : K.lime,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.pop(ctx);
                        launchTask(context, t);
                      },
                      child: const SizedBox(width: 44, height: 40, child: Icon(Icons.play_arrow_rounded, color: K.bg)),
                    ),
                  ),
                ]),
              ),
            const SizedBox(height: 6),
          ],
          Row(children: [
            Expanded(
              child: SecondaryButton(
                label: 'Une pause',
                onPressed: () {
                  Navigator.pop(ctx);
                  openScreen(context, const SimpleTimer(title: 'Pause', minutes: 10, hint: 'Lève-toi, bois un verre d\'eau, bouge un peu. Dix minutes, puis on repart.', what: 'pause'));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SecondaryButton(
                label: 'Voir ma liste',
                onPressed: () {
                  Navigator.pop(ctx);
                  openScreen(context, const TodayScreen(standalone: true));
                },
              ),
            ),
          ]),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Center(child: Text('Rien pour l\'instant', style: K.body(13, color: K.muted))),
          ),
        ]),
      ),
    ),
  );
}
