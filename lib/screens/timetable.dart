import 'dart:math';

import 'package:flutter/material.dart';

import '../agenda.dart';
import '../main.dart';
import '../models.dart';
import '../notifications.dart';
import '../store.dart';
import '../theme.dart';
import 'block.dart';
import 'session.dart';

String fmtMin(int m) => m >= 60 ? '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60}'}' : '$m min';

/// Choisit un jour et une heure. Renvoie null si annulé.
Future<DateTime?> pickWhen(BuildContext context, {DateTime? initial, String title = 'Quand ?'}) async {
  final now = DateTime.now();
  var day = DateTime(now.year, now.month, now.day);
  final init = initial ?? now.add(const Duration(hours: 1));
  if (initial != null) day = DateTime(initial.year, initial.month, initial.day);
  var hour = init.hour;
  var minute = (init.minute ~/ 15) * 15;
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: K.display(20)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < 7; i++)
                    Builder(builder: (_) {
                      final d = DateTime(now.year, now.month, now.day).add(Duration(days: i));
                      final sel = d == day;
                      const names = ['lun', 'mar', 'mer', 'jeu', 'ven', 'sam', 'dim'];
                      return ChoiceChip(
                        label: Text(i == 0 ? 'Aujourd\'hui' : i == 1 ? 'Demain' : '${names[d.weekday - 1]} ${d.day}'),
                        selected: sel,
                        onSelected: (_) => setState(() => day = d),
                        selectedColor: K.gold,
                        labelStyle: K.body(13, color: sel ? K.bg : K.ink),
                        backgroundColor: K.raised,
                        side: BorderSide.none,
                        showCheckmark: false,
                      );
                    }),
                  ActionChip(
                    label: Text('Autre date', style: K.body(13)),
                    backgroundColor: K.raised,
                    side: BorderSide.none,
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: day,
                        firstDate: now.subtract(const Duration(days: 1)),
                        lastDate: now.add(const Duration(days: 365)),
                      );
                      if (d != null) setState(() => day = DateTime(d.year, d.month, d.day));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('À', style: K.display(16, color: K.gold)),
                  const SizedBox(width: 12),
                  _Stepper(
                    value: hour,
                    min: 0,
                    max: 23,
                    label: '${hour.toString().padLeft(2, '0')} h',
                    onChanged: (v) => setState(() => hour = v),
                  ),
                  const SizedBox(width: 12),
                  _Stepper(
                    value: minute ~/ 15,
                    min: 0,
                    max: 3,
                    label: minute.toString().padLeft(2, '0'),
                    onChanged: (v) => setState(() => minute = v * 15),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'C\'est noté',
                onPressed: () => Navigator.pop(ctx, DateTime(day.year, day.month, day.day, hour, minute)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Stepper extends StatelessWidget {
  final int value, min, max;
  final String label;
  final void Function(int) onChanged;
  const _Stepper({required this.value, required this.min, required this.max, required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: K.raised, borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => onChanged(value <= min ? max : value - 1),
              icon: const Icon(Icons.remove_rounded, color: K.ink),
            ),
            SizedBox(width: 48, child: Center(child: Text(label, style: K.display(18)))),
            IconButton(
              onPressed: () => onChanged(value >= max ? min : value + 1),
              icon: const Icon(Icons.add_rounded, color: K.ink),
            ),
          ],
        ),
      );
}

