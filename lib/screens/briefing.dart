import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../notifications.dart';
import '../store.dart';
import '../theme.dart';
import 'block.dart';
import 'dump.dart';
import 'notebook.dart';
import 'problems.dart';
import 'task_panel.dart' show showTaskPanel;
import 'timetable.dart' show askText;
import 'today.dart' show TodayScreen;
import 'matrix.dart';

class BriefingScreen extends StatefulWidget {
  const BriefingScreen({super.key});

  @override
  State<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends State<BriefingScreen> {
  final _pro = TextEditingController();
  final _perso = TextEditingController();
  final _if = TextEditingController();
  final _then = TextEditingController();
  int _sleep = 0;
  int _proGoal = 0;
  final _persoGoal = TextEditingController();
  bool _init = false;
  static const _goalChoices = [60, 90, 120, 180, 240, 300, 360];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final p = AppScope.read(context).today;
    _pro.text = p.pro;
    _perso.text = p.perso;
    _if.text = p.planIf;
    _then.text = p.planThen;
    _sleep = p.sleepH;
    _proGoal = p.proGoalMin > 0 ? p.proGoalMin : AppScope.read(context).settings.dirProDefault;
    _persoGoal.text = p.persoGoal;
  }

  @override
  void dispose() {
    for (final c in [_pro, _perso, _if, _then, _persoGoal]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _fmt(int m) => m >= 60 ? '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60}'}' : '$m min';

  Future<void> _saveFields() async {
    final store = AppScope.read(context);
    final p = store.today;
    p.pro = _pro.text.trim();
    p.perso = _perso.text.trim();
    p.planIf = _if.text.trim();
    p.planThen = _then.text.trim();
    p.sleepH = _sleep;
    p.proGoalMin = _proGoal;
    p.persoGoal = _persoGoal.text.trim();
    await store.commit();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final now = DateTime.now();
    final phase = store.phaseOn(now);
    final deferred = store.deferredToday;

    return PopScope(
      onPopInvokedWithResult: (_, __) => _saveFields(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Briefing du jour')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            const MickySays('Bonjour ! On prépare la journée ? 2 minutes, promis.'),
            const SizedBox(height: 12),
            if (isTablet(context)) ...[
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: K.ink,
                    side: const BorderSide(color: K.cyan, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => openScreen(context, HandwritingPage(note: store.noteFor(store.todayKey, 'briefing'))),
                  icon: const Icon(Icons.draw_rounded, color: K.cyan),
                  label: Text('Écrire mon briefing à la main', style: K.body(15, w: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (phase != null) Pill('Cycle · jour ${store.cycleDay(now)} · $phase', color: K.pink),
                if (deferred.isNotEmpty)
                  Pill('${deferred.length} tâche${deferred.length > 1 ? 's' : ''} reportée${deferred.length > 1 ? 's' : ''} d\'hier',
                      color: const Color(0xFFFFB89A), fill: const Color(0xFF3A2238)),
              ],
            ),
            if (deferred.isNotEmpty) ...[
              const SizedBox(height: 8),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reportées d\'hier', style: K.display(15, color: K.coral)),
                    const SizedBox(height: 4),
                    for (final t in deferred) Text('· ${t.title}', style: K.body(14)),
                    const SizedBox(height: 4),
                    Text('Elles t\'attendent dans la matrice.', style: K.body(12, color: K.muted)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Sommeil cette nuit', style: K.body(14)),
                    const Spacer(),
                    Text(_sleep == 0 ? '—' : '${(_sleep / 2).toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ',')} h',
                        style: K.display(16, color: K.cyan)),
                  ]),
                  Slider(
                    value: _sleep.toDouble(),
                    min: 0,
                    max: 24,
                    divisions: 24,
                    onChanged: (v) => setState(() => _sleep = v.round()),
                  ),
                ],
              ),
            ),

            if (store.today.spawn.isNotEmpty) ...[
              const SizedBox(height: 10),
              Panel(
                border: K.gold,
                child: Text('Ton point de spawn, préparé hier soir : ${store.today.spawn}', style: K.body(14)),
              ),
            ],
            const SizedBox(height: 10),
            if (!store.today.briefingDone) ...[
              Panel(
                border: K.cyan,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.wb_sunny_rounded, color: K.cyan),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Démarrage guidé', style: K.display(16))),
                      Text('facultatif', style: K.body(11, color: K.muted)),
                    ]),
                    const SizedBox(height: 4),
                    Text('Se ranger la tête, réveiller le corps, puis ce briefing. La version mini compte autant.', style: K.body(12, color: K.muted)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: SecondaryButton(
                          label: '15 min',
                          onPressed: () async {
                            await openScreen(context, const DumpScreen(minutes: 5));
                            if (!context.mounted) return;
                            await openScreen(context, const ExerciseTimer());
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SecondaryButton(
                          label: 'Mini · 3 min',
                          onPressed: () async {
                            await openScreen(context, const DumpScreen(minutes: 1));
                            if (!context.mounted) return;
                            await openScreen(context, const SimpleTimer(title: 'Bouger 1 minute', minutes: 1, hint: 'Étire-toi, saute sur place, ouvre la fenêtre. Une minute.', what: 'démarrage'));
                          },
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SkinRow(),
            const _StartCard(),
            const SizedBox(height: 10),
            const _ProblemAsk(),
            const SectionLabel('1 · Tes objectifs du jour'),
            Panel(
              border: K.gold,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Temps pro', style: K.display(16)),
                    const Spacer(),
                    Text(_proGoal == 0 ? 'pas d\'objectif' : _fmt(_proGoal), style: K.display(16, color: K.gold)),
                  ]),
                  const SizedBox(height: 4),
                  Text('Ta moyenne des 7 derniers jours : ${_fmt(store.avgProMinutes(7).round())}',
                      style: K.body(12, color: K.muted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final m in _goalChoices)
                        ChoiceChip(
                          label: Text(_fmt(m)),
                          selected: _proGoal == m,
                          onSelected: (_) => setState(() => _proGoal = _proGoal == m ? 0 : m),
                          selectedColor: K.gold,
                          labelStyle: K.body(13, color: _proGoal == m ? K.bg : K.ink),
                          backgroundColor: K.raised,
                          side: BorderSide.none,
                          showCheckmark: false,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _persoGoal,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Objectif perso du jour',
                      hintText: 'aller courir, appeler maman, 20 min de rangement…',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Objectif pro atteint : médaille d\'argent (+60 XP). Perso fait : un ruban pour Micky et de la Sérénité. Les deux : or. Tout, habitudes comprises : la couronne.',
                    style: K.body(12, color: K.muted),
                  ),
                ],
              ),
            ),

            const SectionLabel('2 · Tes quêtes principales'),
            _field(_pro, 'PRO', 'Ce qui compte vraiment aujourd\'hui', K.lime),
            const SizedBox(height: 10),
            _field(_perso, 'PERSO', 'Pour toi, ta vie, ta maison', K.pink),
            const SizedBox(height: 6),
            Text('Formule une action, pas un résultat : « envoyer 3 mails » plutôt que « avancer ».',
                style: K.body(12, color: K.muted)),

            const SectionLabel('3 · Découpe en étapes et parie sur la durée'),
            StepsEditor(category: 'pro', color: K.lime, label: 'Étapes pro'),
            const SizedBox(height: 10),
            StepsEditor(category: 'perso', color: K.pink, label: 'Étapes perso'),

            const SectionLabel('4 · Ton plan B'),
            if (store.recentIfThen.isNotEmpty) ...[
              Text('Tes plans tirés de tes réflexions :', style: K.body(12, color: K.muted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in store.recentIfThen)
                    ActionChip(
                      backgroundColor: K.raised,
                      side: BorderSide.none,
                      label: Text('Si ${r.ifCue} → ${r.thenDo}', style: K.body(12)),
                      onPressed: () => setState(() {
                        _if.text = r.ifCue;
                        _then.text = r.thenDo;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Panel(
              child: Column(
                children: [
                  Row(children: [
                    SizedBox(width: 48, child: Text('Si', style: K.display(16, color: K.gold))),
                    Expanded(
                      child: TextField(
                        controller: _if,
                        decoration: const InputDecoration(hintText: 'je me retrouve sur mon téléphone'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    SizedBox(width: 48, child: Text('alors', style: K.display(16, color: K.gold))),
                    Expanded(
                      child: TextField(
                        controller: _then,
                        decoration: const InputDecoration(hintText: 'je relance 5 minutes de l\'étape en cours'),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: store.today.briefingDone ? 'Enregistrer' : 'Lancer la journée · +10 XP',
              onPressed: () async {
                final first = !store.today.briefingDone;
                await _saveFields();
                await store.finishBriefing();
                await rescheduleAll(store);
                if (!context.mounted) return;
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                if (first) openScreen(context, const TodayScreen(standalone: true));
                // le kannada se glisse pendant qu'on se prépare
                for (final h in store.activeHabits) {
                  if (store.habitLevel(h, store.todayKey) == 0 && h.name.toLowerCase().contains('kannada')) {
                    messenger.showSnackBar(SnackBar(
                      duration: const Duration(seconds: 6),
                      content: Text('${h.name} en te préparant ? ${h.mini.isNotEmpty ? h.mini : ''}'),
                    ));
                    break;
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: K.body(12, color: color, w: FontWeight.w900)),
          const SizedBox(height: 4),
          TextField(
            controller: c,
            textCapitalization: TextCapitalization.sentences,
            style: K.body(16),
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      );
}

/// Liste d'étapes d'une quête, avec ajout et durée pariée.
class StepsEditor extends StatefulWidget {
  final String category;
  final Color color;
  final String label;
  const StepsEditor({super.key, required this.category, required this.color, required this.label});

  @override
  State<StepsEditor> createState() => _StepsEditorState();
}

class _StepsEditorState extends State<StepsEditor> {
  final _ctrl = TextEditingController();
  int _min = 15;
  static const _choices = [5, 10, 15, 25, 40, 60, 90];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static String _fmtMin(int m) => m >= 60 ? '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60}'}' : '$m min';

  Future<void> _pickMinutes(BuildContext context, AppStore store, Task t) async {
    final v = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Durée de « ${t.title} »', style: K.display(18)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in const [5, 10, 15, 25, 30, 45, 60, 90, 120, 180])
                ActionChip(
                  label: Text(_fmtMin(m)),
                  onPressed: () => Navigator.pop(ctx, m),
                  backgroundColor: t.estimateMin == m ? K.cyan : K.raised,
                  labelStyle: K.body(13, color: t.estimateMin == m ? K.bg : K.ink, w: FontWeight.w800),
                  side: BorderSide.none,
                ),
            ]),
          ]),
        ),
      ),
    );
    if (v != null) await store.editTask(t, estimate: v);
  }

  Future<void> _add() async {
    final title = _ctrl.text.trim();
    if (title.isEmpty) return;
    await AppScope.read(context).addTask(title, category: widget.category, estimate: _min, quad: Quad.doNow);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final steps = store.questSteps(widget.category);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: K.display(15, color: widget.color)),
          const SizedBox(height: 6),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: (a, b) => store.reorderSteps(widget.category, a, b > a ? b - 1 : b),
            children: [
              for (var i = 0; i < steps.length; i++)
                ReorderableDelayedDragStartListener(
                  key: ValueKey(steps[i].id),
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () async {
                            await store.completeTask(steps[i]);
                            if (steps[i].done && context.mounted) await askNext(context, 'Étape faite !');
                          },
                          icon: Icon(steps[i].done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                              color: steps[i].done ? widget.color : K.muted),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => showTaskPanel(context, steps[i]),
                            child: Text(steps[i].title, style: K.body(14)),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => _pickMinutes(context, store, steps[i]),
                          child: Pill(steps[i].estimateMin > 0 ? _fmtMin(steps[i].estimateMin) : 'durée ?', color: steps[i].estimateMin > 0 ? K.cyan : K.gold),
                        ),
                        IconButton(
                          tooltip: 'Supprimer',
                          onPressed: () => store.removeTask(steps[i]),
                          icon: const Icon(Icons.close_rounded, color: K.dim, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (steps.length > 1) Text('Appui long sur une étape pour changer l\'ordre · touche la durée pour la changer · touche le titre pour le panneau.', style: K.body(11, color: K.dim)),
          if (steps.isEmpty)
            Text('Commence par la toute première action concrète.', style: K.body(13, color: K.muted)),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _add(),
            decoration: InputDecoration(
              hintText: 'Nouvelle étape',
              suffixIcon: IconButton(onPressed: _add, icon: Icon(Icons.add_circle_rounded, color: widget.color)),
            ),
          ),
          const SizedBox(height: 8),
          Text('Ton pari de durée', style: K.body(12, color: K.muted)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in _choices)
                ChoiceChip(
                  label: Text('$m min'),
                  selected: _min == m,
                  onSelected: (_) => setState(() => _min = m),
                  selectedColor: widget.color,
                  labelStyle: K.body(13, color: _min == m ? K.bg : K.ink),
                  backgroundColor: K.raised,
                  side: BorderSide.none,
                  showCheckmark: false,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Peau du jour : un tap de 0 (nette) à 4 (poussée), zones en option.
class SkinRow extends StatelessWidget {
  const SkinRow({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = store.today;
    const colors = [K.lime, Color(0xFFC9E86A), K.gold, K.coral, Color(0xFFE0605A)];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Peau aujourd\'hui', style: K.body(14)),
            const Spacer(),
            Text(p.skin < 0 ? '—' : DayPlan.skinLabels[p.skin], style: K.body(13, color: p.skin < 0 ? K.muted : colors[p.skin], w: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            for (var i = 0; i < 5; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 4 ? 6 : 0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      p.skin = p.skin == i ? -1 : i;
                      await store.commit();
                    },
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.skin == i ? colors[i] : K.raised,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$i', style: K.body(14, color: p.skin == i ? K.bg : K.muted, w: FontWeight.w900)),
                    ),
                  ),
                ),
              ),
          ]),
          if (p.skin >= 1) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final z in ['menton', 'mâchoire', 'joues', 'front', 'nez', 'dos'])
                FilterChip(
                  label: Text(z),
                  selected: p.skinZones.split(',').contains(z),
                  onSelected: (_) async {
                    final set = p.skinZones.split(',').where((x) => x.isNotEmpty).toSet();
                    if (!set.remove(z)) set.add(z);
                    p.skinZones = set.join(',');
                    await store.commit();
                  },
                  selectedColor: colors[p.skin],
                  backgroundColor: K.raised,
                  labelStyle: K.body(12, color: p.skinZones.split(',').contains(z) ? K.bg : K.ink),
                  side: BorderSide.none,
                  showCheckmark: false,
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

String _hm(int m) => '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')}';

/// Commencer plus tôt : heure visée, bonus du matin, où tu en es.
class _StartCard extends StatelessWidget {
  const _StartCard();

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final target = store.settings.startTarget;
    final med = store.medianStart();
    final st = store.workStart(store.todayKey);
    final morning = store.morningProMinutes(store.todayKey).round();
    final opts = <int>{540, 570, 600, 630, 660, target}.toList()..sort();
    return Panel(
      border: K.lime,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.flag_rounded, color: K.lime),
          const SizedBox(width: 8),
          Expanded(child: Text('Commencer avant ${_hm(target)}', style: K.display(16))),
        ]),
        const SizedBox(height: 4),
        Text(
          st != null
              ? 'Démarré à ${_hm(st.hour * 60 + st.minute)}${st.hour * 60 + st.minute <= target ? ' : à l\'heure, +20 XP' : ''} · $morning min de pro avant midi'
              : 'Premier pro avant ${_hm(target)} : +20 XP. Avant midi : +10 XP dès 30 min de pro, +20 XP de plus à 90 min.',
          style: K.body(12, color: K.muted),
        ),
        if (med != null) ...[
          const SizedBox(height: 4),
          Text(
            'Ces deux dernières semaines, tu commences vers ${_hm(med)}.${med > target + 45 ? ' Vise d\'abord ${_hm(((med - 30) ~/ 15) * 15)} : un pas à la fois.' : ''}',
            style: K.body(12, color: K.ink),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          for (final m in opts)
            ChoiceChip(
              label: Text(_hm(m)),
              selected: m == target,
              onSelected: (_) async {
                store.settings.startTarget = m;
                await store.updateSettings();
              },
              selectedColor: K.lime,
              labelStyle: K.body(12, w: FontWeight.w800, color: m == target ? K.bg : K.ink),
              backgroundColor: K.raised,
              side: BorderSide.none,
              showCheckmark: false,
            ),
        ]),
      ]),
    );
  }
}

/// « Un problème en tête ? » : ouvre la fiche problème.
class _ProblemAsk extends StatelessWidget {
  const _ProblemAsk();

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final open = store.openProblems;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Un problème en tête ce matin ?', style: K.display(16)),
        const SizedBox(height: 4),
        Text('Le poser, c\'est déjà le sortir de la tête. On le résout ou on le traverse, et on suit son évolution.', style: K.body(12, color: K.muted)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          ActionChip(
            label: const Text('Oui, le noter'),
            onPressed: () async {
              final t = await askText(context, 'Le problème, concrètement', hint: 'un fait, pas un jugement sur toi');
              if (t == null || t.trim().isEmpty) return;
              final p = await store.addProblem(t.trim());
              if (context.mounted) openScreen(context, ProblemScreen(problem: p, guided: true));
            },
            backgroundColor: K.lime,
            labelStyle: K.body(12, color: K.bg, w: FontWeight.w800),
            side: BorderSide.none,
          ),
          for (final p in open.take(3))
            ActionChip(
              label: Text(p.title.length > 24 ? '${p.title.substring(0, 24)}…' : p.title),
              onPressed: () => openScreen(context, ProblemScreen(problem: p)),
              backgroundColor: K.raised,
              labelStyle: K.body(12, w: FontWeight.w800),
              side: BorderSide.none,
            ),
        ]),
      ]),
    );
  }
}
