import 'package:flutter/material.dart';

import '../calendar.dart';
import '../main.dart';
import '../models.dart';
import '../notifications.dart';
import '../theme.dart';
import 'boss.dart';
import 'dump.dart';
import 'timetable.dart';
import 'today.dart';

/// Coche une tâche, avec « Annuler » pendant 5 s, puis « et maintenant ? ».
Future<void> checkTask(BuildContext context, Task t, {bool askAfter = true}) async {
  final store = AppScope.read(context);
  final wasDone = t.done;
  await store.completeTask(t);
  if (store.isHabitTask(t)) {
    if (context.mounted && t.done) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Habitude « ${t.title} » faite ✓')));
    return;
  }
  if (!context.mounted || wasDone) return;
  // faite sans session : combien de temps dessus ? (30 min si on passe)
  final spent = store.sessions.any((x) => x.taskId == t.id && x.end > 0 && dayKey(DateTime.fromMillisecondsSinceEpoch(x.start)) == store.todayKey);
  if (!spent && t.done) {
    final m = await _askTimeSpent(context, t);
    final end = DateTime.now();
    await store.saveSlot(Slot(
      start: end.subtract(Duration(minutes: m)).millisecondsSinceEpoch,
      end: end.millisecondsSinceEpoch,
      kind: t.category == 'perso' ? 'perso' : 'pro',
      title: t.title,
    ));
    if (!context.mounted) return;
  }
  final xp = store.taskXp(t);
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    duration: const Duration(seconds: 5),
    content: Text('Tâche faite · +$xp XP'),
    action: SnackBarAction(
      label: 'ANNULER',
      textColor: K.gold,
      onPressed: () async {
        if (t.done) await store.completeTask(t);
      },
    ),
  ));
  if (askAfter && t.done) await askNext(context, 'Tâche faite !');
}

