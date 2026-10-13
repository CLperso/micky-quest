import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'block.dart';
import 'reflect.dart';
import 'session.dart';
import 'timetable.dart';

String _fmt(int m) => m >= 60 ? '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${(m % 60).toString().padLeft(2, '0')}'}' : '$m min';

/// Couleur d'une émotion : quadrant agréable/désagréable × énergie (comme la grille du check-in).
Color moodColor(int mood, int energy) {
  if (mood <= 0) return K.muted;
  final c = mood - 1;
  final r = energy < 0 ? 2 : (4 - (energy / 25).round()).clamp(0, 4);
  if (r < 2 && c < 2) return const Color(0xFFB5443A);
  if (r < 2 && c > 2) return const Color(0xFFC9A227);
  if (r > 2 && c < 2) return const Color(0xFF3B5BA8);
  if (r > 2 && c > 2) return const Color(0xFF3E8E57);
  return const Color(0xFF6E6799);
}

List<String> moodWords(int mood, int energy) {
  final c = mood - 1;
  final r = energy < 0 ? 2 : (4 - (energy / 25).round()).clamp(0, 4);
  final high = r <= 1, low = r >= 3, bad = c <= 1, good = c >= 3;
  if (high && bad) return ['débordée', 'agacée', 'anxieuse', 'frustrée', 'pressée'];
  if (high && good) return ['motivée', 'enthousiaste', 'concentrée', 'joyeuse', 'fière'];
  if (low && bad) return ['fatiguée', 'triste', 'découragée', 'vide', 'lasse'];
  if (low && good) return ['calme', 'détendue', 'sereine', 'reposée', 'satisfaite'];
  return ['neutre', 'bof', 'ailleurs', 'tranquille', 'tendue'];
}

