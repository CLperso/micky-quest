import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'boss.dart';
import 'briefing.dart';
import 'matrix.dart' show MatrixScreen;
import 'task_panel.dart';
import 'timetable.dart';
import 'tomorrow.dart';
import 'deroule.dart';
import 'modes.dart';

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
    final dups = store.similarPairs();
    final sorted = store.openTasks.where((t) => !store.inToday(t)).toList();

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        if (!standalone)
          Row(children: [
            Expanded(child: Text('Aujourd\'hui', style: K.display(24))),
            TextButton(onPressed: () => openScreen(context, const TomorrowScreen()), child: const Text('Semaine ›')),
            TextButton(onPressed: () => openScreen(context, const BriefingScreen()), child: const Text('Briefing')),
          ]),
        Material(
          color: K.card,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => newTaskSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: K.line, width: 2)),
              child: Row(children: [
                const Icon(Icons.add_circle_rounded, color: K.lime),
                const SizedBox(width: 10),
                Expanded(child: Text('Nouvelle tâche…', style: K.body(14, color: K.muted, w: FontWeight.w800))),
                Text('pro / perso · durée · jour', style: K.body(11, color: K.muted)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (store.tasksIn(Quad.inbox).isNotEmpty) ...[
          const _ToSort(),
          const SizedBox(height: 10),
        ],
        if (!plan.briefingDone)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Une seule liste, dans l\'ordre réel de ta journée. Tire la poignée ≡ pour déplacer.', style: K.body(13, color: K.muted)),
          ),
        if (dups.isNotEmpty) ...[
          Panel(
            border: K.gold,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Doublon ?', style: K.display(15, color: K.gold)),
              for (final d in dups.take(3))
                Row(children: [
                  Expanded(child: Text('« ${d.$1.title} » et « ${d.$2.title} »', style: K.body(13))),
                  TextButton(onPressed: () => mergeSheet(context, d.$1, d.$2), child: Text('fusionner', style: K.body(12, color: K.gold, w: FontWeight.w900))),
                ]),
            ]),
          ),
          const SizedBox(height: 10),
        ],
        const Padding(padding: EdgeInsets.only(bottom: 8), child: Align(alignment: Alignment.centerLeft, child: ModePill())),
        const ModeBanner(),
        const _DayHeader(),
        const SizedBox(height: 10),
        const _DayList(),
        if (sorted.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _pickSorted(context, store, sorted),
              child: Text('Récupérer une tâche rangée (${sorted.length})', style: K.body(12, color: K.gold)),
            ),
          ),
        if (store.toPlaceToday.isNotEmpty) ...[
          const SizedBox(height: 10),
          const _MaybeToday(),
        ],
        const SizedBox(height: 18),
        const DerouleView(),
        const SizedBox(height: 14),
        const _Later(),
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
    store.addToToday(t);
  }
}

/// En haut de la liste : pro (temps / objectif, cap), perso (fait / objectif, cap) et Micky sur ses pierres (une par tâche pro).
class _DayHeader extends StatelessWidget {
  const _DayHeader();

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

  Future<void> _rename(BuildContext context, String cat, String goal) async {
    final store = AppScope.read(context);
    final v = await askText(context, cat == 'pro' ? 'Ton cap pro aujourd\'hui' : 'Ton cap perso aujourd\'hui',
        hint: cat == 'pro' ? 'finir la section méthode' : 'ranger la chambre', initial: goal);
    if (v == null) return;
    await store.setQuestTitle(cat, v);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final plan = store.today;
    final pro = store.questSteps('pro'), perso = store.questSteps('perso');
    final proTotal = store.proMinutesOn(store.todayKey).round();
    final goalMin = plan.proGoalMin;
    final persoDone = perso.where((t) => t.done).length;
    var cur = pro.indexWhere((t) => !t.done);
    if (cur < 0) cur = pro.length;
    final proClosed = store.xpEvents.any((e) => e.reason == 'Quête pro close' && dayKey(DateTime.fromMillisecondsSinceEpoch(e.ts)) == store.todayKey);
    final persoClosed = store.xpEvents.any((e) => e.reason == 'Quête perso close' && dayKey(DateTime.fromMillisecondsSinceEpoch(e.ts)) == store.todayKey);
    Widget cap(String cat, String goal, Color color, String meter, bool complete, bool closed) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _rename(context, cat, goal),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${cat == 'pro' ? 'PRO' : 'PERSO'} · $meter', style: K.body(10, color: color, w: FontWeight.w900)),
              Text(goal.isEmpty ? 'cap du jour…' : goal, style: K.body(13, color: goal.isEmpty ? K.dim : K.ink, w: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (complete && !closed)
                InkWell(
                  onTap: () async {
                    final ok = await store.closeQuest(cat);
                    if (ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Quête close ! +${cat == 'pro' ? 15 : 5} XP · Micky ronronne.')));
                  },
                  child: Text('🏁 Clore', style: K.body(12, color: color, w: FontWeight.w900)),
                ),
              if (closed) Text('close ✓', style: K.body(11, color: color, w: FontWeight.w800)),
            ]),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: K.lime.withValues(alpha: 0.35), width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          cap('pro', plan.pro, K.lime, goalMin > 0 ? '${fmtH(proTotal)} / ${fmtH(goalMin)}' : (pro.isEmpty ? '—' : '${pro.where((t) => t.done).length} / ${pro.length}'), pro.isNotEmpty && cur >= pro.length, proClosed),
          const SizedBox(width: 10),
          cap('perso', plan.perso, K.pink, perso.isEmpty ? '—' : '$persoDone / ${perso.length}', perso.isNotEmpty && persoDone == perso.length, persoClosed),
        ]),
        if (pro.isNotEmpty) ...[
          const SizedBox(height: 6),
          _stones(pro, cur, K.lime),
        ],
      ]),
    );
  }
}

