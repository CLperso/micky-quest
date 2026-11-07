import 'package:flutter/material.dart';

import '../canvas.dart';
import '../model.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

const goalEmojis = ['🎓', '🏃', '🗣', '📚', '🌿', '💪', '🎨', '🧘', '✍️', '🌍', '💛', '🎯', '🧠', '🎻', '🍲', '✈️'];
const goalColors = [0xFF7FA99B, 0xFFE8896B, 0xFFE9B949, 0xFFB9A7FF, 0xFFD9667A, 0xFF6FA8FF];

/// Page de gauche : mes objectifs.
class GoalsIndex extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const GoalsIndex({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final monday = mondayOf(DateTime.now());
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const PageTitle(id: 'goals', over: '', title: 'Objectifs'),
        const SizedBox(height: 10),
        for (final g in store.activeGoals)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onSelect(g.id),
              onLongPress: () => editGoal(context, g),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(g.color).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(g.color).withValues(alpha: selected == g.id ? 1 : 0.4), width: selected == g.id ? 3 : 2),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(g.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(g.title, style: titleFont(20, pal.ink))),
                    Text(g.kind == 'pro' ? 'pro' : 'perso', style: body(11, pal.soft, w: FontWeight.w800)),
                  ]),
                  if (g.why.isNotEmpty) Text(g.why, style: hand(21, pal.soft)),
                  const SizedBox(height: 6),
                  Row(children: [
                    for (var i = 0; i < g.perWeek; i++)
                      Container(
                        width: 22,
                        height: 14,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: i < store.goalStepsBetween(g.id, monday, 7) ? Color(g.color) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Color(g.color), width: 2),
                        ),
                      ),
                    const SizedBox(width: 4),
                    Text('${store.goalStepsBetween(g.id, monday, 7)} pas sur ${g.perWeek} cette semaine', style: body(11, pal.soft, w: FontWeight.w800)),
                  ]),
                ]),
              ),
            ),
          ),
        OutlinedButton.icon(onPressed: () => editGoal(context, null), icon: const Icon(Icons.add_rounded), label: const Text('Un objectif')),
        const SizedBox(height: 6),
        Text('Appui long sur un objectif pour le modifier.', style: body(11, pal.soft)),
      ]),
    );
  }
}

/// Page de droite : l'objectif choisi et ses pas.
class GoalDetail extends StatelessWidget {
  final String goalId;
  const GoalDetail({super.key, required this.goalId});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final g = store.goals[goalId];
    if (g == null || g.del) {
      return Center(child: Text('Choisis un objectif à gauche', style: hand(26, pal.soft)));
    }
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageTitle(over: g.kind == 'pro' ? 'objectif pro' : 'objectif perso', title: '${g.emoji} ${g.title}'),
        if (g.why.isNotEmpty) Text('parce que ${g.why}', style: hand(24, Color(g.color))),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          Tile('${store.goalStepsBetween(g.id, mondayOf(now), 7)}/${g.perWeek}', 'cette semaine', Color(g.color)),
          Tile('${store.goalStepsBetween(g.id, first, now.day)}', 'pas ce mois-ci', Color(g.color)),
        ]),
        const ELabel('goal.steps', 'Prochains pas'),
        BulletList(
          items: store.goalEntries(g.id).where((e) => !e.del).toList(),
          showWhen: true,
          onAdd: (t, k) async => store.addEntry(t, when: 'someday', kind: k, goal: g.id),
        ),
      ]),
    );
  }
}

