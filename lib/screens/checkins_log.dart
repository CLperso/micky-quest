import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'checkin.dart';

/// Journal des check-ins d'une journée : répondus (à corriger) et manqués (à compléter).
class CheckinsLogScreen extends StatefulWidget {
  const CheckinsLogScreen({super.key});

  @override
  State<CheckinsLogScreen> createState() => _CheckinsLogScreenState();
}

class _CheckinsLogScreenState extends State<CheckinsLogScreen> {
  DateTime _day = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final key = dayKey(_day);
    final isToday = key == store.todayKey;
    final answered = store.checkinsOn(key)..sort((a, b) => a.ts.compareTo(b.ts));

    // créneaux attendus ce jour-là
    final s = store.settings;
    final interval = max(15, s.intervalMin);
    final base = DateTime(_day.year, _day.month, _day.day);
    final now = DateTime.now();
    final slots = <DateTime>[];
    for (var m = s.startHour * 60 + interval; m <= s.endHour * 60; m += interval) {
      final t = base.add(Duration(minutes: m));
      if (t.isAfter(now)) break;
      if (store.pausedAt(t)) continue;
      slots.add(t);
    }
    final half = interval * 60000 ~/ 2;
    final rows = <_Row>[
      for (final c in answered) _Row(DateTime.fromMillisecondsSinceEpoch(c.ts), c),
      for (final t in slots)
        if (!answered.any((c) => (c.ts - t.millisecondsSinceEpoch).abs() <= half)) _Row(t, null),
    ]..sort((a, b) => a.time.compareTo(b.time));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal des check-ins'),
        actions: [
          IconButton(
            tooltip: 'Jour précédent',
            onPressed: () => setState(() => _day = _day.subtract(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Center(child: Text(isToday ? 'Aujourd\'hui' : '${_day.day}/${_day.month}', style: K.body(14, w: FontWeight.w800))),
          IconButton(
            tooltip: 'Jour suivant',
            onPressed: isToday ? null : () => setState(() => _day = _day.add(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text('Touche une ligne pour corriger ou compléter.', style: K.body(13, color: K.muted)),
            const SizedBox(height: 10),
            if (rows.isEmpty) Text('Rien ce jour-là.', style: K.body(14, color: K.muted)),
            for (final r in rows) _tile(context, store, r),
            const SizedBox(height: 14),
            SecondaryButton(
              label: 'Ajouter un check-in à une autre heure',
              onPressed: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now));
                if (t == null || !context.mounted) return;
                openScreen(context, CheckinScreen(at: DateTime(_day.year, _day.month, _day.day, t.hour, t.minute)));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, AppStore store, _Row r) {
    final c = r.checkin;
    final cat = c == null ? '' : store.categoryOf(c);
    final color = c == null
        ? K.dim
        : cat == Act.pro
            ? K.lime
            : cat == Act.perso
                ? K.pink
                : K.cyan;
    String summary;
    if (c == null) {
      summary = 'Sans réponse · touche pour compléter';
    } else {
      final parts = <String>[];
      if (c.activity.isNotEmpty) parts.add(Act.labels[c.activity] ?? c.activity);
      final t = c.taskId.isEmpty ? null : store.taskById(c.taskId);
      if (t != null) parts.add(t.title);
      if (c.sinceMin >= 0) parts.add('${c.sinceMin} min');
      if (c.mood > 0) parts.add(AppStore.moodLabels[c.mood - 1].toLowerCase());
      if (c.energy >= 0) parts.add('énergie ${c.energy} %');
      if (c.reason.isNotEmpty) parts.add(c.reason);
      if (c.note.isNotEmpty) parts.add(c.note);
      summary = parts.isEmpty ? 'Répondu sans détail' : parts.join(' · ');
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: K.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => openScreen(context, c == null ? CheckinScreen(at: r.time) : CheckinScreen(existing: c)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                SizedBox(width: 48, child: Text(hm(r.time), style: K.body(14, w: FontWeight.w800))),
                Expanded(child: Text(summary, style: K.body(13, color: c == null ? K.muted : K.ink))),
                Icon(c == null ? Icons.add_circle_outline_rounded : Icons.edit_rounded, color: K.muted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row {
  final DateTime time;
  final CheckIn? checkin;
  _Row(this.time, this.checkin);
}