/// La séquence du jour : 1, 2, 3… ; faites en haut, à faire ensuite ; sous-étapes en 4a, 4b ; glisser pour réordonner.
class _DayList extends StatelessWidget {
  const _DayList();

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final seq = store.daySequence();
    final done = seq.where((t) => t.done).toList();
    final todo = seq.where((t) => !t.done).toList();
    final mode = store.today.mode;
    // sur la vague, le projet passe devant dans le calcul des heures
    final sched = mode == 'vague'
        ? store.schedule([...done, ...todo.where((t) => t.plannedAt > 0 || store.inFocus(t)), ...todo.where((t) => !(t.plannedAt > 0) && !store.inFocus(t))])
        : store.schedule(seq);
    final now = DateTime.now();
    final endMs = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch + store.settings.workEnd * 60000;
    // ce qui commencerait après la fin de journée : du bonus, pas une dette
    // jour sans : 3 tâches ; sur la vague : le projet du jour (et les ancres) ; le reste se replie
    final aside = <Task>[];
    if (mode == 'sans') {
      final keep = todo.where((t) => t.plannedAt > 0 || store.isHabitTask(t)).toList();
      for (final t in todo) {
        if (keep.contains(t)) continue;
        if (keep.where((x) => !(x.plannedAt > 0) && !store.isHabitTask(x)).length < 3) {
          keep.add(t);
        } else {
          aside.add(t);
        }
      }
    } else if (mode == 'vague') {
      aside.addAll(todo.where((t) => !(t.plannedAt > 0) && !store.inFocus(t)));
    }
    final bonus = todo.where((t) => !aside.contains(t) && (sched.times[t.id]?.$1 ?? 0) >= endMs && !(t.plannedAt > 0) && mode != 'vague').toList();
    final main = todo.where((t) => !bonus.contains(t) && !aside.contains(t)).toList();
    var fin = now.millisecondsSinceEpoch;
    for (final t in main) {
      fin = max(fin, sched.times[t.id]?.$2 ?? 0);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < done.length; i++) _SeqRow(task: done[i], n: '${i + 1}', key: ValueKey(done[i].id)),
        if (seq.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Rien dans la journée. Ajoute une tâche, ou récupère-en une dans « Plus tard ».', style: K.body(13, color: K.muted)),
          ),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: (a, b) => store.reorderDay(a, b > a ? b - 1 : b),
          children: [
            for (var i = 0; i < main.length; i++)
              _SeqRow(
                key: ValueKey(main[i].id),
                task: main[i],
                n: '${done.length + i + 1}',
                index: i,
                start: sched.times[main[i].id]?.$1,
                late: sched.late.contains(main[i].id),
                current: i == 0,
              ),
          ],
        ),
        if (main.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: 'Si tu suis l\'ordre : fini vers ', style: K.body(12, color: K.dim)),
              TextSpan(text: hm(DateTime.fromMillisecondsSinceEpoch(fin)), style: K.body(13, color: K.gold, w: FontWeight.w900)),
            ])),
          ),
        if (bonus.isNotEmpty) _BonusBlock(tasks: bonus, firstN: done.length + main.length + 1),
        if (aside.isNotEmpty)
          _BonusBlock(
            tasks: aside,
            firstN: done.length + main.length + bonus.length + 1,
            title: mode == 'sans' ? '🌧 Mis de côté aujourd\'hui (${aside.length}) · pas une dette' : '🌊 Le reste de la journée (${aside.length}) · attend ce soir',
            defer: mode == 'sans',
          ),
        Row(children: [
          TextButton.icon(
            onPressed: () => newTaskSheet(context, quad: Quad.doNow),
            icon: const Icon(Icons.add_rounded, color: K.lime, size: 18),
            label: Text('Tâche', style: K.body(13, color: K.lime, w: FontWeight.w800)),
          ),
          if (store.habits.any((h) => !h.archived))
            TextButton.icon(
              onPressed: () => _pickHabit(context, store),
              icon: const Icon(Icons.repeat_rounded, color: K.cyan, size: 18),
              label: Text('Habitude', style: K.body(13, color: K.cyan, w: FontWeight.w800)),
            ),
        ]),
      ]),
    );
  }
}