/// Le panneau d'actions d'une tâche, le même partout (QG, Aujourd'hui, Trier, planning).
Future<void> showTaskPanel(BuildContext context, Task t) async {
  final store = AppScope.read(context);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  var weekDay = today.add(const Duration(days: 2));
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => AppScope(
      store: store,
      child: StatefulBuilder(
        builder: (ctx, setState) {
          final planned = t.plannedAt > 0;
          final inToday = store.inToday(t);
          Widget small(String label, IconData icon, Color c, String id) => InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.pop(ctx, id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, color: c, size: 18),
                    const SizedBox(width: 4),
                    Text(label, style: K.body(12, color: c, w: FontWeight.w800)),
                  ]),
                ),
              );
          Widget chip(String label, bool on, Color c, VoidCallback onTap) => Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: on ? c : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: on ? c : K.line, width: 2),
                    ),
                    child: Text(label, style: K.body(12, color: on ? K.bg : K.ink, w: FontWeight.w800)),
                  ),
                ),
              );
          final questName = t.category == 'pro' ? store.today.pro : t.category == 'perso' ? store.today.perso : '';
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: K.line, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 10),
                  Row(children: [
                    Pill(t.inQuest ? 'ÉTAPE DE QUÊTE' : (Quad.titles[t.quad] ?? '').toUpperCase(), color: K.bg, fill: K.quadColors[t.quad] ?? K.gold),
                    const SizedBox(width: 8),
                    if (t.estimateMin > 0) Text('${t.estimateMin} min', style: K.body(12, color: K.muted)),
                    if (planned) Text('  ·  ⏰ ${hm(DateTime.fromMillisecondsSinceEpoch(t.plannedAt))}', style: K.body(12, color: K.gold, w: FontWeight.w800)),
                    if (t.condition.isNotEmpty) Expanded(child: Text('  ·  si ${t.condition}', style: K.body(12, color: K.pink), overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 4),
                  Text(t.inQuest && questName.isNotEmpty ? '$questName / ${t.title}' : t.title, style: K.display(20)),
                  const SizedBox(height: 10),
                  if (!t.done)
                    Row(children: [
                      Expanded(child: PrimaryButton(label: '▶  Lancer', onPressed: () => Navigator.pop(ctx, 'go'))),
                      const SizedBox(width: 8),
                      Expanded(child: SecondaryButton(label: '✓  C\'est fait', onPressed: () => Navigator.pop(ctx, 'done'))),
                    ])
                  else
                    SecondaryButton(label: 'Décocher', onPressed: () => Navigator.pop(ctx, 'undone')),
                  const SizedBox(height: 12),
                  if (t.parentId.isEmpty) ...[
                    Text('PLACE', style: K.body(11, color: K.muted, w: FontWeight.w900).copyWith(letterSpacing: 1)),
                    const SizedBox(height: 6),
                    Wrap(children: [
                      chip('↑ En tête', false, K.lime, () => Navigator.pop(ctx, 'head')),
                      chip('↓ Plus tard', false, K.muted, () => Navigator.pop(ctx, 'later')),
                      chip('↳ Sous-étape de…', false, K.cyan, () => Navigator.pop(ctx, 'subof')),
                    ]),
                    Text('Pour le reste de l\'ordre : tire la poignée ≡ dans la liste.', style: K.body(11, color: K.dim)),
                    const SizedBox(height: 10),
                  ],
                  Text('QUEL JOUR ?', style: K.body(11, color: K.muted, w: FontWeight.w900).copyWith(letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Wrap(children: [
                    chip('Aujourd\'hui', inToday, K.lime, () => Navigator.pop(ctx, 'w:today')),
                    chip('Demain', t.day == store.tomorrowKey && !inToday, K.cyan, () => Navigator.pop(ctx, 'w:tomorrow')),
                    chip('Seulement quand…', t.condition.isNotEmpty, K.pink, () => Navigator.pop(ctx, 'w:cond')),
                  ]),
                  Row(children: [
                    Text('cette semaine : ', style: K.body(12, color: K.muted)),
                    for (var i = 2; i < 7; i++)
                      Builder(builder: (_) {
                        final d = today.add(Duration(days: i));
                        final sel = t.day == dayKey(d) && !t.done;
                        const n = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: InkWell(
                            onTap: () {
                              weekDay = d;
                              Navigator.pop(ctx, 'w:week');
                            },
                            child: Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: sel ? K.gold : K.line, borderRadius: BorderRadius.circular(6)),
                              child: Text(n[d.weekday - 1], style: K.body(11, color: sel ? K.bg : K.ink, w: FontWeight.w900)),
                            ),
                          ),
                        );
                      }),
                  ]),
                  const SizedBox(height: 10),
                  Text('ANCRE (FACULTATIF)', style: K.body(11, color: K.muted, w: FontWeight.w900).copyWith(letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Padding(padding: const EdgeInsets.only(right: 6, bottom: 6), child: Text('📌 pas avant', style: K.body(12, color: K.muted))),
                    chip('—', !planned, K.gold, () async {
                      if (planned) await store.unplanTask(t);
                      setState(() {});
                    }),
                    for (final h in [9, 12, 14, 16])
                      chip('${h}h', planned && DateTime.fromMillisecondsSinceEpoch(t.plannedAt).hour == h && DateTime.fromMillisecondsSinceEpoch(t.plannedAt).minute == 0 && dayKey(DateTime.fromMillisecondsSinceEpoch(t.plannedAt)) == t.day, K.gold, () async {
                        final d = DateTime.parse(t.day.compareTo(store.todayKey) < 0 ? store.todayKey : t.day);
                        await store.planTask(t, DateTime(d.year, d.month, d.day, h));
                        await rescheduleAll(store);
                        setState(() {});
                      }),
                    chip(planned ? hm(DateTime.fromMillisecondsSinceEpoch(t.plannedAt)) : 'autre…', planned && ![9, 12, 14, 16].contains(DateTime.fromMillisecondsSinceEpoch(t.plannedAt).hour), K.gold, () async {
                      final at = await pickWhen(ctx, initial: planned ? DateTime.fromMillisecondsSinceEpoch(t.plannedAt) : null, title: 'Pas avant…');
                      if (at == null) return;
                      await store.planTask(t, at);
                      await rescheduleAll(store);
                      setState(() {});
                    }),
                  ]),
                  Text('Seulement pour un vrai rendez-vous : le déroulé attend cette heure.', style: K.body(11, color: K.dim)),
                  const SizedBox(height: 10),
                  Text('TEMPS ESTIMÉ', style: K.body(11, color: K.muted, w: FontWeight.w900).copyWith(letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Wrap(children: [
                    for (final m in [15, 30, 45, 60, 90, 120, 180])
                      chip(fmtMin(m), t.estimateMin == m, K.cyan, () async {
                        t.estimateMin = m;
                        if (t.plannedAt > 0) t.plannedMin = m;
                        await store.commit();
                        setState(() {});
                      }),
                    chip(![15, 30, 45, 60, 90, 120, 180].contains(t.estimateMin) && t.estimateMin > 0 ? fmtMin(t.estimateMin) : 'autre…', ![15, 30, 45, 60, 90, 120, 180].contains(t.estimateMin) && t.estimateMin > 0, K.cyan, () async {
                      final v = await askText(ctx, 'Temps estimé (minutes)', hint: '75', initial: t.estimateMin > 0 ? '${t.estimateMin}' : '');
                      final m = int.tryParse((v ?? '').trim());
                      if (m == null || m <= 0) return;
                      t.estimateMin = m;
                      if (t.plannedAt > 0) t.plannedMin = m;
                      await store.commit();
                      setState(() {});
                    }),
                  ]),
                  const SizedBox(height: 12),
                  Text('PRO / PERSO', style: K.body(11, color: K.muted, w: FontWeight.w900).copyWith(letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Wrap(children: [
                    chip('Pro', t.category == 'pro', K.lime, () async {
                      await store.editTask(t, category: t.category == 'pro' ? '' : 'pro', inQuest: true);
                      setState(() {});
                    }),
                    chip('Perso', t.category == 'perso', K.pink, () async {
                      await store.editTask(t, category: t.category == 'perso' ? '' : 'perso', inQuest: true);
                      setState(() {});
                    }),
                  ]),
                  const SizedBox(height: 8),
                  Text('ÇA COMPTE POUR…', style: K.body(11, color: K.muted, w: FontWeight.w900).copyWith(letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Wrap(children: [
                    if (t.category != 'perso')
                      chip(store.settings.dirPro.isNotEmpty ? '→ ${store.settings.dirPro}' : '→ objectif pro', store.effectiveLink(t) == 'pro', K.lime, () async {
                        if (t.category == 'pro') {
                          if (t.link == 'boss') await store.setLink(t, 'boss');
                        } else {
                          await store.setLink(t, 'pro');
                        }
                        setState(() {});
                      }),
                    if (t.category != 'pro')
                      chip(store.settings.dirPerso.isNotEmpty ? '→ ${store.settings.dirPerso}' : '→ objectif perso', store.effectiveLink(t) == 'perso', K.pink, () async {
                        if (t.category == 'perso') {
                          if (t.link == 'boss') await store.setLink(t, 'boss');
                        } else {
                          await store.setLink(t, 'perso');
                        }
                        setState(() {});
                      }),
                    if (store.boss != null && store.boss!.id != t.id)
                      chip('→ le boss', t.link == 'boss', K.coral, () async {
                        await store.setLink(t, 'boss');
                        setState(() {});
                      }),
                  ]),
                  Text(
                    t.link == 'boss'
                        ? 'Chaque coche entame le boss (+10 XP).'
                        : store.effectiveLink(t).isEmpty
                            ? 'Sans pro / perso, elle ne compte pour aucun objectif.'
                            : 'Une tâche ${t.category} est un pas de la semaine vers le jalon ${t.category} (Ma direction, briefing, +5 XP).',
                    style: K.body(11, color: K.muted),
                  ),
                  if (t.parentId.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text('SOUS-ÉTAPES', style: K.body(11, color: K.muted, w: FontWeight.w900).copyWith(letterSpacing: 1)),
                    for (final sub in store.subStepsOf(t))
                      Row(children: [
                        CheckCircle(task: sub, color: K.cyan),
                        Expanded(child: Text('${sub.title}${sub.estimateMin > 0 ? ' · ${sub.estimateMin} min' : ''}', style: K.body(13, color: sub.done ? K.muted : K.ink).copyWith(decoration: sub.done ? TextDecoration.lineThrough : null))),
                        IconButton(
                          tooltip: 'Détacher',
                          visualDensity: VisualDensity.compact,
                          onPressed: () async {
                            await store.detachSub(sub);
                            setState(() {});
                          },
                          icon: const Icon(Icons.link_off_rounded, color: K.muted, size: 18),
                        ),
                      ]),
                    TextButton.icon(
                      onPressed: () async {
                        await subStepSheet(context, t);
                        setState(() {});
                      },
                      icon: const Icon(Icons.subdirectory_arrow_right_rounded, color: K.cyan, size: 18),
                      label: Text('Ajouter ou rattacher une sous-étape', style: K.body(13, color: K.cyan, w: FontWeight.w800)),
                    ),
                  ] else if (store.taskById(t.parentId) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(children: [
                        Expanded(child: Text('Sous-étape de « ${store.taskById(t.parentId)!.title} »', style: K.body(12, color: K.muted))),
                        TextButton(
                          onPressed: () async {
                            await store.detachSub(t);
                            setState(() {});
                          },
                          child: Text('détacher', style: K.body(12, color: K.cyan, w: FontWeight.w800)),
                        ),
                      ]),
                    ),
                  const Divider(color: K.line, height: 18),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      small('Ranger', Icons.grid_view_rounded, K.ink, 'sort'),
                      small('Découper', Icons.content_cut_rounded, K.cyan, 'cut'),
                      small('Modifier', Icons.edit_rounded, K.ink, 'edit'),
                      small(t.isBoss ? 'Boss' : 'Boss', Icons.pest_control_rounded, K.coral, 'boss'),
                      small('Fusionner', Icons.call_merge_rounded, K.gold, 'merge'),
                      small('Supprimer', Icons.delete_outline_rounded, K.muted, 'delete'),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
  if (result == null || !context.mounted) return;
  if (result.startsWith('w:')) {
    await applyWhen(context, t, result.substring(2), day: weekDay);
    return;
  }
  switch (result) {
    case 'go':
      await launchTask(context, t);
      break;
    case 'done':
      await checkTask(context, t);
      break;
    case 'undone':
      await store.completeTask(t);
      break;
    case 'head':
      await store.toHead(t);
      break;
    case 'later':
      await store.laterTask(t);
      await rescheduleAll(store);
      break;
    case 'subof':
      final cands = store.openTasks.where((x) => x.id != t.id && x.parentId.isEmpty).toList();
      final parent = await showModalBottomSheet<Task>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('« ${t.title} » devient une sous-étape de…', style: K.display(17)),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.55),
                child: ListView(shrinkWrap: true, children: [
                  for (final x in cands)
                    ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(x.title, style: K.body(14, w: FontWeight.w700)), onTap: () => Navigator.pop(ctx, x)),
                ]),
              ),
            ]),
          ),
        ),
      );
      if (parent == null) return;
      await store.attachSub(parent, t);
      await rescheduleAll(store);
      break;
    case 'merge':
      final cands = store.openTasks.where((x) => x.id != t.id && x.parentId.isEmpty).toList();
      final other = await showModalBottomSheet<Task>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Fusionner « ${t.title} » avec…', style: K.display(17)),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.55),
                child: ListView(shrinkWrap: true, children: [
                  for (final x in cands)
                    ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(x.title, style: K.body(14, w: FontWeight.w700)), onTap: () => Navigator.pop(ctx, x)),
                ]),
              ),
            ]),
          ),
        ),
      );
      if (other == null || !context.mounted) return;
      await mergeSheet(context, t, other);
      break;
    case 'unplan':
      await store.unplanTask(t);
      await rescheduleAll(store);
      break;
    case 'sort':
      final q = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: _quadBtn(ctx, Quad.doNow, t)),
                const SizedBox(width: 8),
                Expanded(child: _quadBtn(ctx, Quad.plan, t)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _quadBtn(ctx, Quad.light, t)),
                const SizedBox(width: 8),
                Expanded(child: _quadBtn(ctx, Quad.drop, t)),
              ]),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: _quadBtn(ctx, Quad.inbox, t)),
            ]),
          ),
        ),
      );
      if (q == null || !context.mounted) return;
      await store.moveTask(t, q);
      if (q == Quad.plan && t.plannedAt == 0 && t.condition.isEmpty && context.mounted) await whenSheet(context, t);
      break;
    case 'edit':
      await editTaskSheet(context, t);
      break;
    case 'cut':
      final first = await Navigator.of(context).push<Task?>(MaterialPageRoute(builder: (_) => DumpScreen(cut: t)));
      if (first != null && context.mounted) await launchTask(context, first);
      break;
    case 'boss':
      if (!t.isBoss) await store.setBoss(t);
      if (context.mounted) await openScreen(context, const BossScreen());
      break;
    case 'delete':
      await store.removeTask(t);
      await rescheduleAll(store);
      break;
  }
}

