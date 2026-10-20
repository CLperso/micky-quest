import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../agenda.dart';
import '../calendar.dart';
import '../main.dart';
import '../models.dart';
import '../notifications.dart';
import '../store.dart';
import '../theme.dart';
import 'block.dart';
import 'dump.dart';
import 'slot.dart';
import 'task_panel.dart';
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

/// « Quand ? » : Aujourd'hui, Demain, Cette semaine, Seulement quand… Les trois premiers ouvrent le planning en mode « caser ».
Future<void> planSheet(BuildContext context, Task t) => whenSheet(context, t);

Future<void> whenSheet(BuildContext context, Task t) async {
  final store = AppScope.read(context);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  var weekDay = today.add(const Duration(days: 2));
  final choice = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: K.line, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 10),
              Text('${t.title}${t.estimateMin > 0 ? ' · ${t.estimateMin} min' : ''}', style: K.display(20)),
              Text('Quand est-ce que tu t\'y mets ?', style: K.body(13, color: K.muted)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: whenTile(ctx, 'Aujourd\'hui', '→ je choisis un créneau', K.lime, K.bg, () => Navigator.pop(ctx, 'today'))),
                const SizedBox(width: 8),
                Expanded(child: whenTile(ctx, 'Demain', '→ planning de demain', K.cyan, K.bg, () => Navigator.pop(ctx, 'tomorrow'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: whenTile(ctx, 'Cette semaine', '', K.raised, K.gold, () => Navigator.pop(ctx, 'week'), border: K.gold, child: Row(children: [
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
                              width: 20,
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
                Expanded(child: whenTile(ctx, 'Seulement quand…', t.condition.isNotEmpty ? '« ${t.condition} »' : '« j\'ai reçu la réponse »', K.raised, K.pink, () => Navigator.pop(ctx, 'cond'), border: K.pink)),
              ]),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, 'none'),
                  child: Text('Pas maintenant · juste dans « Planifier », sans date', style: K.body(12, color: K.muted)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  await applyWhen(context, t, choice, day: weekDay);
}

/// Applique une réponse à « Quand ? » : today, tomorrow, week (avec [day]), cond, none.
Future<void> applyWhen(BuildContext context, Task t, String choice, {DateTime? day}) async {
  final store = AppScope.read(context);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  switch (choice) {
    case 'today':
      await openScreen(context, PlanningScreen(day: dayKey(today), place: t));
      break;
    case 'tomorrow':
      await openScreen(context, PlanningScreen(day: dayKey(today.add(const Duration(days: 1))), place: t));
      break;
    case 'week':
      await openScreen(context, PlanningScreen(day: dayKey(day ?? today.add(const Duration(days: 2))), place: t));
      break;
    case 'cond':
      final c = await askText(context, 'Seulement quand…', hint: 'j\'ai reçu la réponse de Nathalie', initial: t.condition);
      if (c == null || c.isEmpty) return;
      await store.setCondition(t, c);
      break;
    default:
      if (t.quad != Quad.plan) await store.moveTask(t, Quad.plan);
  }
}

Widget whenTile(BuildContext ctx, String title, String sub, Color bg, Color fg, VoidCallback onTap, {Color? border, Widget? child}) => Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 92,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: border == null ? null : Border.all(color: border, width: 2)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: K.display(16, color: fg)),
              child ?? Text(sub, style: K.body(11, color: fg == K.bg ? K.bg.withValues(alpha: 0.8) : K.muted, w: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );

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

/// Le planning en plein écran (liste ou grille), éventuellement en mode « caser » une tâche.
class PlanningScreen extends StatelessWidget {
  final String? day;
  final Task? place;
  const PlanningScreen({super.key, this.day, this.place});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(place == null ? 'Planning' : 'Caser « ${place!.title} »')),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
            children: [PlanningView(day: day, place: place, onPlaced: () => Navigator.pop(context))],
          ),
        ),
      );
}

/// Ancien nom, gardé pour les écrans qui l'utilisent.
class TimetableScreen extends PlanningScreen {
  const TimetableScreen({super.key, super.day, super.place});
}

/// Liste chronologique du jour (sessions faites, agenda, blocs, trous), avec bascule vers la grille.
class PlanningView extends StatefulWidget {
  final String? day;
  final Task? place;
  final VoidCallback? onPlaced;
  const PlanningView({super.key, this.day, this.place, this.onPlaced});

  @override
  State<PlanningView> createState() => _PlanningViewState();
}

class _Item {
  final int start, end;
  final String kind; // session, agenda, block, free, past, slot
  final String title, sub;
  final Task? task;
  final Slot? slot;
  final bool done;
  _Item(this.start, this.end, this.kind, this.title, this.sub, {this.task, this.slot, this.done = false});
}

class _PlanningViewState extends State<PlanningView> {
  late DateTime _day;
  bool _grid = false;
  List<CalEvent> _events = [];
  String _eventsFor = '';

  @override
  void initState() {
    super.initState();
    _day = widget.day == null ? DateTime.now() : parseDay(widget.day!);
    _day = DateTime(_day.year, _day.month, _day.day);
  }

