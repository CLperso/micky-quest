import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'boss.dart';
import 'briefing.dart';
import 'task_panel.dart';
import 'timetable.dart';
import 'tomorrow.dart';

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
    final others = store.openTasks.where((t) => !inQuests.contains(t.id) && store.inToday(t)).toList()
      ..sort((a, b) => (a.plannedAt == 0 ? 1 << 52 : a.plannedAt).compareTo(b.plannedAt == 0 ? 1 << 52 : b.plannedAt));
    final sorted = store.openTasks.where((t) => !store.inToday(t)).toList();

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        if (!standalone)
          Row(children: [
            Expanded(child: Text('Aujourd\'hui', style: K.display(24))),
            TextButton(onPressed: () => openScreen(context, const TomorrowScreen()), child: const Text('Demain ›')),
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
                Expanded(child: Text('Aussi aujourd\'hui', style: K.display(15))),
                if (sorted.isNotEmpty)
                  TextButton(
                    onPressed: () => _pickSorted(context, store, sorted),
                    child: Text('Récupérer (${sorted.length})', style: K.body(12, color: K.gold)),
                  ),
              ]),
              if (others.isEmpty)
                Text('Rien d\'autre. « Faire maintenant » et ce qui a une heure aujourd\'hui arrive ici.', style: K.body(12, color: K.muted)),
              for (final t in others) TaskRow(task: t, color: K.quadColors[t.quad] ?? K.gold),
            ],
          ),
        ),
        if (store.toPlaceToday.isNotEmpty) ...[
          const SizedBox(height: 10),
          const _MaybeToday(),
        ],
        const SizedBox(height: 18),
        const PlanningView(),
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

class _QuestBlock extends StatefulWidget {
  final String cat, tag, goal;
  final Color color;
  const _QuestBlock({required this.cat, required this.tag, required this.goal, required this.color});

  @override
  State<_QuestBlock> createState() => _QuestBlockState();
}

class _QuestBlockState extends State<_QuestBlock> {
  bool _open = false;