Future<void> _pickHabit(BuildContext context, AppStore store) async {
  final inList = store.tasks.where((t) => !t.removed && t.day == store.todayKey && t.link.startsWith('habit:')).map((t) => t.link.substring(6)).toSet();
  final hs = store.habits.where((h) => !h.archived && !inList.contains(h.id)).toList();
  if (hs.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Toutes tes habitudes sont déjà dans la liste.')));
    return;
  }
  final h = await showModalBottomSheet<Habit>(
    context: context,
    builder: (ctx) => SafeArea(
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(18, 16, 18, 10), children: [
        Text('Quelle habitude dans la liste ?', style: K.display(18)),
        Text('Elle se place en fin de liste ; glisse-la où tu veux. La cocher la coche aussi dans Habitudes.', style: K.body(12, color: K.muted)),
        const SizedBox(height: 6),
        for (final x in hs)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.repeat_rounded, color: K.cyan, size: 18),
            title: Text(x.name, style: K.body(14, w: FontWeight.w700)),
            subtitle: x.mini.isNotEmpty ? Text('mini : ${x.mini}', style: K.body(11, color: K.muted)) : null,
            onTap: () => Navigator.pop(ctx, x),
          ),
      ]),
    ),
  );
  if (h == null) return;
  await store.habitToToday(h);
}

/// Après la fin de journée (19 h par défaut) : bonus, repliés, à reporter en un geste.
class _BonusBlock extends StatefulWidget {
  final List<Task> tasks;
  final int firstN;
  final String title;
  final bool defer;
  const _BonusBlock({required this.tasks, required this.firstN, this.title = '', this.defer = true});

  @override
  State<_BonusBlock> createState() => _BonusBlockState();
}

class _BonusBlockState extends State<_BonusBlock> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final h = store.settings.workEnd;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: K.line, width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              if (widget.title.isEmpty) const Text('✨', style: TextStyle(fontSize: 16)),
              if (widget.title.isEmpty) const SizedBox(width: 6),
              Expanded(
                child: Text(
                    widget.title.isNotEmpty
                        ? widget.title
                        : 'Bonus après ${h ~/ 60} h${h % 60 == 0 ? '' : (h % 60).toString().padLeft(2, '0')} (${widget.tasks.length}) · si tu as encore de l\'énergie',
                    style: K.body(13, color: K.muted, w: FontWeight.w800)),
              ),
              Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: K.muted),
            ]),
          ),
        ),
        if (_open)
          for (var i = 0; i < widget.tasks.length; i++) _SeqRow(task: widget.tasks[i], n: '${widget.firstN + i}', key: ValueKey('b${widget.tasks[i].id}')),
        if (widget.defer)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () async {
              for (final t in widget.tasks) {
                await store.deferTask(t);
              }
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.tasks.length} tâche${widget.tasks.length > 1 ? 's' : ''} pour demain')));
            },
            child: Text('Tout reporter à demain', style: K.body(12, color: K.cyan, w: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }
}

