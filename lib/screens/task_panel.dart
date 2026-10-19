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
                  Text('QUAND ?', style: K.body(11, color: K.muted, w: FontWeight.w900).copyWith(letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: whenTile(ctx, 'Aujourd\'hui', '→ caser dans le planning', K.lime, K.bg, () => Navigator.pop(ctx, 'w:today'))),
                    const SizedBox(width: 8),
                    Expanded(child: whenTile(ctx, 'Demain', '→ caser demain', K.cyan, K.bg, () => Navigator.pop(ctx, 'w:tomorrow'))),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: whenTile(ctx, 'Cette semaine', '', K.raised, K.gold, () => Navigator.pop(ctx, 'w:week'), border: K.gold, child: Row(children: [
                        for (var i = 0; i < 7; i++)
                          Builder(builder: (_) {
                            final d = today.add(Duration(days: i));
                            final sel = d == weekDay;
                            const n = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 3),
                              child: InkWell(
                                onTap: () => setState(() => weekDay = d),
                                child: Container(
                                  width: 18,
                                  height: 20,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: sel ? K.gold : K.line, borderRadius: BorderRadius.circular(6)),
                                  child: Text(n[d.weekday - 1], style: K.body(10, color: sel ? K.bg : K.ink, w: FontWeight.w900)),
                                ),
                              ),
                            );
                          }),
                      ])),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: whenTile(ctx, 'Seulement quand…', t.condition.isNotEmpty ? '« ${t.condition} »' : 'une condition', K.raised, K.pink, () => Navigator.pop(ctx, 'w:cond'), border: K.pink),
                    ),
                  ]),
                  if (planned)
                    Row(children: [
                      small('Durée (${fmtMin(t.blockMin)})', Icons.timer_outlined, K.cyan, 'len'),
                      small('Retirer du planning', Icons.close_rounded, K.coral, 'unplan'),
                    ]),
                  const SizedBox(height: 12),
                  Text('QUÊTE', style: K.body(11, color: K.muted, w: FontWeight.w900).copyWith(letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Wrap(children: [
                    chip('Pro', t.category == 'pro', K.lime, () async {
                      await store.editTask(t, category: t.category == 'pro' ? '' : 'pro');
                      setState(() {});
                    }),
                    chip('Perso', t.category == 'perso', K.pink, () async {
                      await store.editTask(t, category: t.category == 'perso' ? '' : 'perso');
                      setState(() {});
                    }),
                    if (t.category.isNotEmpty)
                      chip('Étape de la quête du jour', t.inQuest, K.gold, () async {
                        await store.editTask(t, inQuest: !t.inQuest);
                        setState(() {});
                      }),
                  ]),
                  const Divider(color: K.line, height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      small('Ranger', Icons.grid_view_rounded, K.ink, 'sort'),
                      small('Découper', Icons.content_cut_rounded, K.cyan, 'cut'),
                      small('Modifier', Icons.edit_rounded, K.ink, 'edit'),
                      small(t.isBoss ? 'Boss' : 'Boss', Icons.pest_control_rounded, K.coral, 'boss'),
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
    case 'len':
      final v = await showModalBottomSheet<int>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in [15, 30, 45, 60, 90, 120, 180, 240])
                ActionChip(label: Text(fmtMin(m)), backgroundColor: K.raised, side: BorderSide.none, onPressed: () => Navigator.pop(ctx, m)),
            ]),
          ),
        ),
      );
      if (v == null) return;
      t.plannedMin = v;
      await store.commit();
      await PhoneCalendar.writeBlock(store, t);
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

/// Nouvelle tâche : titre, pro/perso, étape de quête, pari, case.
Future<void> newTaskSheet(BuildContext context, {String quad = Quad.inbox, String category = ''}) async {
  final store = AppScope.read(context);
  final c = TextEditingController();
  var cat = category;
  var inQuest = false;
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

      final questName = cat == 'pro' ? store.today.pro : cat == 'perso' ? store.today.perso : '';
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
                  chip('Aucun', cat.isEmpty, K.muted, () => setState(() {
                        cat = '';
                        inQuest = false;
                      })),
                ]),
                if (cat.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: K.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: inQuest ? K.gold : K.line, width: 2),
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: inQuest,
                      activeColor: K.gold,
                      onChanged: (v) => setState(() {
                        inQuest = v;
                        if (v && where == Quad.inbox) where = Quad.doNow;
                      }),
                      title: Text('Étape de la quête ${cat == 'pro' ? 'pro' : 'perso'} du jour', style: K.body(13, w: FontWeight.w800)),
                      subtitle: Text(
                        questName.isEmpty ? 'quête pas encore nommée' : '$questName / ${c.text.isEmpty ? '…' : c.text}',
                        style: K.body(12, color: K.gold, w: FontWeight.w800),
                      ),
                    ),
                  ),
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
  final t = await store.addTask(title, category: cat, estimate: min, quad: where, inQuest: inQuest);
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