  String get _key => dayKey(_day);

  /// En mode « caser », toucher un bloc occupé : intervertir, remplacer, ou en faire une sous-étape.
  Future<void> _onOccupied(AppStore store, Task other) async {
    final p = widget.place!;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('« ${other.title} » est déjà là', style: K.display(18)),
            const SizedBox(height: 4),
            Text('${hm(DateTime.fromMillisecondsSinceEpoch(other.plannedAt))} · que fait-on de « ${p.title} » ?', style: K.body(13, color: K.muted)),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.swap_vert_rounded, color: K.cyan),
              title: Text('Intervertir', style: K.body(15, w: FontWeight.w800)),
              subtitle: Text(p.plannedAt > 0 ? 'chacune prend la place de l\'autre' : '« ${other.title} » retourne dans tes tâches sans heure', style: K.body(12, color: K.muted)),
              onTap: () => Navigator.pop(ctx, 'swap'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.find_replace_rounded, color: K.gold),
              title: Text('Remplacer', style: K.body(15, w: FontWeight.w800)),
              subtitle: Text('« ${other.title} » retourne dans tes tâches, « ${p.title} » prend le créneau', style: K.body(12, color: K.muted)),
              onTap: () => Navigator.pop(ctx, 'replace'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.subdirectory_arrow_right_rounded, color: K.lime),
              title: Text('En faire une sous-étape', style: K.body(15, w: FontWeight.w800)),
              subtitle: Text('« ${p.title} » se fait pendant « ${other.title} »', style: K.body(12, color: K.muted)),
              onTap: () => Navigator.pop(ctx, 'sub'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded, color: K.muted),
              title: Text('Juste après', style: K.body(15, w: FontWeight.w800)),
              subtitle: Text('à ${hm(DateTime.fromMillisecondsSinceEpoch(other.plannedAt + max(15, other.blockMin) * 60000))}', style: K.body(12, color: K.muted)),
              onTap: () => Navigator.pop(ctx, 'after'),
            ),
          ]),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final at = DateTime.fromMillisecondsSinceEpoch(other.plannedAt);
    switch (choice) {
      case 'swap':
        final mine = p.plannedAt;
        await store.planTask(p, at);
        if (mine > 0) {
          await store.planTask(other, DateTime.fromMillisecondsSinceEpoch(mine));
        } else {
          await store.unplanTask(other);
        }
        break;
      case 'replace':
        await store.unplanTask(other);
        await store.planTask(p, at);
        break;
      case 'sub':
        await store.attachSub(other, p);
        break;
      case 'after':
        await store.planTask(p, at.add(Duration(minutes: max(15, other.blockMin))));
        break;
    }
    await rescheduleAll(store);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(choice == 'sub' ? '« ${p.title} » est une sous-étape de « ${other.title} »' : 'C\'est casé.')));
    widget.onPlaced?.call();
  }


  Future<void> _loadEvents() async {
    final store = AppScope.read(context);
    if (!store.settings.calendarRead) return;
    final k = _key;
    if (_eventsFor == k) return;
    _eventsFor = k;
    final ev = await PhoneCalendar.eventsOn(_day);
    if (mounted && _eventsFor == k) setState(() => _events = ev);
  }

  Future<void> _placeAt(DateTime at) async {
    final store = AppScope.read(context);
    final t = widget.place;
    if (t != null) {
      await store.planTask(t, at);
      await rescheduleAll(store);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('« ${t.title} » à ${hm(at)} · rappel programmé')));
      widget.onPlaced?.call();
      return;
    }
    // sans tâche en main : choisir quoi caser
    final open = store.openTasks.where((x) => !x.done).toList();
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
              for (final x in open)
                ListTile(
                  leading: Container(width: 10, height: 10, decoration: BoxDecoration(color: x.category == 'pro' ? K.lime : x.category == 'perso' ? K.pink : K.quadColors[x.quad], shape: BoxShape.circle)),
                  title: Text(x.title, style: K.body(15)),
                  subtitle: x.plannedAt > 0 ? Text('déjà à ${hm(DateTime.fromMillisecondsSinceEpoch(x.plannedAt))}', style: K.body(12, color: K.muted)) : null,
                  onTap: () => Navigator.pop(ctx, x),
                ),
              ListTile(
                leading: const Icon(Icons.add_rounded, color: K.lime),
                title: Text('Nouvelle tâche', style: K.body(15)),
                onTap: () => Navigator.pop(ctx, Task(title: '', day: '')),
              ),
              if (store.habits.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('HABITUDES', style: K.body(11, color: K.muted, w: FontWeight.w900).copyWith(letterSpacing: 1)),
                for (final h in store.habits)
                  ListTile(
                    leading: const Icon(Icons.repeat_rounded, color: K.cyan, size: 18),
                    title: Text(h.name, style: K.body(15)),
                    subtitle: h.reminderMin >= 0 ? Text('déjà à ${(h.reminderMin ~/ 60).toString().padLeft(2, '0')}:${(h.reminderMin % 60).toString().padLeft(2, '0')}', style: K.body(12, color: K.muted)) : null,
                    onTap: () => Navigator.pop(ctx, Task(id: 'habit:${h.id}', title: h.name, day: '')),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    Task x = chosen;
    if (x.title.isEmpty) {
      final n = await askNewTask(context);
      if (n == null) return;
      x = await store.addTask(n.title, category: n.category, estimate: n.minutes, quad: Quad.plan, inQuest: false);
    }
    await store.planTask(x, at);
    await rescheduleAll(store);
  }

  List<_Item> _items(AppStore store) {
    final items = <_Item>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final x in store.sessionsOn(_key)) {
      final end = x.running ? now : x.end;
      final cat = store.sessionCategory(x);
      items.add(_Item(x.start, end, 'session', x.title,
          '${cat == Act.perso ? 'perso' : 'pro'} · ${((end - x.start) / 60000).round()} min${x.running ? ' · en cours' : x.onTarget ? ' · pari tenu' : x.finished ? '' : ' · décrochée'}',
          done: true));
    }
    for (final e in _events.where((e) => !e.allDay)) {
      items.add(_Item(e.start.millisecondsSinceEpoch, e.end.millisecondsSinceEpoch, 'agenda', e.title, 'agenda · ${e.end.difference(e.start).inMinutes} min'));
    }
    for (final x in store.slotsOn(_key)) {
      items.add(_Item(x.start, x.end, 'slot', x.title.isNotEmpty ? x.title : (Slot.labels[x.kind] ?? x.kind),
          [
            if (x.title.isNotEmpty) Slot.labels[x.kind] ?? x.kind,
            fmtMin(x.minutes.round()),
            if (x.emotion.isNotEmpty) x.emotion,
            if (x.why.isNotEmpty) x.why.toLowerCase(),
            'noté après coup',
          ].join(' · '),
          slot: x, done: true));
    }
    for (final t in store.plannedOn(_key)) {
      // un bloc déjà couvert par une session faite dessus n'est pas répété
      if (t.done && items.any((i) => i.kind == 'session' && i.task == null && i.title == t.title)) continue;
      items.add(_Item(t.plannedAt, t.plannedAt + t.blockMin * 60000, 'block', t.title,
          '${t.category.isNotEmpty ? t.category : 'tâche'} · ${fmtMin(t.blockMin)}${t.condition.isNotEmpty ? ' · si ${t.condition}' : ''}${t.postponed > 0 ? ' · reporté ×${t.postponed}' : ''}${t.done ? ' · fait' : ' · rappel ${hm(DateTime.fromMillisecondsSinceEpoch(t.plannedAt))}'}',
          task: t, done: t.done));
    }
    items.sort((a, b) => a.start.compareTo(b.start));
    // trous (≥ 30 min) entre maintenant/le début de journée et la fin de journée
    final s = store.settings;
    final dayStart = _day.add(Duration(hours: s.startHour)).millisecondsSinceEpoch;
    final dayEnd = _day.add(Duration(hours: s.endHour)).millisecondsSinceEpoch;
    if (_key.compareTo(store.todayKey) > 0) {
      // jour futur : seulement les trous à venir
    }
    var cursor = dayStart;
    final out = <_Item>[];
    void gap(int a, int b) {
      if (b - a < 30 * 60000 || a >= dayEnd) return;
      b = min(b, dayEnd);
      // partie passée : « noter ce créneau » ; partie à venir : « caser »
      if (b <= now) {
        out.add(_Item(a, b, 'past', '', ''));
      } else if (a >= now) {
        out.add(_Item(a, b, 'free', '', ''));
      } else {
        if (now - a >= 30 * 60000) out.add(_Item(a, now, 'past', '', ''));
        if (b - now >= 30 * 60000) out.add(_Item(now, b, 'free', '', ''));
      }
    }
    for (final i in items) {
      gap(cursor, i.start);
      out.add(i);
      cursor = max(cursor, i.end);
    }
    gap(cursor, dayEnd);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    _loadEvents();
    final isToday = _key == store.todayKey;
    final now = DateTime.now().millisecondsSinceEpoch;
    const names = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    final place = widget.place;
    final items = _items(store);
    var nowShown = !isToday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.view_day_rounded, color: K.gold, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(isToday ? 'Planning du jour' : '${names[_day.weekday - 1]} ${_day.day}/${_day.month}', style: K.display(18))),
          IconButton(
            onPressed: () => setState(() {
              _day = _day.subtract(const Duration(days: 1));
              _events = [];
            }),
            icon: const Icon(Icons.chevron_left_rounded, color: K.muted),
          ),
          IconButton(
            onPressed: () => setState(() {
              _day = _day.add(const Duration(days: 1));
              _events = [];
            }),
            icon: const Icon(Icons.chevron_right_rounded, color: K.muted),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => setState(() => _grid = !_grid),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(_grid ? Icons.view_list_rounded : Icons.grid_on_rounded, color: K.gold, size: 20),
            ),
          ),
        ]),
        if (place != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: K.lime, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: K.lime.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))]),
            child: Row(children: [
              const Icon(Icons.back_hand_rounded, color: K.bg),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${place.title}${place.estimateMin > 0 ? ' · ${place.estimateMin} min' : ''}', style: K.body(14, color: K.bg, w: FontWeight.w800)),
                    Text('Touche un créneau libre, ou « à une heure précise »', style: K.body(11, color: K.bg.withValues(alpha: 0.8), w: FontWeight.w800)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () async {
                  final at = await pickWhen(context, initial: _day.add(const Duration(hours: 9)), title: 'À quelle heure ?');
                  if (at != null) await _placeAt(at);
                },
                child: Text('heure précise', style: K.body(12, color: K.bg, w: FontWeight.w900)),
              ),
            ]),
          ),
        if (_grid)
          TimetableView(key: ValueKey('grid-$_key'), day: _key, place: place)
        else ...[
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Rien ce jour-là.', style: K.body(13, color: K.muted)),
            ),
          for (final i in items) ...[
            if (!nowShown && i.start > now) ...[
              _nowLine(now),
              Builder(builder: (_) {
                nowShown = true;
                return const SizedBox.shrink();
              }),
            ],
            _row(store, i, place),
          ],
          if (!nowShown) _nowLine(now),
          const SizedBox(height: 8),
          if (place == null)
            Row(children: [
              Expanded(
                child: SecondaryButton(
                  label: '+ Caser une tâche',
                  onPressed: () async {
                    final at = await pickWhen(context, title: 'À quelle heure ?');
                    if (at != null) await _placeAt(at);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SecondaryButton(
                  label: '+ Créneau passé',
                  onPressed: () => addPastSlotSheet(context,
                      start: _key == store.todayKey ? null : _day.add(const Duration(hours: 9)),
                      end: _key == store.todayKey ? null : _day.add(const Duration(hours: 12))),
                ),
              ),
            ]),
        ],
      ],
    );
  }

  Widget _nowLine(int now) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          const SizedBox(width: 44),
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: K.coral, shape: BoxShape.circle)),
          Expanded(child: Container(height: 2, color: K.coral)),
          const SizedBox(width: 6),
          Text('${hm(DateTime.fromMillisecondsSinceEpoch(now))} · maintenant', style: K.body(10, color: K.coral, w: FontWeight.w900)),
        ]),
      );

  Widget _row(AppStore store, _Item i, Task? place) {
    final t = i.task;
    final start = DateTime.fromMillisecondsSinceEpoch(i.start);
    if (i.kind == 'past') {
      final mins = ((i.end - i.start) / 60000).round();
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(width: 44, child: Text(hm(start), textAlign: TextAlign.right, style: K.body(11, color: K.muted, w: FontWeight.w800))),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => addPastSlotSheet(context, start: start, end: DateTime.fromMillisecondsSinceEpoch(i.end)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: K.line, width: 2)),
                child: Row(children: [
                  Expanded(child: Text('${fmtMin(mins)} sans trace', style: K.body(12, color: K.muted, w: FontWeight.w800))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: K.raised, borderRadius: BorderRadius.circular(999)),
                    child: Text('+ noter', style: K.body(11, w: FontWeight.w900)),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      );
    }
    if (i.kind == 'slot') {
      final x = i.slot!;
      final c = x.kind == 'idle' || x.kind == 'phone'
          ? moodColor(x.mood, x.energy)
          : x.kind == 'pro'
              ? K.lime
              : x.kind == 'perso'
                  ? K.pink
                  : K.cyan;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 44, child: Padding(padding: const EdgeInsets.only(top: 8), child: Text(hm(start), textAlign: TextAlign.right, style: K.body(11, color: K.muted, w: FontWeight.w800)))),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => addPastSlotSheet(context, existing: x),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border(left: BorderSide(color: c, width: 4)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.title, style: K.body(13, w: FontWeight.w800)),
                  Text(i.sub, style: K.body(11, color: K.muted)),
                ]),
              ),
            ),
          ),
        ]),
      );
    }
    if (i.kind == 'free') {
      final mins = ((i.end - i.start) / 60000).round();
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(width: 44, child: Text(hm(start), textAlign: TextAlign.right, style: K.body(11, color: K.muted, w: FontWeight.w800))),
          const SizedBox(width: 10),
          Expanded(
            child: Material(
              color: place != null ? K.lime.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _placeAt(start),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: place != null ? K.lime : K.line, width: 2, strokeAlign: BorderSide.strokeAlignInside)),
                  child: Row(children: [
                    Expanded(child: Text('${fmtMin(mins)} libre${place != null ? ' · touche pour caser ici' : ''}', style: K.body(12, color: place != null ? K.lime : K.muted, w: FontWeight.w800))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: place != null ? K.lime : K.raised, borderRadius: BorderRadius.circular(999)),
                      child: Text('+ caser', style: K.body(11, color: place != null ? K.bg : K.ink, w: FontWeight.w900)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      );
    }
    final color = i.kind == 'agenda'
        ? K.muted
        : i.kind == 'session'
            ? (i.sub.startsWith('perso') ? K.pink : K.lime)
            : (t?.category == 'pro' ? K.lime : t?.category == 'perso' ? K.pink : K.gold);
    final dim = i.done || i.kind == 'agenda';
    Widget card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: i.done ? const Color(0xFF1C1736) : K.card,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: i.done && i.kind != 'session' ? K.line : color, width: 4)),
      ),
      child: Row(children: [
        if (i.kind == 'agenda') const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.event_rounded, color: K.muted, size: 14)),
        if (i.kind == 'session') Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.check_rounded, color: color, size: 16)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(i.title, style: K.body(13, color: dim ? K.muted : K.ink, w: FontWeight.w800).copyWith(decoration: i.done && i.kind == 'block' ? TextDecoration.lineThrough : null), maxLines: 2, overflow: TextOverflow.ellipsis),
              Text(i.sub, style: K.body(11, color: K.muted)),
            ],
          ),
        ),
        if (t != null && !t.done && t.plannedAt > 0)
          IconButton(
            tooltip: 'Déplacer',
            visualDensity: VisualDensity.compact,
            onPressed: () => openScreen(context, PlanningScreen(day: _key, place: t)),
            icon: const Icon(Icons.open_with_rounded, color: K.muted, size: 20),
          ),
        if (t != null && !t.done)
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => launchTask(context, t),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: K.bg, size: 20),
            ),
          ),
      ]),
    );
    if (t != null) {
      card = Dismissible(
        key: ValueKey('plan-${t.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(color: K.coral.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.close_rounded, color: K.coral),
        ),
        confirmDismiss: (_) async {
          await store.unplanTask(t);
          await rescheduleAll(store);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('« ${t.title} » retirée du planning (toujours dans tes tâches)')));
          return false;
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => widget.place != null && widget.place!.id != t.id ? _onOccupied(store, t) : showTaskPanel(context, t),
          child: card,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 44, child: Padding(padding: const EdgeInsets.only(top: 8), child: Text(hm(start), textAlign: TextAlign.right, style: K.body(11, color: K.muted, w: FontWeight.w800)))),
        const SizedBox(width: 10),
        Expanded(child: card),
      ]),
    );
  }

  Future<void> _blockMenu(AppStore store, Task t) async {
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
            if (!t.done) ListTile(leading: const Icon(Icons.play_arrow_rounded, color: K.lime), title: const Text('Lancer maintenant'), onTap: () => Navigator.pop(ctx, 'go')),
            if (!t.done) ListTile(leading: const Icon(Icons.check_rounded, color: K.lime), title: const Text('C\'est fait'), onTap: () => Navigator.pop(ctx, 'done')),
            ListTile(leading: const Icon(Icons.schedule_rounded, color: K.gold), title: const Text('Déplacer'), onTap: () => Navigator.pop(ctx, 'move')),
            ListTile(leading: const Icon(Icons.timer_outlined, color: K.cyan), title: Text('Durée du bloc (${fmtMin(t.blockMin)})'), onTap: () => Navigator.pop(ctx, 'len')),
            ListTile(leading: const Icon(Icons.close_rounded, color: K.coral), title: const Text('Retirer du planning'), onTap: () => Navigator.pop(ctx, 'unplan')),
            ListTile(leading: const Icon(Icons.delete_outline_rounded, color: K.muted), title: const Text('Supprimer la tâche'), onTap: () => Navigator.pop(ctx, 'delete')),
          ],
        ),
      ),
    );
    if (a == null || !mounted) return;
    switch (a) {
      case 'go':
        await launchTask(context, t);
        break;
      case 'done':
        await store.completeTask(t);
        if (t.done && mounted) await askNext(context, 'Tâche faite !');
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
      case 'delete':
        await store.removeTask(t);
        await rescheduleAll(store);
        break;
    }
  }
}

