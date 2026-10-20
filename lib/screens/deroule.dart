import 'package:flutter/material.dart';

import '../calendar.dart';
import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'task_panel.dart';
import 'timetable.dart' show fmtMin;

/// Le déroulé du jour : vue calculée, non éditable. Ce qui est fait (sessions), puis la liste dans l'ordre
/// à partir de maintenant, en respectant les ancres 📌, l'agenda du téléphone et les habitudes à heure fixe.
class DerouleView extends StatefulWidget {
  final String? day;
  const DerouleView({super.key, this.day});

  @override
  State<DerouleView> createState() => _DerouleViewState();
}

class _Line {
  final int start, end;
  final String kind; // session, cal, habit, task, gap, end
  final String title, sub;
  final Task? task;
  final Color color;
  final bool late;
  _Line(this.start, this.end, this.kind, this.title, this.sub, this.color, {this.task, this.late = false});
}

class _DerouleViewState extends State<DerouleView> {
  List<CalEvent> _events = [];
  String _eventsFor = '';

  String _key(AppStore store) => widget.day ?? store.todayKey;

  Future<void> _load(AppStore store) async {
    if (!store.settings.calendarRead) return;
    final k = _key(store);
    if (_eventsFor == k) return;
    _eventsFor = k;
    final ev = await PhoneCalendar.eventsOn(DateTime.parse(k));
    if (mounted && _eventsFor == k) setState(() => _events = ev);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final key = _key(store);
    final isToday = key == store.todayKey;
    _load(store);
    final d = DateTime.parse(key);
    final dayMs = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
    final now = DateTime.now().millisecondsSinceEpoch;

    final busy = <(int, int)>[];
    for (final e in _events.where((e) => !e.allDay)) {
      busy.add((e.start.millisecondsSinceEpoch, e.end.millisecondsSinceEpoch));
    }
    for (final h in store.habits.where((h) => h.reminderMin >= 0 && !h.archived)) {
      final s = dayMs + h.reminderMin * 60000;
      if (!isToday || s > now) busy.add((s, s + 15 * 60000));
    }
    final seq = store.daySequence(day: key);
    final sched = store.schedule(seq, day: key, busy: busy);

    final lines = <_Line>[];
    if (isToday) {
      for (final s in store.sessionsOn(key)) {
        final end = s.running ? now : s.end;
        lines.add(_Line(s.start, end, 'session', s.title, '${((end - s.start) / 60000).round()} min${s.running ? ' · en cours' : ''}', store.sessionCategory(s) == Act.perso ? K.pink : K.lime));
      }
    }
    for (final e in _events.where((e) => !e.allDay)) {
      lines.add(_Line(e.start.millisecondsSinceEpoch, e.end.millisecondsSinceEpoch, 'cal', e.title, fmtMin(e.end.difference(e.start).inMinutes), K.muted));
    }
    for (final h in store.habits.where((h) => h.reminderMin >= 0 && !h.archived)) {
      final s = dayMs + h.reminderMin * 60000;
      lines.add(_Line(s, s + 15 * 60000, 'habit', h.name, store.habitLevel(h, key) > 0 ? 'faite ✓' : 'habitude', K.cyan));
    }
    for (final t in seq) {
      if (t.done) continue;
      final tm = sched.times[t.id];
      if (tm == null) continue;
      final subs = store.subStepsOf(t).where((x) => !x.done).map((x) => '› ${x.title}${x.estimateMin > 0 ? ' · ${x.estimateMin} min' : ''}').join('\n');
      final color = t.category == 'pro' ? K.lime : t.category == 'perso' ? K.pink : K.gold;
      lines.add(_Line(tm.$1, tm.$2, 'task', t.title, [fmtMin(t.blockMin), if (subs.isNotEmpty) subs].join('\n'), color, task: t, late: sched.late.contains(t.id)));
    }
    lines.sort((a, b) => a.start.compareTo(b.start));

    final todo = seq.where((t) => !t.done).toList();
    final proLeft = todo.where((t) => t.category == 'pro').fold(0, (a, t) => a + t.blockMin);
    final proDone = isToday ? store.proMinutesOn(key).round() : 0;
    final goal = isToday ? store.today.proGoalMin : 0;

    const names = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.timeline_rounded, color: K.gold, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(isToday ? 'Déroulé du jour' : 'Déroulé · ${names[d.weekday - 1]} ${d.day}/${d.month}', style: K.display(18))),
      ]),
      Text(
        isToday ? 'Si tu suis l\'ordre à partir de maintenant. Rien à placer ici : ça découle de la liste.' : 'Si tu suis l\'ordre à partir de ton heure de démarrage.',
        style: K.body(12, color: K.muted),
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (lines.isEmpty) Text('Rien de prévu. Ajoute des tâches dans la liste.', style: K.body(13, color: K.muted)),
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0 && lines[i].start - lines[i - 1].end >= 10 * 60000 && lines[i].kind == 'task')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('· ${fmtMin(((lines[i].start - lines[i - 1].end) / 60000).round())} de marge ·', textAlign: TextAlign.center, style: K.body(11, color: K.dim)),
              ),
            _row(context, lines[i], now, isToday),
          ],
          if (todo.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              SizedBox(width: 48, child: Text(hm(DateTime.fromMillisecondsSinceEpoch(sched.end)), style: K.body(12, color: K.gold, w: FontWeight.w900))),
              Expanded(
                child: Text(
                  isToday && goal > 0
                      ? 'Fin · ${fmtMin(proDone + proLeft)} de pro → objectif ${fmtMin(goal)} ${proDone + proLeft >= goal ? 'atteint' : 'pas tout à fait'}'
                      : 'Fin · ${fmtMin(proLeft)} de pro prévu',
                  style: K.body(13, color: K.gold, w: FontWeight.w800),
                ),
              ),
            ]),
          ],
        ]),
      ),
      if (sched.late.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Une ancre 📌 est intenable dans cet ordre : raccourcis ce qui est avant, remonte-la dans la liste, ou décale l\'ancre.', style: K.body(12, color: K.coral)),
        ),
    ]);
  }

  Widget _row(BuildContext context, _Line l, int now, bool isToday) {
    final past = isToday && l.end <= now && l.kind != 'task';
    final left = SizedBox(
      width: 48,
      child: Text(hm(DateTime.fromMillisecondsSinceEpoch(l.start)), style: K.body(12, color: l.late ? K.coral : (l.task != null && l.task!.plannedAt > 0 ? K.gold : (past ? K.dim : K.muted)), w: FontWeight.w900)),
    );
    Widget box;
    switch (l.kind) {
      case 'cal':
        box = Container(
          decoration: BoxDecoration(color: K.raised.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(8), border: const Border(left: BorderSide(color: K.muted, width: 3))),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(children: [
            const Icon(Icons.event_rounded, color: K.muted, size: 12),
            const SizedBox(width: 6),
            Expanded(child: Text(l.title, style: K.body(12, color: K.muted, w: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text(l.sub, style: K.body(11, color: K.dim)),
          ]),
        );
        break;
      case 'habit':
        box = Container(
          decoration: BoxDecoration(color: K.cyan.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: const Border(left: BorderSide(color: K.cyan, width: 3))),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(children: [
            const Icon(Icons.repeat_rounded, color: K.cyan, size: 12),
            const SizedBox(width: 6),
            Expanded(child: Text(l.title, style: K.body(12, color: K.ink, w: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text(l.sub, style: K.body(11, color: K.cyan)),
          ]),
        );
        break;
      case 'session':
        box = Container(
          decoration: BoxDecoration(color: l.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: l.color.withValues(alpha: 0.6), width: 3))),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(children: [
            Icon(Icons.check_rounded, color: l.color, size: 12),
            const SizedBox(width: 6),
            Expanded(child: Text(l.title, style: K.body(12, color: K.muted, w: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text(l.sub, style: K.body(11, color: K.dim)),
          ]),
        );
        break;
      default:
        final t = l.task!;
        final parts = l.sub.split('\n');
        box = InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => showTaskPanel(context, t),
          child: Container(
            decoration: BoxDecoration(
              color: l.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border(left: BorderSide(color: l.late ? K.coral : l.color, width: 4)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${t.plannedAt > 0 ? '📌 ' : ''}${l.title}', style: K.body(13, w: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text(parts.first, style: K.body(11, color: K.muted, w: FontWeight.w700)),
              ]),
              for (final p in parts.skip(1)) Text(p, style: K.body(11, color: K.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (l.late) Text('en retard sur l\'ancre ${hm(DateTime.fromMillisecondsSinceEpoch(t.plannedAt))}', style: K.body(11, color: K.coral, w: FontWeight.w800)),
            ]),
          ),
        );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 6), child: left),
        Expanded(child: Opacity(opacity: past ? 0.6 : 1, child: box)),
      ]),
    );
  }
}

/// Écran plein : le déroulé. Si [place] est donné, la tâche entre d'abord dans la liste du jour.
class DerouleScreen extends StatelessWidget {
  final String? day;
  final Task? place;
  const DerouleScreen({super.key, this.day, this.place});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.read(context);
    final p = place;
    if (p != null) store.addToToday(p);
    return Scaffold(
      appBar: AppBar(title: const Text('Déroulé')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
          children: [DerouleView(day: day)],
        ),
      ),
    );
  }
}