class _SeqRow extends StatelessWidget {
  final Task task;
  final String n;
  final int? index; // null = faite (pas de poignée)
  final int? start;
  final bool late, current;
  const _SeqRow({super.key, required this.task, required this.n, this.index, this.start, this.late = false, this.current = false});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final t = task;
    final habit = store.isHabitTask(t);
    final color = habit ? K.cyan : t.category == 'pro' ? K.lime : t.category == 'perso' ? K.pink : K.gold;
    final anchor = t.plannedAt > 0 && dayKey(DateTime.fromMillisecondsSinceEpoch(t.plannedAt)) == store.todayKey;
    final running = store.runningSession?.taskId == t.id;
    final sub = <String>[
      if (habit) 'habitude',
      if (t.estimateMin > 0) fmtMin(t.estimateMin),
      if (running) 'en cours',
      if (!t.isBoss && t.progress > 0 && t.progress < 100) '${t.progress} %',
      if (t.isBoss) 'boss',
      if (t.link == 'boss') '→ boss',
      if (t.link == 'pro' || t.link == 'perso') '→ objectif',
      if (t.condition.isNotEmpty) 'si ${t.condition}',
    ];
    final subs = store.subStepsOf(t);
    final row = Container(
      padding: EdgeInsets.symmetric(vertical: current ? 6 : 4, horizontal: current ? 6 : 0),
      decoration: current ? BoxDecoration(color: K.bg, borderRadius: BorderRadius.circular(12)) : null,
      child: Row(children: [
        SizedBox(width: 24, child: Text(n, textAlign: TextAlign.right, style: K.display(15, color: t.done ? K.dim : color))),
        const SizedBox(width: 6),
        CheckCircle(task: t, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => t.isBoss ? openScreen(context, const BossScreen()) : showTaskPanel(context, t),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title, style: K.body(14, color: t.done ? K.muted : K.ink, w: FontWeight.w800).copyWith(decoration: t.done ? TextDecoration.lineThrough : null)),
              Row(children: [
                if (sub.isNotEmpty) Text(sub.join(' · '), style: K.body(11, color: K.muted)),
                if (sub.isNotEmpty && (anchor || start != null)) Text(' · ', style: K.body(11, color: K.muted)),
                if (anchor)
                  Text('📌 ${hm(DateTime.fromMillisecondsSinceEpoch(t.plannedAt))}${late ? ' · en retard' : ''}', style: K.body(11, color: late ? K.coral : K.gold, w: FontWeight.w900))
                else if (start != null && !t.done)
                  Text('~ ${hm(DateTime.fromMillisecondsSinceEpoch(start!))}', style: K.body(11, color: K.dim)),
              ]),
            ]),
          ),
        ),
        if (!t.done)
          IconButton(
            tooltip: 'Lancer',
            visualDensity: VisualDensity.compact,
            onPressed: () => launchTask(context, t),
            icon: Icon(Icons.play_circle_fill_rounded, color: color, size: 30),
          ),
        if (index != null)
          ReorderableDragStartListener(
            index: index!,
            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8), child: Icon(Icons.drag_handle_rounded, color: K.line, size: 22)),
          ),
      ]),
    );
    if (subs.isEmpty) return row;
    const letters = 'abcdefghij';
    return Column(children: [
      row,
      for (var i = 0; i < subs.length; i++)
        Padding(
          padding: const EdgeInsets.only(left: 22),
          child: Row(children: [
            SizedBox(width: 24, child: Text('$n${letters[i % letters.length]}', textAlign: TextAlign.right, style: K.display(12, color: subs[i].done ? K.dim : color))),
            const SizedBox(width: 6),
            CheckCircle(task: subs[i], color: color),
            Expanded(
              child: InkWell(
                onTap: () => showTaskPanel(context, subs[i]),
                child: Text('${subs[i].title}${subs[i].estimateMin > 0 ? ' · ${subs[i].estimateMin} min' : ''}',
                    style: K.body(13, color: subs[i].done ? K.muted : K.ink).copyWith(decoration: subs[i].done ? TextDecoration.lineThrough : null)),
              ),
            ),
            if (!subs[i].done)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => launchTask(context, subs[i]),
                icon: Icon(Icons.play_circle_outline_rounded, color: color, size: 24),
              ),
            const SizedBox(width: 30),
          ]),
        ),
    ]);
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
    final row = Padding(
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
                      if (!t.isBoss && t.progress > 0 && t.progress < 100) '${t.progress} %',
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
    final subs = store.subStepsOf(t);
    if (subs.isEmpty) return row;
    return Column(children: [
      row,
      for (final sub in subs)
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Row(children: [
            Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: sub.done ? K.dim : K.muted),
            CheckCircle(task: sub, color: color),
            Expanded(
              child: InkWell(
                onTap: () => showTaskPanel(context, sub),
                child: Text('${sub.title}${sub.estimateMin > 0 ? ' · ${sub.estimateMin} min' : ''}',
                    style: K.body(13, color: sub.done ? K.muted : K.ink).copyWith(decoration: sub.done ? TextDecoration.lineThrough : null)),
              ),
            ),
            if (!sub.done)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => launchTask(context, sub),
                icon: Icon(Icons.play_circle_outline_rounded, color: color, size: 24),
              ),
          ]),
        ),
    ]);
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
  @override
  Widget build(BuildContext context) => const TodayScreen();
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
            Text('Tes tâches « Planifier » sans jour. « Aujourd\'hui » les ajoute en fin de liste, « Pas auj. » les cache jusqu\'à demain.', style: K.body(11, color: K.muted)),
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
                        onTap: () => store.addToToday(t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: K.lime, borderRadius: BorderRadius.circular(999)),
                          child: Text('Aujourd\'hui', style: K.body(11, color: K.bg, w: FontWeight.w900)),
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