Widget _quadBtn(BuildContext ctx, String q, Task t) {
  final c = K.quadColors[q] ?? K.muted;
  final on = t.quad == q;
  return SizedBox(
    height: q == Quad.inbox ? 44 : 64,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: on ? c : K.quadBg[q],
        side: BorderSide(color: c, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      onPressed: () => Navigator.pop(ctx, q),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(Quad.titles[q]!, style: K.display(14, color: on ? K.bg : c)),
        if (Quad.hints[q] != null) Text(Quad.hints[q]!, style: K.body(10, color: on ? K.bg : K.muted), textAlign: TextAlign.center),
      ]),
    ),
  );
}

/// Nouvelle tâche : titre, pro/perso, pari, case.
Future<void> newTaskSheet(BuildContext context, {String quad = Quad.inbox, String category = ''}) async {
  final store = AppScope.read(context);
  final c = TextEditingController();
  var cat = category;
  var min = 0;
  var where = quad;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      Widget chip(String label, bool on, Color col, VoidCallback onTap) => Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: on ? col : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: on ? col : K.line, width: 2),
                ),
                child: Text(label, style: K.body(12, color: on ? K.bg : K.ink, w: FontWeight.w800)),
              ),
            ),
          );
      Widget whereBtn(String q, String label) {
        final col = K.quadColors[q] ?? K.muted;
        final on = where == q;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => where = q),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? col : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: on ? col : K.line, width: 2),
                ),
                child: Text(label, textAlign: TextAlign.center, style: K.body(12, color: on ? K.bg : K.ink, w: FontWeight.w800)),
              ),
            ),
          ),
        );
      }

      String label(String s) => s.toUpperCase();
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: K.line, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 10),
                Text('Nouvelle tâche', style: K.display(20)),
                const SizedBox(height: 8),
                TextField(
                  controller: c,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'relire l\'intro, prendre RDV…'),
                ),
                const SizedBox(height: 10),
                Text(label('C\'est'), style: K.body(11, color: K.muted, w: FontWeight.w900)),
                const SizedBox(height: 6),
                Wrap(children: [
                  chip('Pro', cat == 'pro', K.lime, () => setState(() => cat = 'pro')),
                  chip('Perso', cat == 'perso', K.pink, () => setState(() => cat = 'perso')),
                  chip('Aucun', cat.isEmpty, K.muted, () => setState(() => cat = '')),
                ]),
                const SizedBox(height: 10),
                Text(label('Pari'), style: K.body(11, color: K.muted, w: FontWeight.w900)),
                const SizedBox(height: 6),
                Wrap(children: [
                  for (final m in [10, 15, 25, 45, 60, 90, 120]) chip('$m', min == m, K.cyan, () => setState(() => min = min == m ? 0 : m)),
                ]),
                const SizedBox(height: 6),
                Text(label('Où ?'), style: K.body(11, color: K.muted, w: FontWeight.w900)),
                const SizedBox(height: 4),
                Row(children: [whereBtn(Quad.inbox, 'À trier'), whereBtn(Quad.doNow, 'Faire maintenant')]),
                Row(children: [whereBtn(Quad.plan, 'Planifier → Quand ?'), whereBtn(Quad.light, 'Alléger')]),
                Row(children: [whereBtn(Quad.drop, 'Laisser tomber'), const Expanded(child: SizedBox())]),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Ajouter',
                  onPressed: () {
                    if (c.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }),
  );
  final title = c.text.trim();
  c.dispose();
  if (ok != true || title.isEmpty) return;
  final t = await store.addTask(title, category: cat, estimate: min, quad: where, inQuest: true);
  if (where == Quad.plan && context.mounted) await whenSheet(context, t);
}

