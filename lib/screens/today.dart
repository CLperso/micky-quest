import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../notifications.dart';
import '../store.dart';
import '../theme.dart';
import 'briefing.dart';
import 'timetable.dart';

String fmtH(int m) => m >= 60 ? '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${(m % 60).toString().padLeft(2, '0')}'}' : '$m min';

/// Aujourd'hui : les quêtes du jour avec leurs étapes, les autres tâches, et le planning en dessous.
/// Une étape se coche, se lance, se modifie, se réordonne ou se pose à une heure — tout au même endroit.
class TodayScreen extends StatelessWidget {
  final bool standalone;
  const TodayScreen({super.key, this.standalone = false});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final plan = store.today;
    final inQuests = {for (final t in [...store.questSteps('pro'), ...store.questSteps('perso')]) t.id};
    final others = store.openTasks.where((t) => !inQuests.contains(t.id) && store.inToday(t)).toList();
    final sorted = store.openTasks.where((t) => !store.inToday(t)).toList();

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
            child: Text('Touche une quête pour la nommer, ajoute ses étapes, pose-les dans la journée.', style: K.body(13, color: K.muted)),
          ),
        _QuestBlock(cat: 'pro', tag: 'QUÊTE PRO', goal: plan.pro, color: K.lime),
        const SizedBox(height: 10),
        _QuestBlock(cat: 'perso', tag: 'QUÊTE PERSO', goal: plan.perso, color: K.pink),
        const SizedBox(height: 10),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text('Autres tâches du jour', style: K.display(15))),
                if (sorted.isNotEmpty)
                  TextButton(
                    onPressed: () => _pickSorted(context, store, sorted),
                    child: Text('Récupérer (${sorted.length})', style: K.body(12, color: K.gold)),
                  ),
              ]),
              if (others.isEmpty)
                Text('Rien d\'autre. « Faire maintenant » et les tâches avec une heure aujourd\'hui arrivent ici.', style: K.body(12, color: K.muted)),
              for (final t in others) TaskRow(task: t, color: K.quadColors[t.quad] ?? K.gold),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const TimetableView(),
      ],
    );
    if (!standalone) return body;
    return Scaffold(appBar: AppBar(title: const Text('Aujourd\'hui')), body: SafeArea(top: false, child: body));
  }

  Future<void> _pickSorted(BuildContext context, AppStore store, List<Task> sorted) async {
    final t = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: [
              Text('Ramener dans la journée', style: K.display(18)),
              const SizedBox(height: 8),
              for (final t in sorted)
                ListTile(
                  leading: Container(width: 10, height: 10, decoration: BoxDecoration(color: K.quadColors[t.quad], shape: BoxShape.circle)),
                  title: Text(t.title, style: K.body(15)),
                  subtitle: Text(Quad.titles[t.quad] ?? '', style: K.body(12, color: K.muted)),
                  onTap: () => Navigator.pop(ctx, t),
                ),
            ],
          ),
        ),
      ),
    );
    if (t == null) return;
    await store.moveTask(t, Quad.doNow);
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
    final goalMin = cat == 'pro' ? store.today.proGoalMin : 0;
    final proTotal = cat == 'pro' ? store.proMinutesOn(store.todayKey).round() : 0;
    final closed = store.xpEvents.any((e) => e.reason == 'Quête ${cat == 'pro' ? 'pro' : 'perso'} close' && dayKey(DateTime.fromMillisecondsSinceEpoch(e.ts)) == store.todayKey);
    return Panel(
      border: complete ? color : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Pill(tag, color: K.bg, fill: color),
            const SizedBox(width: 8),
            Expanded(child: Text(steps.isEmpty ? '' : '$done / ${steps.length} étapes', style: K.body(12, color: K.muted))),
            if (cat == 'pro' && (proTotal > 0 || goalMin > 0))
              Pill(goalMin > 0 ? '${fmtH(proTotal)} / ${fmtH(goalMin)}' : fmtH(proTotal), color: proTotal >= goalMin && goalMin > 0 ? K.gold : color)
            else if (minutes > 0)
              Pill(fmtH(minutes), color: color),
          ]),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final v = await askText(context, cat == 'pro' ? 'Ta quête pro aujourd\'hui' : 'Ta quête perso aujourd\'hui',
                  hint: cat == 'pro' ? 'finir la section méthode' : 'ranger la chambre', initial: goal);
              if (v == null) return;
              await store.setQuestTitle(cat, v);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Expanded(
                  child: Text(goal.isEmpty ? 'Touche pour nommer ta quête ${cat == 'pro' ? 'pro' : 'perso'}…' : goal,
                      style: K.body(17, w: FontWeight.w800, color: goal.isEmpty ? K.dim : K.ink)),
                ),
                const Icon(Icons.edit_rounded, color: K.muted, size: 16),
              ]),
            ),
          ),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 8),
            Bar(done / steps.length, color: color),
            const SizedBox(height: 6),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: (a, b) => store.reorderSteps(cat, a, b > a ? b - 1 : b),
              children: [
                for (var i = 0; i < steps.length; i++)
                  ReorderableDelayedDragStartListener(
                    key: ValueKey(steps[i].id),
                    index: i,
                    child: TaskRow(task: steps[i], color: color, quest: cat),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(children: [
            TextButton.icon(
              onPressed: () => addStepSheet(context, cat),
              icon: Icon(Icons.add_rounded, color: color, size: 18),
              label: Text('Ajouter une étape', style: K.body(13, color: color)),
            ),
            const Spacer(),
            if (complete && !closed)
              TextButton.icon(
                onPressed: () async {
                  final ok = await store.closeQuest(cat);
                  if (ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Quête close ! +${cat == 'pro' ? 15 : 5} XP · Micky ronronne.')));
                  }
                },
                icon: Icon(Icons.flag_rounded, color: color, size: 18),
                label: Text('Clore la quête', style: K.body(13, color: color, w: FontWeight.w800)),
              ),
            if (closed) Pill('QUÊTE CLOSE', color: color),
          ]),
        ],
      ),
    );
  }
}

