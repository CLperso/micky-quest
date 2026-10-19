import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'timetable.dart' show askText;

const _vio = Color(0xFFB9A7FF);
TextStyle _lora(double size, {Color color = K.ink}) => GoogleFonts.lora(fontSize: size, fontStyle: FontStyle.italic, height: 1.45, color: color);

String _hm(int m) => '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')}';
String _dur(int m) => m >= 60 ? '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60}'}' : '$m min';

/// Suggestions d'intention pro, semaine par semaine (le plan des papiers, en arrière-plan).
const dirPlan = [
  'QALEM : analyses finies (Spearman-Brown, AFE) et OSF déposé',
  'QALEM : résultats et tableaux rédigés',
  'QALEM : méthode et introduction',
  'QALEM : discussion, version complète à ma directrice',
  'SCA : OSF révisé, plan des Excel',
  'SCA : Excel refaits',
  'SCA : PubMed relancé, premier tri',
  'QALEM : retours intégrés, tout revérifié, avis extérieurs',
  'SCA : tri fini, analyses relancées',
  'QALEM : avis extérieurs intégrés, soumis',
  'SCA : méthode et résultats rédigés',
  'SCA : introduction et discussion, à ma directrice',
  'SCA : retours intégrés, revérifié, avis extérieurs',
];

/// Petit anneau de progression.
class _Ring extends StatelessWidget {
  final double frac;
  final Color color;
  final String label;
  final double size;
  const _Ring(this.frac, this.color, this.label, {this.size = 46});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(value: frac.clamp(0.0, 1.0), strokeWidth: 5, color: color, backgroundColor: K.raised),
          ),
          Text(label, style: K.display(size * 0.27, color: color)),
        ]),
      );
}