/// Noter un créneau après coup. [existing] pour corriger, [start]/[end] pour préremplir.
Future<void> addPastSlotSheet(BuildContext context, {Slot? existing, DateTime? start, DateTime? end}) async {
  final store = AppScope.read(context);
  final now = DateTime.now();
  var from = existing != null
      ? DateTime.fromMillisecondsSinceEpoch(existing.start)
      : start ?? DateTime(now.year, now.month, now.day, max(store.settings.startHour, now.hour - 3));
  var to = existing != null ? DateTime.fromMillisecondsSinceEpoch(existing.end) : end ?? DateTime(now.year, now.month, now.day, now.hour, (now.minute ~/ 15) * 15);
  if (!to.isAfter(from)) to = from.add(const Duration(hours: 1));
  var kind = existing?.kind ?? 'idle';
  var mood = existing?.mood ?? 0;
  var energy = existing?.energy ?? -1;
  var emotion = existing?.emotion ?? '';
  var why = existing?.why ?? '';
  final title = TextEditingController(text: existing?.title ?? '');

  DateTime snap(DateTime d) => DateTime(d.year, d.month, d.day, d.hour, (d.minute ~/ 15) * 15);
  from = snap(from);
  to = snap(to);

  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
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
      Widget timeBox(String label, DateTime t, void Function(DateTime) set) => Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(color: K.bg, borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text(label, style: K.body(11, color: K.muted, w: FontWeight.w800)),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(onPressed: () => setState(() => set(t.subtract(const Duration(minutes: 15)))), icon: const Icon(Icons.remove_rounded, color: K.muted)),
                  Text(hm(t), style: K.display(20)),
                  IconButton(onPressed: () => setState(() => set(t.add(const Duration(minutes: 15)))), icon: const Icon(Icons.add_rounded, color: K.muted)),
                ]),
              ]),
            ),
          );
      final mins = to.difference(from).inMinutes;
      final kindColors = {'pro': K.lime, 'perso': K.pink, 'pause': K.cyan, 'phone': K.dim, 'idle': moodColor(mood, energy) == K.muted ? K.coral : moodColor(mood, energy)};
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
                Text(existing == null ? 'Noter un créneau passé' : 'Corriger le créneau', style: K.display(20)),
                Text('Sans jugement : c\'est pour voir ta journée telle qu\'elle a été.', style: K.body(12, color: K.muted)),
                const SizedBox(height: 10),
                Row(children: [
                  timeBox('De', from, (v) => from = v),
                  const SizedBox(width: 8),
                  timeBox('À', to, (v) => to = v),
                ]),
                const SizedBox(height: 4),
                Text(mins > 0 ? _fmt(mins) : 'la fin doit être après le début', style: K.body(12, color: mins > 0 ? K.gold : K.coral, w: FontWeight.w800)),
                const SizedBox(height: 10),
                Text('C\'ÉTAIT', style: K.body(11, color: K.muted, w: FontWeight.w900)),
                const SizedBox(height: 6),
                Wrap(children: [
                  for (final k in Slot.kinds) chip(Slot.labels[k]!, kind == k, kindColors[k]!, () => setState(() => kind = k)),
                ]),
                if (kind == 'pro' || kind == 'perso')
                  TextField(
                    controller: title,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Sur quoi ? (facultatif)'),
                  ),
                const SizedBox(height: 10),
                Text('ET TU TE SENTAIS', style: K.body(11, color: K.muted, w: FontWeight.w900)),
                const SizedBox(height: 6),
                MiniMoodGrid(
                  mood: mood,
                  energy: energy,
                  onChanged: (m, e) => setState(() {
                    mood = m;
                    energy = e;
                    if (!moodWords(mood, energy).contains(emotion)) emotion = '';
                  }),
                ),
                if (mood > 0) ...[
                  const SizedBox(height: 8),
                  Wrap(children: [
                    for (final w in moodWords(mood, energy)) chip(w, emotion == w, moodColor(mood, energy), () => setState(() => emotion = emotion == w ? '' : w)),
                  ]),
                ],
                if (kind == 'idle' || kind == 'phone') ...[
                  const SizedBox(height: 6),
                  Text('POURQUOI, À TON AVIS ? (FACULTATIF)', style: K.body(11, color: K.muted, w: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Wrap(children: [
                    for (final w in Slot.whys) chip(w, why == w, K.gold, () => setState(() => why = why == w ? '' : w)),
                  ]),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  if (existing != null) ...[
                    Expanded(child: SecondaryButton(label: 'Supprimer', onPressed: () => Navigator.pop(ctx, 'delete'))),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: PrimaryButton(
                      label: existing == null ? 'Noter · +1 XP' : 'Enregistrer',
                      onPressed: mins <= 0 ? null : () => Navigator.pop(ctx, 'save'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      );
    }),
  );
  final t = title.text.trim();
  title.dispose();
  if (result == 'delete' && existing != null) {
    await store.removeSlot(existing);
    return;
  }
  if (result != 'save') return;
  final x = existing ?? Slot(start: 0, end: 0, kind: kind);
  x
    ..start = from.millisecondsSinceEpoch
    ..end = to.millisecondsSinceEpoch
    ..kind = kind
    ..title = t
    ..mood = mood
    ..energy = energy
    ..emotion = emotion
    ..why = why;
  await store.saveSlot(x);
  if (existing == null && (kind == 'idle' || kind == 'phone') && x.minutes >= 45 && context.mounted) {
    await showRecoverCard(context, x);
  }
}

/// Grille 5 × 5 compacte : agréable ↔ désagréable, énergie.
class MiniMoodGrid extends StatelessWidget {
  final int mood;
  final int energy;
  final void Function(int mood, int energy) onChanged;
  const MiniMoodGrid({super.key, required this.mood, required this.energy, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final selR = mood <= 0 ? -1 : (energy < 0 ? 2 : (4 - (energy / 25).round()).clamp(0, 4));
    final selC = mood - 1;
    return Column(children: [
      for (var r = 0; r < 5; r++)
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(children: [
            for (var c = 0; c < 5; c++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: c < 4 ? 3 : 0),
                  child: GestureDetector(
                    onTap: () => (selR == r && selC == c) ? onChanged(0, -1) : onChanged(c + 1, (4 - r) * 25),
                    child: Container(
                      height: 26,
                      decoration: BoxDecoration(
                        color: moodColor(c + 1, (4 - r) * 25).withValues(alpha: selR == r && selC == c ? 1 : 0.75),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: selR == r && selC == c ? K.ink : Colors.transparent, width: 3),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('désagréable', style: K.body(10, color: K.muted, w: FontWeight.w800)),
        Text('↑ énergie', style: K.body(10, color: K.muted, w: FontWeight.w800)),
        Text('agréable', style: K.body(10, color: K.muted, w: FontWeight.w800)),
      ]),
    ]);
  }
}

/// Après un créneau improductif : rattraper, comprendre ou accepter.
Future<void> showRecoverCard(BuildContext context, Slot x) async {
  final store = AppScope.read(context);
  final p = store.today;
  final now = DateTime.now();
  final endOfDay = DateTime(now.year, now.month, now.day, store.settings.endHour);
  final left = max(0, endOfDay.difference(now).inMinutes);
  final pro = store.proMinutesOn(store.todayKey).round();
  final missing = max(0, p.proGoalMin - pro);
  final msg = p.proGoalMin > 0
      ? (missing == 0
          ? 'Ton objectif pro est déjà atteint. Ce créneau n\'enlève rien.'
          : 'Il reste ${_fmt(left)} dans ta journée. ${_fmt(missing)} suffisent pour la médaille d\'argent.')
      : 'Il reste ${_fmt(left)} dans ta journée. Une seule session suffit à la relancer.';
  final mins = x.minutes.round();
  final a = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: K.line, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 10),
            MickySays('${_fmt(mins)} qui ont glissé. C\'est noté, et c\'est déjà ça : tu regardes ta journée en face. Une matinée ne fait pas ta journée.', pose: 'belly', ring: K.pink),
            const SizedBox(height: 10),
            Text(msg, style: K.body(13, color: K.gold, w: FontWeight.w800)),
            const SizedBox(height: 12),
            _path(ctx, 'Rattraper', 'Jusqu\'où tu peux aller maintenant ?', K.lime, Icons.play_arrow_rounded, children: [
              Row(children: [
                for (final m in [10, 25, 60]) ...[
                  Expanded(child: SecondaryButton(label: '$m min', onPressed: () => Navigator.pop(ctx, 'go:$m'))),
                  if (m != 60) const SizedBox(width: 6),
                ],
              ]),
              const SizedBox(height: 6),
              TextButton(onPressed: () => Navigator.pop(ctx, 'plan'), child: const Text('Caser un bloc plus tard dans la journée')),
            ]),
            _path(ctx, 'Comprendre', 'Ce qui s\'est passé, pour la prochaine fois', K.cyan, Icons.psychology_alt_rounded, children: [
              Row(children: [
                Expanded(child: SecondaryButton(label: 'Je bloque', onPressed: () => Navigator.pop(ctx, 'block'))),
                const SizedBox(width: 6),
                Expanded(child: SecondaryButton(label: 'Qu\'est-ce que j\'évitais ?', onPressed: () => Navigator.pop(ctx, 'reflect'))),
              ]),
            ]),
            _path(ctx, 'Accepter', 'Tant pis, c\'est fait. On garde l\'énergie pour la suite.', K.pink, Icons.spa_rounded, children: [
              Row(children: [
                Expanded(child: SecondaryButton(label: 'Tant pis', onPressed: () => Navigator.pop(ctx, 'accept'))),
                if (p.proGoalMin > 60) ...[
                  const SizedBox(width: 6),
                  Expanded(child: SecondaryButton(label: 'Objectif −1 h', onPressed: () => Navigator.pop(ctx, 'accept60'))),
                ],
              ]),
              if (p.proGoalMin > 60)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Baisser l\'objectif garde la médaille atteignable : mieux qu\'un « foutu pour foutu ».', style: K.body(11, color: K.muted)),
                ),
            ]),
          ],
        ),
      ),
    ),
  );
  if (a == null || !context.mounted) return;
  if (a.startsWith('go:')) {
    final m = int.parse(a.substring(3));
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AppScope(store: store, child: StartSessionSheet(minutes: m)),
    );
    if (ok == true && context.mounted) openScreen(context, const SessionScreen());
  } else if (a == 'plan') {
    openScreen(context, PlanningScreen(day: store.todayKey));
  } else if (a == 'block') {
    openScreen(context, const BlockScreen());
  } else if (a == 'reflect') {
    openScreen(context, ReflectionScreen(kind: 'decroche', title: 'Créneau de ${hm(DateTime.fromMillisecondsSinceEpoch(x.start))} à ${hm(DateTime.fromMillisecondsSinceEpoch(x.end))}'));
  } else if (a == 'accept' || a == 'accept60') {
    await store.acceptSlot(lowerGoalBy: a == 'accept60' ? 60 : 0);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accepté. +Sérénité. La suite de la journée t\'appartient.')));
    }
  }
}

Widget _path(BuildContext ctx, String title, String sub, Color c, IconData icon, {required List<Widget> children}) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: K.bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: c, width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: c),
            const SizedBox(width: 8),
            Text(title, style: K.display(16, color: c)),
          ]),
          Text(sub, style: K.body(12, color: K.muted)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