  Widget _stones(List<Task> steps, int cur, Color color) {
    final n = steps.length;
    return SizedBox(
      height: 58,
      child: LayoutBuilder(builder: (context, c) {
        const flag = 26.0, gap = 8.0;
        final w = (c.maxWidth - flag - gap * n) / n;
        final children = <Widget>[];
        for (var i = 0; i < n; i++) {
          final x = i * (w + gap);
          final done = i < cur || steps[i].done;
          final here = i == cur;
          if (i < n) {
            children.add(Positioned(
              left: x + w,
              top: 44,
              width: gap,
              height: 3,
              child: Container(color: done ? color : K.line),
            ));
          }
          children.add(Positioned(
            left: x,
            top: 37,
            width: w,
            height: 17,
            child: GestureDetector(
              onTap: () => showTaskPanel(context, steps[i]),
              child: Container(
                decoration: BoxDecoration(
                  color: done ? color : (here ? K.bg : K.raised),
                  borderRadius: BorderRadius.circular(20),
                  border: here ? Border.all(color: color, width: 3) : null,
                ),
              ),
            ),
          ));
        }
        // Micky sur l'étape en cours (ou au drapeau si tout est fait)
        final mx = cur >= n ? c.maxWidth - flag / 2 - 15 : cur * (w + gap) + w / 2 - 15;
        children.add(AnimatedPositioned(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          left: mx,
          top: 0,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              image: DecorationImage(image: AssetImage(K.micky['face']!), fit: BoxFit.cover),
            ),
          ),
        ));
        children.add(Positioned(right: 0, top: 30, child: Text('🏁', style: TextStyle(fontSize: 20, color: cur >= n ? color : null))));
        return Stack(clipBehavior: Clip.none, children: children);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.cat, goal = widget.goal, color = widget.color;
    final store = AppScope.of(context);
    final steps = store.questSteps(cat);
    final done = steps.where((s) => s.done).length;
    final byTask = store.minutesByTask(store.todayKey);
    final minutes = steps.fold(0.0, (a, s) => a + (byTask[s.id] ?? 0)).round();
    final complete = steps.isNotEmpty && done == steps.length;
    final goalMin = cat == 'pro' ? store.today.proGoalMin : 0;
    final proTotal = cat == 'pro' ? store.proMinutesOn(store.todayKey).round() : 0;
    final closed = store.xpEvents.any((e) => e.reason == 'Quête ${cat == 'pro' ? 'pro' : 'perso'} close' && dayKey(DateTime.fromMillisecondsSinceEpoch(e.ts)) == store.todayKey);
    var cur = steps.indexWhere((s) => !s.done);
    if (cur < 0) cur = steps.length;
    final current = cur < steps.length ? steps[cur] : null;
    final next = cur + 1 < steps.length ? steps.skip(cur + 1).firstWhere((s) => !s.done, orElse: () => steps[cur + 1]) : null;
    final meter = cat == 'pro' && (proTotal > 0 || goalMin > 0)
        ? (goalMin > 0 ? '${fmtH(proTotal)} / ${fmtH(goalMin)}' : fmtH(proTotal))
        : (minutes > 0 ? fmtH(minutes) : (steps.isEmpty ? '' : '$done / ${steps.length}'));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: K.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: complete ? color : color.withValues(alpha: 0.35), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final v = await askText(context, cat == 'pro' ? 'Ta quête pro aujourd\'hui' : 'Ta quête perso aujourd\'hui',
                      hint: cat == 'pro' ? 'finir la section méthode' : 'ranger la chambre', initial: goal);
                  if (v == null) return;
                  await store.setQuestTitle(cat, v);
                },
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    steps.isEmpty ? 'QUÊTE ${widget.tag}' : (complete ? 'QUÊTE ${widget.tag} · TOUT EST FAIT' : 'QUÊTE ${widget.tag} · ÉTAPE ${cur + 1} / ${steps.length}'),
                    style: K.body(10, color: color, w: FontWeight.w900),
                  ),
                  Text(goal.isEmpty ? 'Touche pour nommer ta quête…' : goal, style: K.display(18, color: goal.isEmpty ? K.dim : K.ink)),
                ]),
              ),
            ),
            if (meter.isNotEmpty) Text(meter, style: K.body(12, color: proTotal >= goalMin && goalMin > 0 ? K.gold : K.muted, w: FontWeight.w800)),
          ]),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 4),
            _stones(steps, cur, color),
            const SizedBox(height: 6),
            if (current != null)
              Container(
                padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
                decoration: BoxDecoration(color: K.bg, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  CheckCircle(task: current, color: color),
                  Expanded(
                    child: InkWell(
                      onTap: () => showTaskPanel(context, current),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${current.title}${current.estimateMin > 0 ? ' · ${fmtH(current.estimateMin)}' : ''}', style: K.body(14, w: FontWeight.w800)),
                          if (next != null) Text('ensuite : ${next.title}', style: K.body(11, color: K.dim)),
                        ]),
                      ),
                    ),
                  ),
                  Material(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => launchTask(context, current),
                      child: const SizedBox(width: 44, height: 40, child: Icon(Icons.play_arrow_rounded, color: K.bg)),
                    ),
                  ),
                ]),
              )
            else
              Text(closed ? 'Quête close. Micky ronronne.' : 'Toutes les étapes sont faites : tu peux clore la quête.', style: K.body(13, color: color, w: FontWeight.w800)),
            if (_open) ...[
              const SizedBox(height: 8),
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
              Text('Appui long pour changer l\'ordre.', style: K.body(11, color: K.dim)),
            ],
          ],
          const SizedBox(height: 2),
          Row(children: [
            if (steps.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _open = !_open),
                child: Text(_open ? 'Replier' : 'Toutes les étapes (${steps.length})', style: K.body(13, color: K.muted)),
              ),
            TextButton.icon(
              onPressed: () => addStepSheet(context, cat),
              icon: Icon(Icons.add_rounded, color: color, size: 18),
              label: Text('Étape', style: K.body(13, color: color)),
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
                label: Text('Clore', style: K.body(13, color: color, w: FontWeight.w800)),
              ),
            if (closed) Pill('CLOSE', color: color),
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
    final wasQuest = t.inQuest;
    await store.editTask(t, title: c.text, estimate: min, category: cat == t.category ? null : cat);
    // changer pro ↔ perso garde l'étape dans la quête du nouveau type
    if (wasQuest && cat.isNotEmpty && cat != t.category) await store.editTask(t, inQuest: true);
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
          CheckCircle(task: t, color: color),
          const SizedBox(width: 2),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => t.isBoss ? openScreen(context, const BossScreen()) : showTaskPanel(context, t),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title,
                      style: K.body(14, color: t.done ? K.muted : K.ink, w: FontWeight.w800)
                          .copyWith(decoration: t.done ? TextDecoration.lineThrough : null)),
                  Text(
                    [
                      if (t.estimateMin > 0) '${t.estimateMin} min',
                      if (t.isBoss) 'boss',
                      if (t.condition.isNotEmpty) 'si ${t.condition}',
                      if (quest.isEmpty && t.category.isNotEmpty) t.category,
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
              onTap: () => whenSheet(context, t),
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
  int? _mode; // 0 = Trier, 1 = Aujourd'hui
  int _lastToSort = -1;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final toSort = store.tasksIn(Quad.inbox).length;
    // le bandeau « à trier » vient de se vider : on passe à Aujourd'hui
    if (_lastToSort > 0 && toSort == 0 && (_mode ?? 0) == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _mode = 1);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tout est trié · place à Aujourd\'hui')));
      });
    }
    _lastToSort = toSort;
    final mode = _mode ?? (toSort > 0 ? 0 : 1);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Row(children: [
            for (final (i, label) in [toSort > 0 ? '1 · Trier ($toSort)' : '1 · Trier', '2 · Aujourd\'hui'].indexed)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 0 ? 6 : 0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _mode = i),
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: mode == i ? K.gold : K.card, borderRadius: BorderRadius.circular(12)),
                      child: Text(label, style: K.body(13, color: mode == i ? K.bg : K.ink, w: FontWeight.w800)),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        Expanded(child: mode == 1 ? const TodayScreen() : widget.matrix),
      ],
    );
  }
}