/// Carte du QG : une raison, la constance de la semaine. Un tap ouvre Ma direction.
class DirectionCard extends StatelessWidget {
  const DirectionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.settings;
    final kept = store.weekKept(DateTime.now());
    return GestureDetector(
      onTap: () => openScreen(context, const DirectionScreen()),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3A2A6E), Color(0xFF22194A), K.bg]),
          border: Border.all(color: _vio.withValues(alpha: 0.35), width: 2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('MA DIRECTION · SEMAINE ${store.dirWeek() + 1} / 13', style: K.body(11, color: _vio, w: FontWeight.w900)),
            const Spacer(),
            if (store.reviewDue) Pill('bilan à faire', color: K.bg, fill: K.gold) else const Icon(Icons.chevron_right_rounded, color: K.muted, size: 18),
          ]),
          const SizedBox(height: 8),
          Text('« ${store.reasonOfDay} »', style: _lora(16)),
          const SizedBox(height: 10),
          Row(children: [
            _Ring(kept / max(1, s.dirProTgt), K.lime, '$kept/${s.dirProTgt}'),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                s.dirIntention.isNotEmpty ? 'jours tenus cette semaine\nCette semaine : ${s.dirIntention}' : 'jours tenus cette semaine\nDémarrer avant ${_hm(s.startTarget)} · ${_dur(s.dirProDefault)} de pro',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: K.body(12, color: K.muted),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Ma direction : motivations, constance de la semaine, parcours de 13 semaines.
class DirectionScreen extends StatelessWidget {
  const DirectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.settings;
    final week = store.dirWeek();
    final days = store.weekDays(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Ma direction')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            InkWell(
              onTap: () async {
                final v = await askText(context, 'Ma phrase', initial: s.dirPhrase);
                if (v == null) return;
                s.dirPhrase = v.trim();
                await store.updateSettings();
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: _vio.withValues(alpha: 0.1),
                  border: const Border(left: BorderSide(color: _vio, width: 3)),
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(14), bottomRight: Radius.circular(14)),
                ),
                child: Text(s.dirPhrase.isEmpty ? 'Touche pour écrire ta phrase…' : '« ${s.dirPhrase} »', style: _lora(16)),
              ),
            ),
            const SizedBox(height: 12),
            if (store.reviewDue) ...[
              Material(
                color: const Color(0xFF2A2516),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => openScreen(context, const WeekReviewScreen()),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: K.gold, width: 2)),
                    child: Row(children: [
                      const Icon(Icons.event_repeat_rounded, color: K.gold),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Le bilan de la semaine · 2 min, quand tu veux', style: K.body(14, w: FontWeight.w800))),
                      const Icon(Icons.chevron_right_rounded, color: K.gold),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _Path(week: week, held: [for (var i = 0; i < 13; i++) i < week && store.weekHeld(i)]),
            const SizedBox(height: 6),
            Text('Une pierre par semaine. Micky avance quand ta semaine est tenue, même à moitié.', style: K.body(12, color: K.muted)),
            const SizedBox(height: 14),
            Text('DEVENIR CONSTANTE · CETTE SEMAINE', style: K.body(11, color: _vio, w: FontWeight.w900)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => editHourGoals(context),
                icon: const Icon(Icons.tune_rounded, size: 16, color: K.cyan),
                label: Text('Changer mes heures', style: K.body(12, color: K.cyan, w: FontWeight.w800)),
              ),
            ),
            _PillarRow(
              icon: '⏰',
              title: 'Démarrer avant ${_hm(s.startTarget)}',
              target: s.dirStartTgt,
              values: [for (final d in days) store.pillarStart(d)],
              color: K.lime,
            ),
            _PillarRow(
              icon: '💼',
              title: '${_dur(s.dirProDefault)} de pro (ou jour minimum ${s.dirMinPro} min)',
              target: s.dirProTgt,
              values: [for (final d in days) store.pillarPro(d)],
              color: K.lime,
            ),
            for (final h in store.activeHabits)
              _PillarRow(
                icon: '🌸',
                title: h.name,
                target: s.dirHabTgt,
                values: [for (final d in days) store.pillarHabit(h, d)],
                color: K.pink,
              ),
            if (store.twoMissed())
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Hier et avant-hier ont été difficiles. Aujourd\'hui, un jour minimum suffit : ${s.dirMinPro} min de pro, et c\'est tenu.',
                    style: K.body(12, color: K.gold)),
              ),
            const SizedBox(height: 6),
            Text('Rond plein = tenu · pointillé = jour minimum (ça compte). Tout se remplit tout seul avec tes sessions, check-ins et habitudes.',
                style: K.body(11, color: K.dim)),
            const SizedBox(height: 16),
            Text('MES OBJECTIFS SUR 3 MOIS', style: K.body(11, color: _vio, w: FontWeight.w900)),
            const SizedBox(height: 6),
            _goalTile(context, store, '📄', 'Pro', s.dirPro, (v) => s.dirPro = v),
            _goalTile(context, store, '🏃', 'Perso', s.dirPerso, (v) => s.dirPerso = v),
            if (s.dirIntention.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Intention pro de la semaine : ${s.dirIntention}', style: K.body(13, color: K.muted)),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text('MES RAISONS', style: K.body(11, color: _vio, w: FontWeight.w900))),
              TextButton(onPressed: () => openScreen(context, const DigWhyScreen()), child: Text('+ creuser', style: K.body(12, color: K.cyan, w: FontWeight.w800))),
            ]),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: s.dirReasons.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onLongPress: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: K.card,
                        title: const Text('Retirer cette raison ?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Retirer')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      s.dirReasons.removeAt(i);
                      await store.updateSettings();
                    }
                  },
                  child: Container(
                    width: 190,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(16)),
                    child: Text('« ${s.dirReasons[i]} »', style: _lora(13), overflow: TextOverflow.fade),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SecondaryButton(label: 'Faire le bilan de la semaine', onPressed: () => openScreen(context, const WeekReviewScreen())),
          ],
        ),
      ),
    );
  }

  Widget _goalTile(BuildContext context, AppStore store, String icon, String label, String value, void Function(String) set) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: K.card,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final v = await askText(context, 'Objectif $label sur 3 mois', hint: 'une phrase', initial: value);
              if (v == null) return;
              set(v.trim());
              await store.updateSettings();
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Text(icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(child: Text(value.isEmpty ? '$label : touche pour l\'écrire' : value, style: K.body(14, color: value.isEmpty ? K.dim : K.ink, w: FontWeight.w700))),
                const Icon(Icons.edit_rounded, color: K.muted, size: 16),
              ]),
            ),
          ),
        ),
      );
}

class _Path extends StatelessWidget {
  final int week;
  final List<bool> held;
  const _Path({required this.week, required this.held});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(colors: [Color(0xFF2A3F5E), Color(0xFF3B2A5E), Color(0xFF5E2A4A)]),
        ),
        child: Column(children: [
          Row(children: [
            Text('S1', style: K.body(10, color: K.muted, w: FontWeight.w800)),
            const Spacer(),
            Text('S13 🏁', style: K.body(10, color: K.muted, w: FontWeight.w800)),
          ]),
          const SizedBox(height: 4),
          LayoutBuilder(builder: (context, c) {
            const gap = 3.0;
            final w = (c.maxWidth - gap * 12) / 13;
            return SizedBox(
              height: 50,
              child: Stack(clipBehavior: Clip.none, children: [
                for (var i = 0; i < 13; i++)
                  Positioned(
                    left: i * (w + gap),
                    top: 34,
                    width: w,
                    height: 14,
                    child: Container(
                      decoration: BoxDecoration(
                        color: held[i] ? K.lime : (i == week ? K.bg : K.raised),
                        borderRadius: BorderRadius.circular(7),
                        border: i == week ? Border.all(color: K.gold, width: 2) : null,
                      ),
                    ),
                  ),
                Positioned(
                  left: week * (w + gap) + w / 2 - 15,
                  top: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: K.gold, width: 2),
                      image: DecorationImage(image: AssetImage(K.micky['face']!), fit: BoxFit.cover),
                    ),
                  ),
                ),
              ]),
            );
          }),
        ]),
      );
}