/// « Planifier » depuis la matrice : une heure, ou une condition.
Future<void> planSheet(BuildContext context, Task t) async {
  final store = AppScope.read(context);
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.title, style: K.display(18)),
            const SizedBox(height: 4),
            Text('Quand est-ce que tu t\'y mets ?', style: K.body(13, color: K.muted)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.schedule_rounded, color: K.gold),
              title: Text('À une heure précise', style: K.body(15)),
              subtitle: Text('Un bloc dans ta journée, avec rappel « c\'est l\'heure »', style: K.body(12, color: K.muted)),
              onTap: () => Navigator.pop(ctx, 'when'),
            ),
            ListTile(
              leading: const Icon(Icons.rule_rounded, color: K.cyan),
              title: Text('Seulement quand…', style: K.body(15)),
              subtitle: Text('« …j\'ai reçu la réponse de X », « …il fait jour »', style: K.body(12, color: K.muted)),
              onTap: () => Navigator.pop(ctx, 'cond'),
            ),
            ListTile(
              leading: const Icon(Icons.inbox_rounded, color: K.muted),
              title: Text('Juste dans « Planifier », sans heure', style: K.body(15)),
              onTap: () => Navigator.pop(ctx, 'none'),
            ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'when') {
    final at = await pickWhen(context);
    if (at == null) return;
    await store.planTask(t, at);
    await rescheduleAll(store);
  } else if (choice == 'cond') {
    final c = await askText(context, 'Seulement quand…', hint: 'j\'ai reçu la réponse de Nathalie');
    if (c == null || c.isEmpty) return;
    await store.setCondition(t, c);
  } else {
    await store.moveTask(t, Quad.plan);
  }
}

Future<String?> askText(BuildContext context, String title, {String hint = '', String initial = ''}) async {
  final c = TextEditingController(text: initial);
  final text = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: K.card,
      title: Text(title, style: K.display(20)),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('OK')),
      ],
    ),
  );
  c.dispose();
  return text?.trim();
}

/// La journée en blocs : ce qui est prévu, ce qui a été fait.
class TimetableScreen extends StatefulWidget {
  final String? day;
  const TimetableScreen({super.key, this.day});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  late DateTime _day;
  static const _hourH = 64.0;

  @override
  void initState() {
    super.initState();
    _day = widget.day == null ? DateTime.now() : parseDay(widget.day!);
    _day = DateTime(_day.year, _day.month, _day.day);
  }

  String get _key => dayKey(_day);

