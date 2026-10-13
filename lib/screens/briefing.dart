import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../notifications.dart';
import '../theme.dart';
import 'notebook.dart';
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
    _proGoal = p.proGoalMin;
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
        appBar: AppBar(title: const Text('Briefing du matin')),
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
            Text('Formule une action, pas un résultat : « envoyer 3 mails » plutôt que « avancer ». (Dr K)',
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
                Navigator.pop(context);
                if (first) openScreen(context, const MatrixScreen(standalone: true));
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
          for (final t in steps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () async {
                      await store.completeTask(t);
                      if (t.done && context.mounted) await askNext(context, 'Étape faite !');
                    },
                    icon: Icon(t.done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        color: t.done ? widget.color : K.muted),
                  ),
                  Expanded(child: Text(t.title, style: K.body(14))),
                  Pill('${t.estimateMin} min', color: K.cyan),
                  IconButton(
                    tooltip: 'Supprimer',
                    onPressed: () => store.removeTask(t),
                    icon: const Icon(Icons.close_rounded, color: K.dim, size: 20),
                  ),
                ],
              ),
            ),
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