class _PillarRow extends StatelessWidget {
  final String icon, title;
  final int target;
  final List<int> values;
  final Color color;
  const _PillarRow({required this.icon, required this.title, required this.target, required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    final kept = values.where((v) => v == 1 || v == 2).length;
    const names = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('$icon $title', style: K.body(14, w: FontWeight.w800))),
          Text('$kept / $target', style: K.body(12, color: kept >= target ? K.gold : color, w: FontWeight.w900)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Column(children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: values[i] == 1 ? color : (values[i] == 2 ? Colors.transparent : (values[i] == 0 ? K.raised : Colors.transparent)),
                    border: values[i] == 2
                        ? Border.all(color: color, width: 2)
                        : (values[i] == -1 ? Border.all(color: K.line, width: 1) : null),
                  ),
                ),
                const SizedBox(height: 2),
                Text(names[i], style: K.body(9, color: K.dim)),
              ]),
            ),
        ]),
      ]),
    );
  }
}

/// Le bilan de la semaine : une fois par semaine, quand tu veux.
class WeekReviewScreen extends StatefulWidget {
  const WeekReviewScreen({super.key});

  @override
  State<WeekReviewScreen> createState() => _WeekReviewScreenState();
}

class _WeekReviewScreenState extends State<WeekReviewScreen> {
  late final _intent = TextEditingController(text: AppScope.read(context).settings.dirIntention);

  @override
  void dispose() {
    _intent.dispose();
    super.dispose();
  }