Future<void> editGoal(BuildContext context, Goal? g) async {
  final store = StoreScope.read(context);
  final title = TextEditingController(text: g?.title ?? '');
  final why = TextEditingController(text: g?.why ?? '');
  var emoji = g?.emoji ?? '🎯';
  var color = g?.color ?? goalColors.first;
  var kind = g?.kind ?? 'perso';
  var per = g?.perWeek ?? 3;
  final ok = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(g == null ? 'Un objectif' : 'Modifier l’objectif'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: title, autofocus: g == null, decoration: const InputDecoration(labelText: 'Objectif')),
            TextField(controller: why, decoration: const InputDecoration(labelText: 'Parce que…')),
            const SizedBox(height: 10),
            Wrap(spacing: 4, children: [
              for (final e in goalEmojis)
                ChoiceChip(label: Text(e, style: const TextStyle(fontSize: 18)), selected: emoji == e, onSelected: (_) => setState(() => emoji = e)),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final c in goalColors)
                GestureDetector(
                  onTap: () => setState(() => color = c),
                  child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: Border.all(color: color == c ? Colors.black : Colors.transparent, width: 2))),
                ),
            ]),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'pro', label: Text('Pro')), ButtonSegment(value: 'perso', label: Text('Perso'))],
              selected: {kind},
              onSelectionChanged: (v) => setState(() => kind = v.first),
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Text('Pas par semaine'),
              const Spacer(),
              IconButton(onPressed: () => setState(() => per = (per - 1).clamp(1, 7)), icon: const Icon(Icons.remove)),
              Text('$per'),
              IconButton(onPressed: () => setState(() => per = (per + 1).clamp(1, 7)), icon: const Icon(Icons.add)),
            ]),
          ]),
        ),
        actions: [
          if (g != null) TextButton(onPressed: () => Navigator.pop(ctx, 'del'), child: const Text('Supprimer')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'ok'), child: const Text('OK')),
        ],
      ),
    ),
  );
  if (ok == null) return;
  if (ok == 'del' && g != null) {
    g.del = true;
    g.mod = nowMs();
    await store.commit();
    return;
  }
  if (title.text.trim().isEmpty) return;
  final x = g ?? Goal(title: '');
  x
    ..title = title.text.trim()
    ..why = why.text.trim()
    ..emoji = emoji
    ..color = color
    ..kind = kind
    ..perWeek = per
    ..mod = nowMs();
  store.goals[x.id] = x;
  await store.commit();
}

/// Collections : la page d'index.
class CollIndex extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const CollIndex({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const PageTitle(id: 'colls', over: '', title: 'Collections'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            for (final c in store.activeColls)
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSelect(c.id),
                onLongPress: () => editColl(context, c),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: pal.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Color(c.color).withValues(alpha: selected == c.id ? 1 : 0.35), width: selected == c.id ? 3 : 2),
                    boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.emoji, style: const TextStyle(fontSize: 22)),
                    Text(c.title, style: titleFont(16, pal.ink), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Text('${store.collEntries(c.id).where((e) => !e.done && !e.dropped).length} en cours', style: body(11, pal.soft)),
                  ]),
                ),
              ),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => editColl(context, null),
              child: Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: pal.line, width: 2)),
                child: Center(child: Text('+ une collection', style: hand(24, pal.soft))),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Appui long sur une collection pour la renommer.', style: body(11, pal.soft)),
      ]),
    );
  }
}

class CollPage extends StatelessWidget {
  final String collId;
  const CollPage({super.key, required this.collId});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final c = store.colls[collId];
    if (c == null || c.del) return Center(child: Text('Choisis une collection à gauche', style: hand(26, pal.soft)));
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageTitle(over: 'collection', title: '${c.emoji} ${c.title}'),
        const SizedBox(height: 8),
        BulletList(items: store.collEntries(c.id), showWhen: true, onAdd: (t, k) async => store.addEntry(t, coll: c.id, kind: k)),
        const ELabel('coll.notes', 'Notes'),
        HandField(
          value: c.note,
          hint: 'tout ce qui ne rentre pas ailleurs…',
          size: 24,
          maxLines: 30,
          onChanged: (v) {
            c.note = v;
            c.mod = nowMs();
            store.commit();
          },
        ),
      ]),
    );
  }
}

Future<void> editColl(BuildContext context, Collection? c) async {
  final store = StoreScope.read(context);
  final title = await askText(context, c == null ? 'Nouvelle collection' : 'Renommer', initial: c?.title ?? '', hint: 'Livres, Bangalore, Santé…');
  if (title == null) return;
  if (title.isEmpty && c != null) {
    final del = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la collection ?'),
        content: const Text('Ses lignes restent dans le carnet.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer'))],
      ),
    );
    if (del == true) {
      c.del = true;
      c.mod = nowMs();
      await store.commit();
    }
    return;
  }
  if (title.isEmpty) return;
  const emojis = ['📒', '🎤', '🌿', '💡', '📚', '✈️', '🎁', '🍲', '🧶', '💌', '🗣', '🎬'];
  const colors = [0xFFE8896B, 0xFF7FA99B, 0xFFE9B949, 0xFFB9A7FF, 0xFFD9667A, 0xFF6FA8FF];
  final x = c ?? Collection(title: '', emoji: emojis[store.colls.length % emojis.length], color: colors[store.colls.length % colors.length]);
  x.title = title;
  x.mod = nowMs();
  store.colls[x.id] = x;
  await store.commit();
}