  Future<void> _addAt(DateTime at) async {
    final store = AppScope.read(context);
    final open = store.openTasks.where((t) => !t.done).toList();
    final chosen = await showModalBottomSheet<Task?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: [
              Text('À ${hm(at)} : quoi ?', style: K.display(18)),
              const SizedBox(height: 8),
              for (final t in open)
                ListTile(
                  leading: Container(width: 10, height: 10, decoration: BoxDecoration(color: K.quadColors[t.quad], shape: BoxShape.circle)),
                  title: Text(t.title, style: K.body(15)),
                  subtitle: t.plannedAt > 0 ? Text('déjà à ${hm(DateTime.fromMillisecondsSinceEpoch(t.plannedAt))}', style: K.body(12, color: K.muted)) : null,
                  onTap: () => Navigator.pop(ctx, t),
                ),
              ListTile(
                leading: const Icon(Icons.add_rounded, color: K.lime),
                title: Text('Nouvelle tâche', style: K.body(15)),
                onTap: () => Navigator.pop(ctx, Task(title: '', day: '')),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    Task t = chosen;
    if (t.title.isEmpty) {
      final title = await askText(context, 'Nouvelle tâche', hint: 'relire l\'intro');
      if (title == null || title.isEmpty) return;
      t = await store.addTask(title, quad: Quad.plan);
    }
    await store.planTask(t, at);
    await rescheduleAll(store);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.settings;
    final startH = min(s.startHour, 7);
    final endH = max(s.endHour, 22);
    final planned = store.plannedOn(_key);
    final sessions = store.sessionsOn(_key);
    final now = DateTime.now();
    final isToday = _key == store.todayKey;
    final dayMs = _day.millisecondsSinceEpoch;
    double top(int ts) => (ts - dayMs) / 3600000 * _hourH - startH * _hourH;

    const names = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    return Scaffold(
      appBar: AppBar(
        title: Text(isToday ? 'Ma journée' : '${names[_day.weekday - 1]} ${_day.day}/${_day.month}'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _day = _day.subtract(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            onPressed: () => setState(() => _day = _day.add(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
          children: [
            Text(
              planned.isEmpty
                  ? 'Touche une heure pour y poser une tâche. Micky te dira « c\'est l\'heure ».'
                  : '${planned.length} bloc${planned.length > 1 ? 's' : ''} prévu${planned.length > 1 ? 's' : ''} · en vert, ce que tu as vraiment fait.',
              style: K.body(13, color: K.muted),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: (endH - startH + 1) * _hourH,
              child: Stack(
                children: [
                  // grille des heures
                  for (var h = startH; h <= endH; h++)
                    Positioned(
                      top: (h - startH) * _hourH,
                      left: 0,
                      right: 0,
                      height: _hourH,
                      child: InkWell(
                        onTap: () => _addAt(_day.add(Duration(hours: h))),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 44, child: Text('${h.toString().padLeft(2, '0')} h', style: K.body(12, color: K.muted))),
                            Expanded(child: Container(height: 1, color: K.line, margin: const EdgeInsets.only(top: 8))),
                          ],
                        ),
                      ),
                    ),
                  // sessions réelles
                  for (final x in sessions)
                    Positioned(
                      top: top(x.start) + 8,
                      left: 48,
                      width: 70,
                      height: max(14, ((x.running ? now.millisecondsSinceEpoch : x.end) - x.start) / 3600000 * _hourH),
                      child: Container(
                        decoration: BoxDecoration(
                          color: (store.sessionCategory(x) == Act.perso ? K.pink : K.lime).withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: store.sessionCategory(x) == Act.perso ? K.pink : K.lime),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Text(x.title, style: K.body(10), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  // blocs prévus
                  for (final t in planned)
                    Positioned(
                      top: top(t.plannedAt) + 8,
                      left: 124,
                      right: 4,
                      height: max(30, t.blockMin / 60 * _hourH),
                      child: Material(
                        color: t.done ? K.raised : K.card,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _blockOptions(t),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: t.done ? K.line : (K.quadColors[t.quad] ?? K.gold), width: 2),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${hm(DateTime.fromMillisecondsSinceEpoch(t.plannedAt))} · ${t.title}${t.condition.isNotEmpty ? ' · si ${t.condition}' : ''}',
                                    style: K.body(12, color: t.done ? K.muted : K.ink, w: FontWeight.w800)
                                        .copyWith(decoration: t.done ? TextDecoration.lineThrough : null),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (t.postponed > 0) Pill('×${t.postponed}', color: K.coral),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  // maintenant
                  if (isToday)
                    Positioned(
                      top: top(now.millisecondsSinceEpoch) + 8,
                      left: 40,
                      right: 0,
                      child: Row(children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: K.coral, shape: BoxShape.circle)),
                        Expanded(child: Container(height: 2, color: K.coral)),
                      ]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _blockOptions(Task t) async {
    final store = AppScope.read(context);
    final a = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(alignment: Alignment.centerLeft, child: Text(t.title, style: K.display(18))),
            ),
            if (!t.done)
              ListTile(leading: const Icon(Icons.play_arrow_rounded, color: K.lime), title: const Text('Lancer maintenant'), onTap: () => Navigator.pop(ctx, 'go')),
            ListTile(leading: const Icon(Icons.schedule_rounded, color: K.gold), title: const Text('Déplacer'), onTap: () => Navigator.pop(ctx, 'move')),
            ListTile(leading: const Icon(Icons.timer_outlined, color: K.cyan), title: Text('Durée du bloc (${fmtMin(t.blockMin)})'), onTap: () => Navigator.pop(ctx, 'len')),
            ListTile(leading: const Icon(Icons.close_rounded, color: K.muted), title: const Text('Retirer de la journée'), onTap: () => Navigator.pop(ctx, 'unplan')),
          ],
        ),
      ),
    );
    if (a == null || !mounted) return;
    switch (a) {
      case 'go':
        await launchTask(context, t);
        break;
      case 'move':
        final at = await pickWhen(context, initial: DateTime.fromMillisecondsSinceEpoch(t.plannedAt));
        if (at == null) return;
        await store.planTask(t, at);
        await rescheduleAll(store);
        break;
      case 'len':
        final v = await showModalBottomSheet<int>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in [15, 30, 45, 60, 90, 120, 180, 240])
                    ActionChip(label: Text(fmtMin(m)), backgroundColor: K.raised, side: BorderSide.none, onPressed: () => Navigator.pop(ctx, m)),
                ],
              ),
            ),
          ),
        );
        if (v == null) return;
        t.plannedMin = v;
        await store.commit();
        break;
      case 'unplan':
        await store.unplanTask(t);
        await rescheduleAll(store);
        break;
    }
  }
}

/// Lance la session sur une tâche (choix du pari préréglé).
Future<void> launchTask(BuildContext context, Task t) async {
  final store = AppScope.read(context);
  if (store.runningSession != null) {
    await openScreen(context, const SessionScreen());
    return;
  }
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => AppScope(store: store, child: StartSessionSheet(preselect: t.id)),
  );
  if (ok == true && context.mounted) {
    await rescheduleAll(store);
    if (context.mounted) await openScreen(context, const SessionScreen());
  }
}

/// Écran « C'est l'heure » ouvert depuis le rappel.
class ReminderScreen extends StatelessWidget {
  final Task task;
  final int ts;
  const ReminderScreen({super.key, required this.task, required this.ts});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final t = task;
    return Scaffold(
      appBar: AppBar(title: const Text('C\'est l\'heure')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            MickySays('Il est ${hm(DateTime.fromMillisecondsSinceEpoch(ts))} : « ${t.title} ». On y va ?', pose: 'window'),
            const SizedBox(height: 16),
            Panel(
              border: K.quadColors[t.quad],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title, style: K.display(20)),
                  const SizedBox(height: 4),
                  Text('Bloc de ${fmtMin(t.blockMin)}${t.condition.isNotEmpty ? ' · seulement quand ${t.condition}' : ''}${t.postponed > 0 ? ' · déjà reporté ${t.postponed} fois' : ''}',
                      style: K.body(13, color: K.muted)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Je lance',
              onPressed: () async {
                store.answerReminder(t, ts, 'go');
                await store.commit();
                if (!context.mounted) return;
                Navigator.pop(context);
                final ctx = navKey.currentContext;
                if (ctx != null) await launchTask(ctx, t);
              },
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Pas tout de suite',
              onPressed: () async {
                final done = await openScreen<bool>(context, PostponeScreen(task: t, ts: ts));
                if (done == true && context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// « Pas tout de suite » : tout ce qu'on peut faire d'une tâche qu'on ne lance pas.
/// Réutilisé tel quel dans « Je bloque ».
class PostponeScreen extends StatelessWidget {
  final Task task;
  final int ts;
  final bool embedded;
  const PostponeScreen({super.key, required this.task, required this.ts, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final body = PostponeBlock(task: task, ts: ts, onDone: () => Navigator.pop(context, true));
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Pas tout de suite')),
      body: SafeArea(
        top: false,
        child: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [body]),
      ),
    );
  }
}

class PostponeBlock extends StatelessWidget {
  final Task task;
  final int ts;
  final VoidCallback onDone;
  final bool hideBlock;
  const PostponeBlock({super.key, required this.task, required this.ts, required this.onDone, this.hideBlock = false});

  Future<void> _after(BuildContext context, AppStore store, bool third) async {
    await rescheduleAll(store);
    if (!context.mounted) return;
    if (third) await showSplitSuggestion(context, task);
    onDone();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.read(context);
    final like = store;
    final t = task;
    Widget btn(String label, IconData icon, Color c, Future<void> Function() go, {String? sub}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: K.card,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: go,
              child: Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: K.line, width: 2)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(icon, color: c),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: K.body(15, w: FontWeight.w800)),
                          if (sub != null) Text(sub, style: K.body(12, color: K.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('« ${t.title} »', style: K.display(18)),
        const SizedBox(height: 4),
        Text('Pas de jugement : on décide juste quand.', style: K.body(13, color: K.muted)),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final m in [5, 10, 15, 30]) ...[
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: K.card,
                      side: const BorderSide(color: K.gold, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () async {
                      final third = await store.postpone(t, minutes: m, at: ts);
                      if (context.mounted) await _after(context, like, third);
                    },
                    child: Text('+$m', style: K.display(16, color: K.gold)),
                  ),
                ),
              ),
              if (m != 30) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text('minutes · Micky revient te chercher', style: K.body(12, color: K.muted)),
        const SizedBox(height: 12),
        btn('Plus tard aujourd\'hui', Icons.schedule_rounded, K.gold, () async {
          final at = await pickWhen(context, title: 'À quelle heure ?');
          if (at == null) return;
          store.answerReminder(t, ts, 'plustard', detail: hm(at));
          t.postponed++;
          await store.planTask(t, at);
          if (context.mounted) await _after(context, like, t.postponed >= 3);
        }, sub: 'un autre créneau dans ta journée'),
        btn('Demain', Icons.wb_twilight_rounded, K.cyan, () async {
          store.answerReminder(t, ts, 'demain');
          t.plannedAt = 0;
          await store.deferTask(t);
          if (context.mounted) await _after(context, like, false);
        }, sub: 'elle revient dans tes tâches et au briefing'),
        btn('Agenda du téléphone', Icons.event_rounded, K.pink, () async {
          final at = await pickWhen(context, title: 'Dans l\'agenda, quand ?');
          if (at == null) return;
          store.answerReminder(t, ts, 'agenda', detail: '${at.day}/${at.month} ${hm(at)}');
          final err = await addToPhoneAgenda(t.title, at, minutes: t.blockMin, at: at);
          if (err == null) {
            t.plannedAt = 0;
            t.removed = true;
            await store.commit();
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
            return;
          }
          if (context.mounted) await _after(context, like, false);
        }, sub: 'avec le jour et l\'heure'),
        btn('Seulement quand…', Icons.rule_rounded, K.cyan, () async {
          final c = await askText(context, 'Seulement quand…', hint: 'j\'ai reçu le fichier', initial: t.condition);
          if (c == null || c.isEmpty) return;
          store.answerReminder(t, ts, 'condition', detail: c);
          await store.setCondition(t, c);
          if (context.mounted) await _after(context, like, false);
        }, sub: 'une condition plutôt qu\'une heure'),
        if (!hideBlock)
          btn('Ça bloque', Icons.help_outline_rounded, K.coral, () async {
            store.answerReminder(t, ts, 'bloque');
            await store.commit();
            if (!context.mounted) return;
            onDone();
            final ctx = navKey.currentContext;
            if (ctx != null) openScreen(ctx, BlockScreen(task: t));
          }, sub: 'coups de pouce pour relancer'),
        btn('Annuler la tâche', Icons.delete_outline_rounded, K.dim, () async {
          store.answerReminder(t, ts, 'annule');
          await store.removeTask(t);
          if (context.mounted) await _after(context, like, false);
        }),
      ],
    );
  }
}

/// Au 3e report : Micky propose de découper.
Future<void> showSplitSuggestion(BuildContext context, Task t) async {
  final store = AppScope.read(context);
  final first = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final c = TextEditingController();
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MickySays('Trois reports : « ${t.title} » est sans doute trop gros d\'un coup. On découpe ? Quelle est la toute première action, en une phrase ?'),
                const SizedBox(height: 12),
                TextField(
                  controller: c,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'ouvrir le fichier et lire le premier paragraphe'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: SecondaryButton(label: 'Pas maintenant', onPressed: () => Navigator.pop(ctx))),
                    const SizedBox(width: 10),
                    Expanded(child: PrimaryButton(label: 'Créer l\'étape', onPressed: () => Navigator.pop(ctx, c.text.trim()))),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  if (first == null || first.isEmpty) return;
  final step = await store.addTask(first, category: t.category, estimate: 10, quad: Quad.doNow);
  step.order = t.order;
  await store.commit();
}
