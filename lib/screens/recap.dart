import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'cards.dart' show showPendingCard;

/// Ce qui est déjà connu de la journée : sessions et créneaux notés (début, fin, libellé, couleur).
List<(int, int, String, Color)> _known(AppStore store, String day) {
  final out = <(int, int, String, Color)>[];
  final now = DateTime.now().millisecondsSinceEpoch;
  for (final s in store.sessionsOn(day)) {
    out.add((s.start, s.running ? now : s.end, s.title, store.sessionCategory(s) == Act.perso ? K.pink : K.lime));
  }
  for (final x in store.slotsOn(day)) {
    final c = x.kind == 'pro' ? K.lime : x.kind == 'perso' ? K.pink : x.kind == 'pause' ? K.cyan : (x.kind == 'phone' ? K.coral : const Color(0xFFB9A7FF));
    out.add((x.start, x.end, '${Slot.labels[x.kind] ?? x.kind}${x.title.isNotEmpty ? ' · ${x.title}' : ''}', c));
  }
  out.sort((a, b) => a.$1.compareTo(b.$1));
  return out;
}

/// Dernière trace dans l'appli aujourd'hui (session, créneau, check-in, tâche cochée).
int lastTrace(AppStore store) {
  final day = store.todayKey;
  var last = 0;
  for (final k in _known(store, day)) {
    last = max(last, k.$2);
  }
  for (final c in store.checkinsOn(day)) {
    last = max(last, c.ts);
  }
  for (final t in store.tasks) {
    if (t.done && t.doneAt > 0 && dayKey(DateTime.fromMillisecondsSinceEpoch(t.doneAt)) == day) last = max(last, t.doneAt);
  }
  return last;
}

/// Début de la journée à raconter : la première trace, sinon l'heure de début réglée.
int dayStart(AppStore store) {
  final n = DateTime.now();
  final set = DateTime(n.year, n.month, n.day, store.settings.startHour).millisecondsSinceEpoch;
  final k = _known(store, store.todayKey);
  return k.isEmpty ? set : min(set, k.first.$1);
}

/// QG : « Pas d'appli depuis 9h ? Raconte en gros. »
class RecapBanner extends StatefulWidget {
  const RecapBanner({super.key});

  @override
  State<RecapBanner> createState() => _RecapBannerState();
}

class _RecapBannerState extends State<RecapBanner> {
  static String _hidden = '';

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final now = DateTime.now();
    if (_hidden == store.todayKey) return const SizedBox.shrink();
    final from = max(lastTrace(store), dayStart(store));
    final gap = now.millisecondsSinceEpoch - from;
    if (gap < 2 * 3600000 || now.hour * 60 > store.settings.workEnd + 120 || now.hour < store.settings.startHour + 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: K.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => openScreen(context, const RecapScreen()),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: K.lime, width: 2)),
            child: Row(children: [
              ClipOval(child: Image.asset(K.micky['happy']!, width: 40, height: 40, fit: BoxFit.cover)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Rien depuis ${hm(DateTime.fromMillisecondsSinceEpoch(from))} ?', style: K.display(15)),
                  Text('Raconte en gros ce que tu as fait : ça compte pareil.', style: K.body(12, color: K.muted)),
                ]),
              ),
              IconButton(onPressed: () => setState(() => _hidden = store.todayKey), icon: const Icon(Icons.close_rounded, color: K.muted, size: 18)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// « Ce que j'ai fait » : la journée en créneaux, les trous se remplissent après coup.
class RecapScreen extends StatelessWidget {
  const RecapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final now = DateTime.now().millisecondsSinceEpoch;
    final known = _known(store, store.todayKey);
    // la frise : connu + trous (≥ 15 min), découpés à l'heure pile
    final items = <(int, int, String, Color, bool)>[];
    var cur = dayStart(store);
    void gaps(int until) {
      while (until - cur >= 15 * 60000) {
        final d = DateTime.fromMillisecondsSinceEpoch(cur);
        final nextHour = DateTime(d.year, d.month, d.day, d.hour + 1).millisecondsSinceEpoch;
        final e = min(until, nextHour);
        if (e - cur >= 15 * 60000) items.add((cur, e, '', K.line, false));
        cur = e;
      }
      cur = max(cur, until);
    }

    for (final k in known) {
      gaps(k.$1);
      items.add((k.$1, k.$2, k.$3, k.$4, true));
      cur = max(cur, k.$2);
    }
    gaps(now);

    return Scaffold(
      appBar: AppBar(title: const Text('Ce que j\'ai fait')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            const MickySays('Pas d\'appli pendant un moment ? Pas grave. Raconte en gros : ça compte pareil.', ring: K.lime),
            const SizedBox(height: 12),
            for (final it in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 48, child: Padding(padding: const EdgeInsets.only(top: 8), child: Text(hm(DateTime.fromMillisecondsSinceEpoch(it.$1)), style: K.body(12, color: K.muted, w: FontWeight.w900)))),
                  Expanded(
                    child: it.$5
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(color: it.$4.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10), border: Border(left: BorderSide(color: it.$4, width: 4))),
                            child: Row(children: [
                              Expanded(child: Text(it.$3, style: K.body(13, w: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              Text('${((it.$2 - it.$1) / 60000).round()} min', style: K.body(11, color: K.muted)),
                            ]),
                          )
                        : InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => fillGap(context, it.$1, it.$2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: K.line, width: 2)),
                              child: Text('+ ${hm(DateTime.fromMillisecondsSinceEpoch(it.$1))} → ${hm(DateTime.fromMillisecondsSinceEpoch(it.$2))} : tu faisais quoi ?', style: K.body(12, color: K.muted)),
                            ),
                          ),
                  ),
                ]),
              ),
            const SizedBox(height: 8),
            Text('Le temps raconté compte en pro / perso, dans tes objectifs et Ma direction. Une tâche marquée finie donne sa carte Micky.', style: K.body(12, color: K.dim)),
          ],
        ),
      ),
    );
  }
}

