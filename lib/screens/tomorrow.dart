import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'task_panel.dart' show showTaskPanel;
import 'timetable.dart' show PlanningView, askText;

/// Préparer demain : les quêtes, leurs étapes, le reste, et le planning de demain.
class TomorrowScreen extends StatelessWidget {
  const TomorrowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final day = store.tomorrowKey;
    final plan = store.plan(day);
    final open = store.tasks.where((t) => !t.done && !t.removed && t.day == day).toList()..sort((a, b) => a.order.compareTo(b.order));
    List<Task> steps(String c) => open.where((t) => t.inQuest && t.category == c).toList();
    final others = open.where((t) => !t.inQuest).toList();

    Widget quest(String c, String goal, Color color) => Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('QUÊTE ${c == 'pro' ? 'PRO' : 'PERSO'} DE DEMAIN', style: K.body(10, color: color, w: FontWeight.w900)),
            InkWell(
              onTap: () async {
                final v = await askText(context, c == 'pro' ? 'Ta quête pro demain' : 'Ta quête perso demain', initial: goal);
                if (v == null) return;
                if (c == 'pro') {
                  plan.pro = v.trim();
                } else {
                  plan.perso = v.trim();
                }
                await store.commit();
              },
              child: Row(children: [
                Expanded(child: Text(goal.isEmpty ? 'Touche pour la nommer…' : goal, style: K.display(18, color: goal.isEmpty ? K.dim : K.ink))),
                const Icon(Icons.edit_rounded, color: K.muted, size: 16),
              ]),
            ),
            const SizedBox(height: 6),
            for (final t in steps(c)) _row(context, t, color),
            TextButton.icon(
              onPressed: () async {
                final v = await askText(context, 'Une étape pour demain', hint: c == 'pro' ? 'relire l\'intro' : 'courses');
                if (v == null || v.trim().isEmpty) return;
                await store.addTomorrow(v.trim(), category: c, inQuest: true);
              },
              icon: Icon(Icons.add_rounded, color: color, size: 18),
              label: Text('Étape', style: K.body(13, color: color)),
            ),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Demain')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
          children: [
            Text('Pose ta journée de demain ce soir : demain matin, il n\'y aura plus qu\'à démarrer.', style: K.body(13, color: K.muted)),
            const SizedBox(height: 10),
            Panel(
              border: const Color(0xFFB9A7FF),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('DEMAIN · POUR « DEVENIR CONSTANTE »', style: K.body(11, color: const Color(0xFFB9A7FF), w: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('⏰ Je démarre avant', style: K.body(13, w: FontWeight.w800)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, children: [
                  for (final m in <int>{540, 570, 600, 630, 660, store.settings.startTarget}.toList()..sort())
                    ChoiceChip(
                      label: Text('${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60}'}'),
                      selected: store.settings.startTarget == m,
                      onSelected: (_) async {
                        store.settings.startTarget = m;
                        await store.updateSettings();
                      },
                      selectedColor: K.lime,
                      labelStyle: K.body(12, color: store.settings.startTarget == m ? K.bg : K.ink, w: FontWeight.w800),
                      backgroundColor: K.raised,
                      side: BorderSide.none,
                      showCheckmark: false,
                    ),
                ]),
                const SizedBox(height: 8),
                Text('💼 Temps pro visé', style: K.body(13, w: FontWeight.w800)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, children: [
                  for (final m in const [60, 120, 180, 240, 300])
                    ChoiceChip(
                      label: Text('${m ~/ 60} h'),
                      selected: (plan.proGoalMin > 0 ? plan.proGoalMin : store.settings.dirProDefault) == m,
                      onSelected: (_) async {
                        plan.proGoalMin = m;
                        await store.commit();
                      },
                      selectedColor: K.lime,
                      labelStyle: K.body(12, color: (plan.proGoalMin > 0 ? plan.proGoalMin : store.settings.dirProDefault) == m ? K.bg : K.ink, w: FontWeight.w800),
                      backgroundColor: K.raised,
                      side: BorderSide.none,
                      showCheckmark: false,
                    ),
                ]),
                const SizedBox(height: 4),
                Text('Prérempli avec tes habitudes : ne change que si demain est différent.', style: K.body(11, color: K.dim)),
              ]),
            ),
            const SizedBox(height: 10),
            quest('pro', plan.pro, K.lime),
            const SizedBox(height: 10),
            quest('perso', plan.perso, K.pink),
            const SizedBox(height: 10),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Aussi demain', style: K.display(15)),
                if (others.isEmpty) Text('Rien d\'autre pour l\'instant. Ce que tu reportes au feu de camp arrive ici.', style: K.body(12, color: K.muted)),
                for (final t in others) _row(context, t, t.category == 'perso' ? K.pink : K.gold),
                TextButton.icon(
                  onPressed: () async {
                    final v = await askText(context, 'Une tâche pour demain');
                    if (v == null || v.trim().isEmpty) return;
                    await store.addTomorrow(v.trim());
                  },
                  icon: const Icon(Icons.add_rounded, color: K.gold, size: 18),
                  label: Text('Tâche', style: K.body(13, color: K.gold)),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Text('Le planning de demain', style: K.display(16)),
            const SizedBox(height: 6),
            PlanningView(day: day),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, Task t, Color color) => InkWell(
        onTap: () => showTaskPanel(context, t),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text(t.title, style: K.body(14, w: FontWeight.w700))),
            if (t.plannedAt > 0) Text(hm(DateTime.fromMillisecondsSinceEpoch(t.plannedAt)), style: K.body(12, color: K.gold, w: FontWeight.w900)),
            if (t.estimateMin > 0) Text('  ${t.estimateMin} min', style: K.body(12, color: K.muted)),
          ]),
        ),
      );
}

