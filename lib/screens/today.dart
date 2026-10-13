import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../notifications.dart';
import '../store.dart';
import '../theme.dart';
import 'briefing.dart';
import 'timetable.dart';

/// Aujourd'hui : les quêtes du jour avec leurs étapes, les autres tâches, et le planning en dessous.
/// Une étape se coche, se lance, ou se pose à une heure — tout au même endroit.
class TodayScreen extends StatelessWidget {
  final bool standalone;
  const TodayScreen({super.key, this.standalone = false});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final plan = store.today;
    final inQuests = {for (final t in [...store.questSteps('pro'), ...store.questSteps('perso')]) t.id};
    final others = store.openTasks
        .where((t) => !inQuests.contains(t.id) && (t.quad == Quad.doNow || t.plannedAt > 0 || t.deferred || t.isBoss))
        .toList();

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        if (!standalone)
          Row(children: [
            Expanded(child: Text('Aujourd\'hui', style: K.display(24))),
            TextButton(onPressed: () => openScreen(context, const BriefingScreen()), child: const Text('Briefing')),
          ]),
        if (!plan.briefingDone)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Fais ton briefing pour définir tes quêtes et leurs étapes.', style: K.body(13, color: K.muted)),
          ),
        _QuestBlock(cat: 'pro', tag: 'QUÊTE PRO', goal: plan.pro, color: K.lime),
        const SizedBox(height: 10),
        _QuestBlock(cat: 'perso', tag: 'QUÊTE PERSO', goal: plan.perso, color: K.pink),
        if (others.isNotEmpty) ...[
          const SizedBox(height: 10),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Autres tâches du jour', style: K.display(15)),
                const SizedBox(height: 4),
                for (final t in others) TaskRow(task: t, color: K.quadColors[t.quad] ?? K.gold),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        const TimetableView(),
      ],
    );
    if (!standalone) return body;
    return Scaffold(appBar: AppBar(title: const Text('Aujourd\'hui')), body: SafeArea(top: false, child: body));
  }
}

class _QuestBlock extends StatelessWidget {
  final String cat, tag, goal;
  final Color color;
  const _QuestBlock({required this.cat, required this.tag, required this.goal, required this.color});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final steps = store.questSteps(cat);
    final done = steps.where((s) => s.done).length;
    final byTask = store.minutesByTask(store.todayKey);
    final minutes = steps.fold(0.0, (a, s) => a + (byTask[s.id] ?? 0)).round();
    final complete = steps.isNotEmpty && done == steps.length;
    return Panel(
      border: complete ? color : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Pill(tag, color: K.bg, fill: color),
            const SizedBox(width: 8),
            Expanded(child: Text(steps.isEmpty ? '' : '$done / ${steps.length} étapes', style: K.body(12, color: K.muted))),
            if (minutes > 0) Pill('$minutes min', color: color),
          ]),
          const SizedBox(height: 6),
          Text(goal.isEmpty ? 'Pas encore définie (briefing)' : goal,
              style: K.body(17, w: FontWeight.w800, color: goal.isEmpty ? K.dim : K.ink)),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 8),
            Bar(done / steps.length, color: color),
            const SizedBox(height: 6),
            for (final t in steps) TaskRow(task: t, color: color),
          ],
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () async {
              final title = await askText(context, 'Nouvelle étape $cat', hint: cat == 'pro' ? 'relire l\'intro · 25 min' : 'aller courir');
              if (title == null || title.isEmpty) return;
              await store.addTask(title, category: cat, quad: Quad.doNow);
            },
            icon: Icon(Icons.add_rounded, color: color, size: 18),
            label: Text('Ajouter une étape', style: K.body(13, color: color)),
          ),
        ],
      ),
    );
  }
}

/// Une tâche du jour : cocher, lancer, poser à une heure.
class TaskRow extends StatelessWidget {
  final Task task;
  final Color color;
  const TaskRow({super.key, required this.task, required this.color});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final t = task;
    final planned = t.plannedAt > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () async {
              await store.completeTask(t);
              if (t.done && context.mounted) await askNext(context, 'Étape faite !');
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(t.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: t.done ? color : K.muted, size: 26),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title,
                    style: K.body(14, color: t.done ? K.muted : K.ink, w: FontWeight.w800)
                        .copyWith(decoration: t.done ? TextDecoration.lineThrough : null)),
                Text(
                  [
                    if (t.estimateMin > 0) 'pari ${t.estimateMin} min',
                    if (t.isBoss) 'boss',
                    if (t.condition.isNotEmpty) 'si ${t.condition}',
                    if (t.deferred) 'reportée',
                  ].join(' · '),
                  style: K.body(11, color: K.muted),
                ),
              ],
            ),
          ),
          if (!t.done)
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () async {
                final at = await pickWhen(context,
                    initial: planned ? DateTime.fromMillisecondsSinceEpoch(t.plannedAt) : null, title: 'Quand ?');
                if (at == null) return;
                await store.planTask(t, at);
                await rescheduleAll(store);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: planned ? K.gold : K.line, width: 2),
                ),
                child: Text(planned ? hm(DateTime.fromMillisecondsSinceEpoch(t.plannedAt)) : 'à…',
                    style: K.body(12, color: planned ? K.gold : K.muted, w: FontWeight.w900)),
              ),
            ),
          if (!t.done)
            IconButton(
              tooltip: 'Lancer',
              onPressed: () => launchTask(context, t),
              icon: Icon(Icons.play_circle_fill_rounded, color: color, size: 30),
            ),
        ],
      ),
    );
  }
}

/// Onglet Quêtes : Aujourd'hui (quêtes, tâches, planning) ou la matrice de tri.
class QuestsTab extends StatefulWidget {
  final Widget matrix;
  const QuestsTab({super.key, required this.matrix});

  @override
  State<QuestsTab> createState() => _QuestsTabState();
}

class _QuestsTabState extends State<QuestsTab> {
  int _mode = 0;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(children: [
              for (final (i, label) in ['Aujourd\'hui', 'Trier'].indexed)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == 0 ? 6 : 0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _mode = i),
                      child: Container(
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: _mode == i ? K.gold : K.card, borderRadius: BorderRadius.circular(12)),
                        child: Text(label, style: K.body(13, color: _mode == i ? K.bg : K.ink, w: FontWeight.w800)),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          Expanded(child: _mode == 0 ? const TodayScreen() : widget.matrix),
        ],
      );
}