/// « Peut-être aujourd'hui ? » : tâches Planifier sans heure, repliées par défaut.
class _MaybeToday extends StatefulWidget {
  const _MaybeToday();

  @override
  State<_MaybeToday> createState() => _MaybeTodayState();
}

class _MaybeTodayState extends State<_MaybeToday> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final list = store.toPlaceToday;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Row(children: [
              Expanded(child: Text('Peut-être aujourd\'hui ? (${list.length})', style: K.display(15, color: K.gold))),
              Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: K.gold),
            ]),
          ),
          if (_open) ...[
            Text('Tes tâches « Planifier » sans heure. « Caser » les pose dans le planning, « Pas auj. » les cache jusqu\'à demain.', style: K.body(11, color: K.muted)),
            const SizedBox(height: 4),
                for (final t in list.take(8))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Container(width: 4, height: 34, decoration: BoxDecoration(color: t.category == 'pro' ? K.lime : t.category == 'perso' ? K.pink : K.gold, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => showTaskPanel(context, t),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t.title, style: K.body(13, w: FontWeight.w800)),
                            Text(
                              [
                                if (t.category.isNotEmpty) t.category,
                                if (t.estimateMin > 0) '${t.estimateMin} min',
                                if (t.condition.isNotEmpty) 'seulement quand : ${t.condition}',
                              ].join(' · '),
                              style: K.body(11, color: K.muted),
                            ),
                          ]),
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => openScreen(context, PlanningScreen(day: store.todayKey, place: t)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: K.lime, borderRadius: BorderRadius.circular(999)),
                          child: Text('Caser', style: K.body(11, color: K.bg, w: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => store.hideToday(t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(border: Border.all(color: K.line, width: 2), borderRadius: BorderRadius.circular(999)),
                          child: Text('Pas auj.', style: K.body(11, color: K.muted, w: FontWeight.w800)),
                        ),
                      ),
                    ]),
                  ),
          ],
        ],
      ),
    );
  }
}