  Widget _stepper(String label, int v, ValueChanged<int> on) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(label, style: K.body(14))),
          IconButton(onPressed: v > 1 ? () => on(v - 1) : null, icon: const Icon(Icons.remove_circle_outline_rounded, color: K.muted)),
          Text('$v j / 7', style: K.body(14, w: FontWeight.w900)),
          IconButton(onPressed: v < 7 ? () => on(v + 1) : null, icon: const Icon(Icons.add_circle_outline_rounded, color: K.cyan)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.settings;
    final st = store.last7(store.pillarStart);
    final pr = store.last7(store.pillarPro);
    final suggestion = dirPlan[store.dirWeek().clamp(0, dirPlan.length - 1)];
    Widget line(String label, (int, int) r, int tgt) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(label, style: K.body(14))),
            Text('${r.$1} / ${r.$2}', style: K.body(14, color: r.$1 >= tgt ? K.lime : K.ink, w: FontWeight.w900)),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Bilan de la semaine')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            Text('Les 7 derniers jours', style: K.display(18)),
            const SizedBox(height: 6),
            Panel(
              child: Column(children: [
                line('⏰ Démarré avant ${_hm(s.startTarget)}', st, s.dirStartTgt),
                line('💼 Pro tenu (ou jour minimum)', pr, s.dirProTgt),
                for (final h in store.activeHabits) line('🌸 ${h.name}', store.last7((d) => store.pillarHabit(h, d)), s.dirHabTgt),
              ]),
            ),
            const SizedBox(height: 6),
            Text(
              pr.$1 >= s.dirProTgt ? 'Semaine tenue. Micky avance d\'une pierre.' : (pr.$1 * 2 >= s.dirProTgt ? 'Tenue à moitié : ça compte, Micky avance quand même.' : 'Semaine difficile. On ajuste, on ne juge pas.'),
              style: K.body(13, color: K.muted),
            ),
            const SizedBox(height: 16),
            Text('Tes cibles pour la semaine qui vient', style: K.display(16)),
            const SizedBox(height: 4),
            Text('Trop dur ? Baisse. Facile ? Monte d\'un cran, pas plus.', style: K.body(12, color: K.muted)),
            Panel(
              child: Column(children: [
                _stepper('⏰ Démarrer avant ${_hm(s.startTarget)}', s.dirStartTgt, (v) => setState(() => s.dirStartTgt = v)),
                _stepper('💼 Pro tenu', s.dirProTgt, (v) => setState(() => s.dirProTgt = v)),
                _stepper('🌸 Habitudes', s.dirHabTgt, (v) => setState(() => s.dirHabTgt = v)),
                Row(children: [
                  Expanded(child: Text('Jour minimum', style: K.body(14))),
                  for (final m in const [15, 30, 60])
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text('$m min'),
                        selected: s.dirMinPro == m,
                        onSelected: (_) => setState(() => s.dirMinPro = m),
                        selectedColor: K.lime,
                        labelStyle: K.body(12, color: s.dirMinPro == m ? K.bg : K.ink, w: FontWeight.w800),
                        backgroundColor: K.raised,
                        side: BorderSide.none,
                        showCheckmark: false,
                      ),
                    ),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            Text('Intention pro de la semaine (facultatif)', style: K.display(16)),
            const SizedBox(height: 6),
            TextField(controller: _intent, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'une ligne')),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => setState(() => _intent.text = suggestion),
              child: Text('Suggestion : $suggestion · toucher pour la prendre', style: K.body(12, color: K.cyan)),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'C\'est fait · +10 XP',
              color: _vio,
              onPressed: () async {
                s.dirIntention = _intent.text.trim();
                await store.finishReview();
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Creuser le pourquoi : un objectif, puis « et pourquoi c'est important ? », deux fois.
class DigWhyScreen extends StatefulWidget {
  const DigWhyScreen({super.key});

  @override
  State<DigWhyScreen> createState() => _DigWhyScreenState();
}

class _DigWhyScreenState extends State<DigWhyScreen> {
  final _c = [TextEditingController(), TextEditingController(), TextEditingController()];

  @override
  void dispose() {
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    const labels = ['Ce qui compte pour moi', 'Et pourquoi c\'est important ?', 'Et ça, pourquoi ?'];
    return Scaffold(
      appBar: AppBar(title: const Text('Creuser mes raisons')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            Text('Chaque réponse devient une carte « Mes raisons ». La plus profonde reviendra quand ce sera dur.', style: K.body(13, color: K.muted)),
            const SizedBox(height: 12),
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('↓', style: K.body(16, color: _vio)))),
              Text(labels[i], style: K.body(13, color: _vio, w: FontWeight.w800)),
              const SizedBox(height: 4),
              TextField(controller: _c[i], textCapitalization: TextCapitalization.sentences, maxLines: null, onChanged: (_) => setState(() {})),
            ],
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Garder mes raisons',
              color: _vio,
              onPressed: _c.every((c) => c.text.trim().isEmpty)
                  ? null
                  : () async {
                      for (final c in _c.reversed) {
                        final t = c.text.trim();
                        if (t.isNotEmpty && !store.settings.dirReasons.contains(t)) store.settings.dirReasons.insert(0, t);
                      }
                      await store.updateSettings();
                      if (context.mounted) Navigator.pop(context);
                    },
            ),
          ],
        ),
      ),
    );
  }
}

/// Heure de démarrage visée et temps pro habituel : un seul endroit pour les changer.
Future<void> editHourGoals(BuildContext context) async {
  final store = AppScope.read(context);
  final s = store.settings;
  await showModalBottomSheet(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mes heures', style: K.display(20)),
            const SizedBox(height: 12),
            Text('⏰ Je démarre avant', style: K.body(14, w: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final m in const [480, 510, 540, 570, 600, 630, 660, 690, 720])
                ChoiceChip(
                  label: Text('${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60}'}'),
                  selected: s.startTarget == m,
                  onSelected: (_) => setState(() => s.startTarget = m),
                  selectedColor: K.lime,
                  labelStyle: K.body(13, color: s.startTarget == m ? K.bg : K.ink, w: FontWeight.w800),
                  backgroundColor: K.raised,
                  side: BorderSide.none,
                  showCheckmark: false,
                ),
            ]),
            const SizedBox(height: 14),
            Text('💼 Mon temps pro habituel par jour', style: K.body(14, w: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final m in const [60, 90, 120, 150, 180, 210, 240, 300])
                ChoiceChip(
                  label: Text(_dur(m)),
                  selected: s.dirProDefault == m,
                  onSelected: (_) => setState(() => s.dirProDefault = m),
                  selectedColor: K.lime,
                  labelStyle: K.body(13, color: s.dirProDefault == m ? K.bg : K.ink, w: FontWeight.w800),
                  backgroundColor: K.raised,
                  side: BorderSide.none,
                  showCheckmark: false,
                ),
            ]),
            const SizedBox(height: 6),
            Text('Il préremplit le briefing et « Préparer demain ». Un jour différent ? Change-le juste ce jour-là.', style: K.body(11, color: K.muted)),
            const SizedBox(height: 14),
            PrimaryButton(label: 'OK', onPressed: () => Navigator.pop(ctx)),
          ]),
        ),
      ),
    ),
  );
  await store.updateSettings();
}