/// Nouvelle étape : titre + pari de durée.
Future<void> addStepSheet(BuildContext context, String cat) async {
  final store = AppScope.read(context);
  final c = TextEditingController();
  var min = 25;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nouvelle étape ${cat == 'pro' ? 'pro' : 'perso'}', style: K.display(20)),
                const SizedBox(height: 8),
                TextField(
                  controller: c,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(hintText: cat == 'pro' ? 'relire l\'intro' : 'aller courir'),
                ),
                const SizedBox(height: 10),
                Text('Ton pari', style: K.body(13, color: K.muted)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final m in [10, 15, 25, 45, 60, 90, 120])
                      ChoiceChip(
                        label: Text('$m'),
                        selected: min == m,
                        onSelected: (_) => setState(() => min = m),
                        selectedColor: K.cyan,
                        labelStyle: K.body(13, color: min == m ? K.bg : K.ink),
                        backgroundColor: K.raised,
                        side: BorderSide.none,
                        showCheckmark: false,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: 'Ajouter',
                  onPressed: () async {
                    final t = c.text.trim();
                    if (t.isEmpty) return;
                    await store.addTask(t, category: cat, estimate: min, quad: Quad.doNow);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  c.dispose();
}

/// Modifier une tâche : titre, pari, quête, suppression.
Future<void> editTaskSheet(BuildContext context, Task t) async {
  final store = AppScope.read(context);
  final c = TextEditingController(text: t.title);
  var min = t.estimateMin;
  var cat = t.category;
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Modifier', style: K.display(20)),
                const SizedBox(height: 8),
                TextField(controller: c, textCapitalization: TextCapitalization.sentences),
                const SizedBox(height: 10),
                Text('Pari de durée', style: K.body(13, color: K.muted)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final m in [10, 15, 25, 45, 60, 90, 120])
                      ChoiceChip(
                        label: Text('$m'),
                        selected: min == m,
                        onSelected: (_) => setState(() => min = min == m ? 0 : m),
                        selectedColor: K.cyan,
                        labelStyle: K.body(13, color: min == m ? K.bg : K.ink),
                        backgroundColor: K.raised,
                        side: BorderSide.none,
                        showCheckmark: false,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Quête', style: K.body(13, color: K.muted)),
                const SizedBox(height: 6),
                Row(children: [
                  for (final e in [('pro', 'Pro', K.lime), ('perso', 'Perso', K.pink), ('', 'Aucune', K.gold)])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(e.$2),
                        selected: cat == e.$1,
                        onSelected: (_) => setState(() => cat = e.$1),
                        selectedColor: e.$3,
                        labelStyle: K.body(13, color: cat == e.$1 ? K.bg : K.ink),
                        backgroundColor: K.raised,
                        side: BorderSide.none,
                        showCheckmark: false,
                      ),
                    ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: SecondaryButton(label: 'Supprimer', onPressed: () => Navigator.pop(ctx, 'delete'))),
                  const SizedBox(width: 10),
                  Expanded(child: PrimaryButton(label: 'Enregistrer', onPressed: () => Navigator.pop(ctx, 'save'))),
                ]),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  if (result == 'delete') {
    await store.removeTask(t);
  } else if (result == 'save') {
    await store.editTask(t, title: c.text, estimate: min, category: cat == t.category ? null : cat);
  }
  c.dispose();
}

/// Une tâche du jour : cocher, lancer, poser à une heure, modifier.
class TaskRow extends StatelessWidget {
  final Task task;
  final Color color;
  final String quest; // '' si hors quête
  const TaskRow({super.key, required this.task, required this.color, this.quest = ''});

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
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => editTaskSheet(context, t),
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
                      if (quest.isEmpty && t.category.isNotEmpty) t.category,
                      'modifier',
                    ].join(' · '),
                    style: K.body(11, color: K.muted),
                  ),
                ],
              ),
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
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final toSort = store.tasksIn(Quad.inbox).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Row(children: [
            for (final (i, label) in ['Aujourd\'hui', toSort > 0 ? 'Trier ($toSort)' : 'Trier'].indexed)
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
}
