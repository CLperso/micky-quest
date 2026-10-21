import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';
import 'cabin.dart';
import '../notifications.dart';
import 'session.dart' show SessionScreen;
import 'timetable.dart' show askText, launchTask;

const kBlue = Color(0xFF6FA8FF);

String modeLabel(String m) => m == 'sans' ? '🌧 Jour sans' : (m == 'vague' ? '🌊 Sur la vague' : '☀️ Journée normale');
Color modeColor(String m) => m == 'sans' ? kBlue : (m == 'vague' ? K.cyan : K.lime);

/// « Aujourd'hui, c'est quel genre de journée ? » : normale, jour sans, sur la vague.
class ModeChooser extends StatelessWidget {
  const ModeChooser({super.key});

  Widget _tile(BuildContext context, String m, String icon, String t, String sub) {
    final store = AppScope.of(context);
    final on = store.today.mode == m;
    final c = modeColor(m);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => chooseMode(context, m),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: on ? c.withValues(alpha: 0.15) : Colors.transparent,
            border: Border.all(color: on ? c : K.line, width: 2),
          ),
          child: Column(children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            Text(t, textAlign: TextAlign.center, style: K.display(14, color: on ? c : K.ink)),
            Text(sub, textAlign: TextAlign.center, style: K.body(10, color: K.muted)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Row(children: [
        _tile(context, '', '☀️', 'Normale', 'le plan habituel'),
        const SizedBox(width: 8),
        _tile(context, 'sans', '🌧', 'Jour sans', 'on garde le fil'),
        const SizedBox(width: 8),
        _tile(context, 'vague', '🌊', 'Sur la vague', 'un projet, à fond'),
      ]);
}

/// Change le genre de journée ; pour la vague, demande le projet.
Future<void> chooseMode(BuildContext context, String m) async {
  final store = AppScope.read(context);
  if (m != 'vague') {
    await store.setMode(m);
    if (m == 'sans' && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jour sans : 30 min de pro suffisent, 3 tâches, les habitudes mini comptent.')));
    }
    return;
  }
  final ideas = store.focusIdeas();
  final boss = store.boss;
  final f = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🌊 Ton projet du jour', style: K.display(19)),
          Text('La liste se replie sur lui ; le reste attend ce soir. Les 📌 restent visibles.', style: K.body(12, color: K.muted)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final w in ideas)
              ActionChip(label: Text(w), backgroundColor: K.raised, side: BorderSide.none, onPressed: () => Navigator.pop(ctx, w)),
            if (boss != null)
              ActionChip(label: Text('Le boss : ${boss.title}'), backgroundColor: K.raised, side: BorderSide.none, onPressed: () => Navigator.pop(ctx, boss.id)),
            ActionChip(label: const Text('autre…'), backgroundColor: K.raised, side: BorderSide.none, onPressed: () => Navigator.pop(ctx, '?')),
          ]),
        ]),
      ),
    ),
  );
  if (f == null || !context.mounted) return;
  var focus = f;
  if (f == '?') {
    final v = await askText(context, 'Le projet du jour', hint: 'un mot qui est dans le titre de ses tâches : SCA, QALEM…');
    if (v == null || v.trim().isEmpty) return;
    focus = v.trim();
  }
  await store.setMode('vague', focus: focus);
}

/// Pastille du QG / d'Aujourd'hui : le mode du jour, touche pour changer.
class ModePill extends StatelessWidget {
  const ModePill({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final m = store.today.mode;
    final c = modeColor(m);
    final f = store.today.focus;
    final focusName = m == 'vague' ? (store.taskById(f)?.title ?? f) : '';
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => showModalBottomSheet(
        context: context,
        builder: (ctx) => AppScope(
          store: store,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Aujourd\'hui, c\'est quel genre de journée ?', style: K.display(17)),
                const SizedBox(height: 10),
                const ModeChooser(),
              ]),
            ),
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
        child: Text('${modeLabel(m)}${focusName.isNotEmpty ? ' · $focusName' : ''} · changer', style: K.body(12, color: c, w: FontWeight.w900)),
      ),
    );
  }
}

/// Bandeau en tête d'Aujourd'hui selon le mode.
class ModeBanner extends StatelessWidget {
  const ModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final m = store.today.mode;
    if (m.isEmpty) return const SizedBox.shrink();
    final c = modeColor(m);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: c.withValues(alpha: 0.5), width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          m == 'sans'
              ? 'Un jour sans, ce n\'est pas un jour perdu. ${store.settings.dirMinPro} min de pro suffisent, l\'heure de démarrage ne compte pas, tes habitudes en version mini comptent en entier.'
              : 'Sur la vague : une session ouverte, sans pari ni check-in. Une pause-corps toutes les 90 min. Le temps pro compte double pour le coffre du soir.',
          style: K.body(13),
        ),
        if (m == 'vague') ...[
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final run = store.runningSession;
            final f = store.today.focus;
            final ft = store.taskById(f);
            final name = ft?.title ?? f;
            final matches = store.daySequence().where((t) => !t.done && store.inFocus(t)).length;
            if (run != null) {
              final min = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(run.start)).inMinutes;
              return PrimaryButton(label: '🌊 En cours : ${run.title} · $min min', color: K.cyan, onPressed: () => openScreen(context, const SessionScreen()));
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              PrimaryButton(
                label: '▶ Lancer la vague · $name',
                color: K.cyan,
                onPressed: () async {
                  if (ft != null) return launchTask(context, ft);
                  await store.startSession('', name, 0, category: 'pro', silent: true, flow: true);
                  await rescheduleAll(store);
                  if (context.mounted) await openScreen(context, const SessionScreen());
                },
              ),
              const SizedBox(height: 4),
              Text(
                matches == 0
                    ? 'Aucune tâche du jour ne contient « $name » : la vague se lance sur le projet lui-même. Chaque minute compte en pro.'
                    : 'Ou ▶ sur une tâche du projet ci-dessous. Chaque minute de la session compte en pro, en direct.',
                style: K.body(11, color: K.muted),
              ),
            ]);
          }),
        ],
        if (m == 'sans')
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
            onPressed: () => openScreen(context, const CabinScreen()),
            child: Text('🏕 Si ça pèse : la cabane est là', style: K.body(12, color: const Color(0xFFB9A7FF), w: FontWeight.w800)),
          ),
      ]),
    );
  }
}