/// Bandeau « À trier » : chaque tâche s'ouvre sur le panneau (Quand ?, Ranger…).
class _ToSort extends StatefulWidget {
  const _ToSort();

  @override
  State<_ToSort> createState() => _ToSortState();
}

class _ToSortState extends State<_ToSort> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final list = store.tasksIn(Quad.inbox);
    return Panel(
      border: K.cyan,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Row(children: [
            Expanded(child: Text('À trier (${list.length})', style: K.display(15, color: K.cyan))),
            Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: K.cyan),
          ]),
        ),
        if (_open) ...[
          Text('Touche une tâche : aujourd\'hui, demain, cette semaine, ou plus tard.', style: K.body(11, color: K.muted)),
          const SizedBox(height: 4),
          for (final t in list.take(10))
            InkWell(
              onTap: () => showTaskPanel(context, t),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: t.category == 'pro' ? K.lime : t.category == 'perso' ? K.pink : K.muted, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t.title, style: K.body(14, w: FontWeight.w700))),
                  const Icon(Icons.chevron_right_rounded, color: K.muted, size: 18),
                ]),
              ),
            ),
        ],
      ]),
    );
  }
}

/// « Plus tard » : Planifier, Alléger, Un jour — replié, avec la matrice en lien.
class _Later extends StatefulWidget {
  const _Later();

  @override
  State<_Later> createState() => _LaterState();
}

class _LaterState extends State<_Later> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final groups = [
      (Quad.plan, 'Planifier', K.cyan),
      (Quad.light, 'Alléger', K.gold),
      (Quad.drop, 'Un jour', K.dim),
    ];
    final n = groups.fold(0, (a, g) => a + store.tasksIn(g.$1).where((t) => !store.inToday(t)).length);
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Row(children: [
            Expanded(child: Text('Plus tard ($n)', style: K.display(15, color: K.muted))),
            TextButton(onPressed: () => openScreen(context, const MatrixScreen(standalone: true)), child: Text('voir en matrice', style: K.body(12, color: K.cyan))),
            Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: K.muted),
          ]),
        ),
        if (_open)
          for (final g in groups) ...[
            if (store.tasksIn(g.$1).where((t) => !store.inToday(t)).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(g.$2.toUpperCase(), style: K.body(10, color: g.$3, w: FontWeight.w900)),
              for (final t in store.tasksIn(g.$1).where((t) => !store.inToday(t)))
                InkWell(
                  onTap: () => showTaskPanel(context, t),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: t.category == 'pro' ? K.lime : t.category == 'perso' ? K.pink : g.$3, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(t.title, style: K.body(13))),
                      if (t.condition.isNotEmpty) Text('si ${t.condition}', style: K.body(11, color: K.muted)),
                    ]),
                  ),
                ),
            ],
          ],
      ]),
    );
  }
}

/// Fusionner deux tâches : on garde l'une, l'autre disparaît (ses sous-étapes suivent).
Future<void> mergeSheet(BuildContext context, Task a, Task b) async {
  final store = AppScope.read(context);
  final keep = await showModalBottomSheet<Task>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Laquelle on garde ?', style: K.display(18)),
          const SizedBox(height: 4),
          Text('L\'autre disparaît ; sa durée, son heure et ses sous-étapes passent sur celle gardée.', style: K.body(12, color: K.muted)),
          const SizedBox(height: 10),
          for (final t in [a, b])
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.title, style: K.body(15, w: FontWeight.w800)),
              subtitle: Text([if (t.category.isNotEmpty) t.category, if (t.estimateMin > 0) '${t.estimateMin} min', if (t.plannedAt > 0) hm(DateTime.fromMillisecondsSinceEpoch(t.plannedAt))].join(' · '), style: K.body(12, color: K.muted)),
              onTap: () => Navigator.pop(ctx, t),
            ),
        ]),
      ),
    ),
  );
  if (keep == null) return;
  await store.mergeTasks(keep, keep.id == a.id ? b : a);
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fusionnées en « ${keep.title} »')));
}