/// La journée en blocs : ce qui est prévu, ce qui a été fait. S'intègre dans une liste.
class TimetableView extends StatefulWidget {
  final String? day;

  /// Tâche à poser : touche une heure et elle y va.
  final Task? place;
  const TimetableView({super.key, this.day, this.place});

  @override
  State<TimetableView> createState() => _TimetableViewState();
}

class _TimetableViewState extends State<TimetableView> {
  late DateTime _day;
  static const _hourH = 56.0;
  static const _left = 46.0;
  List<CalEvent> _events = [];
  String _eventsFor = '';
  String? _dragId;
  double _dragDy = 0;

  @override
  void initState() {
    super.initState();
    _day = widget.day == null ? DateTime.now() : parseDay(widget.day!);
    _day = DateTime(_day.year, _day.month, _day.day);
  }

  Future<void> _loadEvents() async {
    final store = AppScope.read(context);
    if (!store.settings.calendarRead) return;
    final k = _key;
    if (_eventsFor == k) return;
    _eventsFor = k;
    final ev = await PhoneCalendar.eventsOn(_day);
    if (mounted && _eventsFor == k) setState(() => _events = ev);
  }

  String get _key => dayKey(_day);

  Future<void> _addAt(DateTime at) async {
    final store = AppScope.read(context);
    final toPlace = widget.place;
    if (toPlace != null && toPlace.plannedAt == 0) {
      await store.planTask(toPlace, at);
      await rescheduleAll(store);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('« ${toPlace.title} » à ${hm(at)}')));
      return;
    }
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
                  leading: Container(width: 10, height: 10, decoration: BoxDecoration(color: t.category == 'pro' ? K.lime : t.category == 'perso' ? K.pink : K.quadColors[t.quad], shape: BoxShape.circle)),
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
    if (chosen.id.startsWith('habit:')) {
      final hid = chosen.id.substring(6);
      for (final h in store.habits) {
        if (h.id == hid) h.reminderMin = at.hour * 60 + at.minute;
      }
      await store.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('« ${chosen.title} » chaque jour à ${hm(at)}')));
      return;
    }
    Task t = chosen;
    if (t.title.isEmpty) {
      final n = await askNewTask(context);
      if (n == null) return;
      t = await store.addTask(n.title, category: n.category, estimate: n.minutes, quad: Quad.plan, inQuest: false);
    }
    await store.planTask(t, at);
    await rescheduleAll(store);
  }

  Color _taskColor(Task t) => t.category == 'pro' ? K.lime : t.category == 'perso' ? K.pink : (K.quadColors[t.quad] ?? K.gold);

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
    _loadEvents();
    final allDay = _events.where((e) => e.allDay).toList();
    final timed = _events.where((e) => !e.allDay).toList();

    const names = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.view_day_rounded, color: K.gold, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(isToday ? 'Planning du jour' : '${names[_day.weekday - 1]} ${_day.day}/${_day.month}', style: K.display(18))),
          IconButton(
            onPressed: () => setState(() {
              _day = _day.subtract(const Duration(days: 1));
              _events = [];
            }),
            icon: const Icon(Icons.chevron_left_rounded, color: K.muted),
          ),
          IconButton(
            onPressed: () => setState(() {
              _day = _day.add(const Duration(days: 1));
              _events = [];
            }),
            icon: const Icon(Icons.chevron_right_rounded, color: K.muted),
          ),
        ]),
        Text(
          widget.place != null && widget.place!.plannedAt == 0
              ? 'Touche l\'heure où tu veux faire « ${widget.place!.title} ».'
              : 'Touche une heure pour y poser une tâche · glisse un bloc pour le déplacer · touche-le pour le retirer.',
          style: K.body(12, color: K.muted),
        ),
        if (allDay.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final e in allDay) Pill(e.title, color: K.muted, fill: K.card)]),
        ],
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: SizedBox(
            height: (endH - startH + 1) * _hourH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // heures et lignes
                for (var h = startH; h <= endH; h++) ...[
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
                          SizedBox(width: _left, child: Padding(padding: const EdgeInsets.only(top: 1), child: Text('${h.toString().padLeft(2, '0')}:00', style: K.body(11, color: K.muted, w: FontWeight.w800)))),
                          Expanded(child: Container(height: 1, color: K.line, margin: const EdgeInsets.only(top: 8))),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: (h - startH) * _hourH + _hourH / 2 + 8,
                    left: _left,
                    right: 0,
                    child: Container(height: 1, color: K.line.withValues(alpha: 0.4)),
                  ),
                ],
                // événements de l'agenda du téléphone
                for (final e in timed)
                  Positioned(
                    top: top(e.start.millisecondsSinceEpoch) + 8,
                    left: _left,
                    right: 0,
                    height: max(20, e.end.difference(e.start).inMinutes / 60 * _hourH),
                    child: Container(
                      decoration: BoxDecoration(
                        color: K.raised.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(left: BorderSide(color: K.muted, width: 3)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: Row(children: [
                        const Icon(Icons.event_rounded, color: K.muted, size: 12),
                        const SizedBox(width: 4),
                        Expanded(child: Text('${hm(e.start)} ${e.title}', style: K.body(11, color: K.muted, w: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
                  ),
                // créneaux notés après coup (couleur de l'émotion)
                for (final x in store.slotsOn(_key))
                  Positioned(
                    top: top(x.start) + 8,
                    left: _left,
                    right: 0,
                    height: max(18, x.minutes / 60 * _hourH),
                    child: GestureDetector(
                      onTap: () => addPastSlotSheet(context, existing: x),
                      child: Container(
                        decoration: BoxDecoration(
                          color: (x.kind == 'idle' || x.kind == 'phone' ? moodColor(x.mood, x.energy) : x.kind == 'pro' ? K.lime : x.kind == 'perso' ? K.pink : K.cyan).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        child: Text('${Slot.labels[x.kind]}${x.emotion.isNotEmpty ? ' · ${x.emotion}' : ''}', style: K.body(11, color: K.muted, w: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ),
                // sessions réelles : liseré à gauche du bloc
                for (final x in sessions)
                  Positioned(
                    top: top(x.start) + 8,
                    left: _left - 8,
                    width: 6,
                    height: max(6, ((x.running ? now.millisecondsSinceEpoch : x.end) - x.start) / 3600000 * _hourH),
                    child: Tooltip(
                      message: '${x.title} · ${x.actualMin.round()} min',
                      child: Container(
                        decoration: BoxDecoration(
                          color: store.sessionCategory(x) == Act.perso ? K.pink : K.lime,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                // habitudes avec une heure
                for (final h in store.habits.where((h) => h.reminderMin >= 0))
                  Positioned(
                    top: top(dayMs + h.reminderMin * 60000) + 8,
                    left: _left + 8,
                    right: 0,
                    height: 26,
                    child: GestureDetector(
                      onTap: () async {
                        final lvl = store.habitLevel(h, _key);
                        if (lvl == 0 && isToday) {
                          await store.cycleHabit(h, to: 2);
                        } else {
                          final off = await showModalBottomSheet<bool>(
                            context: context,
                            builder: (ctx) => SafeArea(
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                ListTile(title: Text(h.name, style: K.display(16))),
                                ListTile(leading: const Icon(Icons.close_rounded, color: K.coral), title: Text('Retirer du planning', style: K.body(14)), onTap: () => Navigator.pop(ctx, true)),
                              ]),
                            ),
                          );
                          if (off == true) {
                            h.reminderMin = -1;
                            await store.commit();
                          }
                        }
                        if (mounted) setState(() {});
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: K.cyan.withValues(alpha: store.habitLevel(h, _key) > 0 ? 0.08 : 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: const Border(left: BorderSide(color: K.cyan, width: 3)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        child: Row(children: [
                          Icon(store.habitLevel(h, _key) > 0 ? Icons.check_rounded : Icons.repeat_rounded, color: K.cyan, size: 12),
                          const SizedBox(width: 4),
                          Expanded(child: Text(h.name, style: K.body(11, color: store.habitLevel(h, _key) > 0 ? K.muted : K.ink, w: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                    ),
                  ),
                // blocs prévus (déplaçables)
                for (final t in planned)
                  Builder(builder: (context) {
                    final c = _taskColor(t);
                    final dragging = _dragId == t.id;
                    final y = top(t.plannedAt) + 8 + (dragging ? _dragDy : 0);
                    final h = max(28.0, t.blockMin / 60 * _hourH);
                    return Positioned(
                      top: y,
                      left: _left + 8,
                      right: 0,
                      height: h,
                      child: GestureDetector(
                        onTap: () => _blockOptions(t),
                        onLongPressStart: (_) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _dragId = t.id;
                            _dragDy = 0;
                          });
                        },
                        onLongPressMoveUpdate: (d) => setState(() => _dragDy = d.offsetFromOrigin.dy),
                        onLongPressEnd: (_) async {
                          final minutes = (_dragDy / _hourH * 60 / 15).round() * 15;
                          setState(() {
                            _dragId = null;
                            _dragDy = 0;
                          });
                          if (minutes == 0) return;
                          final at = DateTime.fromMillisecondsSinceEpoch(t.plannedAt).add(Duration(minutes: minutes));
                          await store.planTask(t, at);
                          await rescheduleAll(store);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          decoration: BoxDecoration(
                            color: t.done ? K.raised : c.withValues(alpha: dragging ? 0.5 : 0.22),
                            borderRadius: BorderRadius.circular(10),
                            border: Border(left: BorderSide(color: t.done ? K.muted : c, width: 4)),
                            boxShadow: dragging ? const [BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 6))] : null,
                          ),
                          padding: const EdgeInsets.fromLTRB(8, 3, 6, 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(t.title,
                                        style: K.body(12, color: t.done ? K.muted : K.ink, w: FontWeight.w800)
                                            .copyWith(decoration: t.done ? TextDecoration.lineThrough : null),
                                        maxLines: h > 40 ? 2 : 1,
                                        overflow: TextOverflow.ellipsis),
                                    if (h > 40)
                                      Text(
                                        '${hm(DateTime.fromMillisecondsSinceEpoch(t.plannedAt))} · ${fmtMin(t.blockMin)}${t.condition.isNotEmpty ? ' · si ${t.condition}' : ''}${t.postponed > 0 ? ' · reporté ×${t.postponed}' : ''}',
                                        style: K.body(10, color: K.muted),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (h > 56)
                                      for (final sub in store.subStepsOf(t).take(((h - 44) / 13).floor()))
                                        Text('${sub.done ? '✓' : '›'} ${sub.title}${sub.estimateMin > 0 ? ' · ${sub.estimateMin} min' : ''}',
                                            style: K.body(10, color: sub.done ? K.dim : K.muted, w: FontWeight.w700).copyWith(decoration: sub.done ? TextDecoration.lineThrough : null),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              if (dragging)
                                Text(hm(DateTime.fromMillisecondsSinceEpoch(t.plannedAt).add(Duration(minutes: (_dragDy / _hourH * 60 / 15).round() * 15))),
                                    style: K.body(12, color: K.gold, w: FontWeight.w900))
                              else if (t.category.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
                                  child: Text(t.category == 'pro' ? 'PRO' : 'PERSO', style: K.body(8, color: K.bg, w: FontWeight.w900)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                // maintenant
                if (isToday)
                  Positioned(
                    top: top(now.millisecondsSinceEpoch) + 8,
                    left: _left - 10,
                    right: 0,
                    child: IgnorePointer(
                      child: Row(children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: K.coral, shape: BoxShape.circle)),
                        Expanded(child: Container(height: 2, color: K.coral)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Container(width: 10, height: 4, decoration: BoxDecoration(color: K.lime, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text('session faite', style: K.body(10, color: K.muted)),
          const SizedBox(width: 10),
          Container(width: 10, height: 10, decoration: BoxDecoration(color: K.lime.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(3), border: const Border(left: BorderSide(color: K.lime, width: 2)))),
          const SizedBox(width: 4),
          Text('bloc prévu', style: K.body(10, color: K.muted)),
          const SizedBox(width: 10),
          const Icon(Icons.event_rounded, color: K.muted, size: 10),
          const SizedBox(width: 4),
          Text('agenda', style: K.body(10, color: K.muted)),
        ]),
      ],
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
            if (!t.done)
              ListTile(leading: const Icon(Icons.check_rounded, color: K.lime), title: const Text('C\'est fait'), onTap: () => Navigator.pop(ctx, 'done')),
            ListTile(leading: const Icon(Icons.schedule_rounded, color: K.gold), title: const Text('Déplacer à une autre heure'), onTap: () => Navigator.pop(ctx, 'move')),
            ListTile(leading: const Icon(Icons.timer_outlined, color: K.cyan), title: Text('Durée du bloc (${fmtMin(t.blockMin)})'), onTap: () => Navigator.pop(ctx, 'len')),
            ListTile(leading: const Icon(Icons.close_rounded, color: K.coral), title: const Text('Retirer du planning'), subtitle: Text('la tâche reste dans ta liste', style: K.body(12, color: K.muted)), onTap: () => Navigator.pop(ctx, 'unplan')),
            ListTile(leading: const Icon(Icons.delete_outline_rounded, color: K.muted), title: const Text('Supprimer la tâche'), onTap: () => Navigator.pop(ctx, 'delete')),
          ],
        ),
      ),
    );
    if (a == null || !mounted) return;
    switch (a) {
      case 'go':
        await launchTask(context, t);
        break;
      case 'done':
        await store.completeTask(t);
        if (t.done && mounted) await askNext(context, 'Tâche faite !');
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
        await PhoneCalendar.writeBlock(store, t);
        break;
      case 'unplan':
        await store.unplanTask(t);
        await rescheduleAll(store);
        break;
      case 'delete':
        await store.removeTask(t);
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
  final go = await showModalBottomSheet<bool>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          MickySays('Trois reports : « ${t.title} » est sans doute trop gros d\'un coup. On le découpe ?'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: SecondaryButton(label: 'Pas maintenant', onPressed: () => Navigator.pop(ctx, false))),
            const SizedBox(width: 10),
            Expanded(child: PrimaryButton(label: 'Découper', onPressed: () => Navigator.pop(ctx, true))),
          ]),
        ]),
      ),
    ),
  );
  if (go != true || !context.mounted) return;
  await Navigator.of(context).push<Task?>(MaterialPageRoute(builder: (_) => DumpScreen(cut: t)));
}

/// Nouvelle tâche depuis le planning : titre, pro / perso / autre, durée.
Future<({String title, String category, int minutes})?> askNewTask(BuildContext context) async {
  final c = TextEditingController();
  var cat = 'pro';
  var min = 25;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nouvelle tâche', style: K.display(20)),
              const SizedBox(height: 8),
              TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'relire l\'intro')),
              const SizedBox(height: 12),
              Row(children: [
                for (final e in const [('pro', 'Pro'), ('perso', 'Perso'), ('', 'Autre')])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(e.$2),
                      selected: cat == e.$1,
                      onSelected: (_) => setState(() => cat = e.$1),
                      selectedColor: e.$1 == 'pro' ? K.lime : (e.$1 == 'perso' ? K.pink : K.gold),
                      labelStyle: K.body(13, color: cat == e.$1 ? K.bg : K.ink, w: FontWeight.w800),
                      backgroundColor: K.raised,
                      side: BorderSide.none,
                      showCheckmark: false,
                    ),
                  ),
              ]),
              const SizedBox(height: 10),
              Text('Durée', style: K.body(13, color: K.muted)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final m in [15, 25, 45, 60, 90, 120])
                  ChoiceChip(
                    label: Text(m >= 60 ? '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60}'}' : '$m min'),
                    selected: min == m,
                    onSelected: (_) => setState(() => min = m),
                    selectedColor: K.cyan,
                    labelStyle: K.body(13, color: min == m ? K.bg : K.ink),
                    backgroundColor: K.raised,
                    side: BorderSide.none,
                    showCheckmark: false,
                  ),
              ]),
              const SizedBox(height: 14),
              PrimaryButton(label: 'Placer dans le planning', onPressed: () => Navigator.pop(ctx, c.text.trim().isNotEmpty)),
            ]),
          ),
        ),
      ),
    ),
  );
  final title = c.text.trim();
  c.dispose();
  if (ok != true || title.isEmpty) return null;
  return (title: title, category: cat, minutes: min);
}