/// Utilisé par la liste du QG et d'Aujourd'hui : rond = cocher, titre = panneau.
class CheckCircle extends StatelessWidget {
  final Task task;
  final Color color;
  const CheckCircle({super.key, required this.task, required this.color});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => checkTask(context, task),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Icon(task.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: task.done ? color : K.muted, size: 26),
          ),
        ),
      );
}

/// « Depuis combien de temps tu étais dessus ? » — 30 min par défaut.
Future<int> _askTimeSpent(BuildContext context, Task t) async {
  final v = await showModalBottomSheet<int>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tu y as passé combien de temps ?', style: K.display(18)),
          const SizedBox(height: 4),
          Text('« ${t.title} » · compté dans ton temps ${t.category == 'perso' ? 'perso' : 'pro'}. Sans réponse : 30 min.', style: K.body(12, color: K.muted)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in [5, 15, 30, 45, 60, 90, 120, 180])
              ActionChip(
                label: Text(m >= 60 ? '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60}'}' : '$m min'),
                onPressed: () => Navigator.pop(ctx, m),
                backgroundColor: m == 30 ? K.lime : K.raised,
                labelStyle: K.body(13, color: m == 30 ? K.bg : K.ink, w: FontWeight.w800),
                side: BorderSide.none,
              ),
          ]),
        ]),
      ),
    ),
  );
  return v ?? 30;
}