/// Remplir un trou : quoi, sur quelle tâche, combien de temps, et est-ce fini ?
Future<void> fillGap(BuildContext context, int from, int to) async {
  final store = AppScope.read(context);
  var kind = 'pro';
  Task? task;
  var minutes = max(15, ((to - from) / 60000).round());
  final maxMin = minutes;
  var finished = false;
  final tasks = store.daySequence().where((t) => !t.done).toList();
  Widget chip(String label, bool on, Color c, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6, bottom: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(color: on ? c : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: on ? c : K.line, width: 2)),
            child: Text(label, style: K.body(12, color: on ? K.bg : K.ink, w: FontWeight.w800)),
          ),
        ),
      );
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(18, 16, 18, 16), children: [
            Text('${hm(DateTime.fromMillisecondsSinceEpoch(from))} → ${hm(DateTime.fromMillisecondsSinceEpoch(to))}, tu faisais…', style: K.display(18)),
            const SizedBox(height: 10),
            Wrap(children: [
              chip('Pro', kind == 'pro', K.lime, () => setState(() => kind = 'pro')),
              chip('Perso', kind == 'perso', K.pink, () => setState(() => kind = 'perso')),
              chip('Pause', kind == 'pause', K.cyan, () => setState(() => kind = 'pause')),
              chip('Téléphone', kind == 'phone', K.coral, () => setState(() => kind = 'phone')),
              chip('Je ne sais plus', kind == 'idle', const Color(0xFFB9A7FF), () => setState(() => kind = 'idle')),
            ]),
            if (kind == 'pro' || kind == 'perso') ...[
              const SizedBox(height: 6),
              Text('Sur une tâche ?', style: K.body(12, color: K.muted)),
              const SizedBox(height: 6),
              Wrap(children: [
                for (final t in tasks.where((t) => kind == 'pro' ? t.category != 'perso' : t.category == 'perso').take(10))
                  chip(t.title, task?.id == t.id, kind == 'pro' ? K.lime : K.pink, () => setState(() => task = task?.id == t.id ? null : t)),
              ]),
            ],
            const SizedBox(height: 6),
            Text('Combien de temps ?', style: K.body(12, color: K.muted)),
            const SizedBox(height: 6),
            Wrap(children: [
              for (final m in {15, 30, 45, 60, 90, maxMin}.where((m) => m <= maxMin).toList()..sort())
                chip(m >= 60 ? '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60}'}' : '$m min', minutes == m, K.cyan, () => setState(() => minutes = m)),
            ]),
            if (task != null)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: K.lime,
                value: finished,
                onChanged: (v) => setState(() => finished = v ?? false),
                title: Text('Et c\'est fini', style: K.body(14, w: FontWeight.w800)),
              ),
            const SizedBox(height: 8),
            PrimaryButton(label: 'Noter', onPressed: () => Navigator.pop(ctx, true)),
          ]),
        ),
      ),
    ),
  );
  if (ok != true) return;
  await store.saveSlot(Slot(start: from, end: from + minutes * 60000, kind: kind, title: task?.title ?? ''));
  final t = task;
  if (finished && t != null && !t.done) {
    await store.completeTask(t);
    if (context.mounted) await showPendingCard(context);
  }
}