/// Nouvelle sous-étape pour [parent], ou rattacher une tâche existante (elle entre dans son bloc du planning).
Future<void> subStepSheet(BuildContext context, Task parent) async {
  final store = AppScope.read(context);
  final c = TextEditingController();
  var min = 0;
  final cands = store.openTasks.where((x) => x.id != parent.id && !x.isBoss).toList();
  final picked = <String>{};
  final res = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              children: [
                Text('Sous-étape de « ${parent.title} »', style: K.display(18)),
                const SizedBox(height: 4),
                Text('Elle vit dans le bloc de la tâche ; si ça dépasse, le bloc s\'allonge.', style: K.body(12, color: K.muted)),
                const SizedBox(height: 10),
                TextField(
                  controller: c,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Nouvelle sous-étape…'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final m in [10, 15, 25, 45, 60])
                    ChoiceChip(
                      label: Text('$m min'),
                      selected: min == m,
                      onSelected: (_) => setState(() => min = min == m ? 0 : m),
                      selectedColor: K.cyan,
                      labelStyle: K.body(12, color: min == m ? K.bg : K.ink, w: FontWeight.w800),
                      backgroundColor: K.raised,
                      side: BorderSide.none,
                      showCheckmark: false,
                    ),
                ]),
                const SizedBox(height: 8),
                PrimaryButton(label: 'Ajouter', onPressed: c.text.trim().isEmpty ? null : () => Navigator.pop(ctx, c.text.trim())),
                if (cands.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('OU RATTACHER DES TÂCHES EXISTANTES', style: K.body(11, color: K.muted, w: FontWeight.w900).copyWith(letterSpacing: 1)),
                  for (final x in cands)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: K.cyan,
                      value: picked.contains(x.id),
                      onChanged: (v) => setState(() => v == true ? picked.add(x.id) : picked.remove(x.id)),
                      title: Text(x.title, style: K.body(14, w: FontWeight.w700)),
                      subtitle: Text([if (x.category.isNotEmpty) x.category, if (x.estimateMin > 0) '${x.estimateMin} min', if (x.plannedAt > 0) '📌 ${hm(DateTime.fromMillisecondsSinceEpoch(x.plannedAt))}'].join(' · '), style: K.body(11, color: K.muted)),
                    ),
                  const SizedBox(height: 6),
                  PrimaryButton(label: picked.isEmpty ? 'Rattacher' : 'Rattacher (${picked.length})', color: K.cyan, onPressed: picked.isEmpty ? null : () => Navigator.pop(ctx, picked.toList())),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
  c.dispose();
  if (res == null) return;
  if (res is List<String>) {
    for (final id in res) {
      final x = store.taskById(id);
      if (x != null) await store.attachSub(parent, x);
    }
  } else if (res is String) {
    await store.addSub(parent, res, minutes: min);
  }
  await rescheduleAll(store);
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sous-étape de « ${parent.title} »')));
}
