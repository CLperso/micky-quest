import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'reflect.dart';
import 'session.dart';
import 'timetable.dart';

/// « Je bloque » : coups de pouce pour relancer, pour relancer,
/// et le même bloc « plus tard » que « pas tout de suite ».
class BlockScreen extends StatefulWidget {
  final Task? task;
  const BlockScreen({super.key, this.task});

  @override
  State<BlockScreen> createState() => _BlockScreenState();
}

class _BlockScreenState extends State<BlockScreen> {
  static const _drK = [
    (
      'Pas besoin d\'être prête',
      'Avancer vers un objectif coûte avant de rapporter. Tu peux agir sans te sentir prête : l\'action d\'abord, le ressenti se traite à côté.'
    ),
    (
      '« Demain » est une pensée, pas un plan',
      'Ton mental propose « je le ferai demain ». Ce n\'est pas toi qui décides, c\'est une pensée qui passe. Tu peux la regarder sans la suivre.'
    ),
    (
      'Qu\'est-ce que j\'évite de ressentir ?',
      'La procrastination est une solution efficace : elle enlève une émotion désagréable. Nomme-la (ennui, peur de rater, honte, flou) et elle perd de la force.'
    ),
    (
      'Reste dans le conflit',
      'La volonté, c\'est surveiller un conflit jusqu\'à l\'action. Pas besoin d\'être calme avant : « je me fiche de ce que mon cerveau veut », et on y va.'
    ),
    (
      'Décris la tâche sans la gonfler',
      'Ni « c\'est une thèse », ni « c\'est rien ». C\'est quoi, exactement, pendant 15 minutes ?'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final t = widget.task;
    return Scaffold(
      appBar: AppBar(title: const Text('Je bloque')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            MickySays(
              t == null
                  ? 'Ça arrive à tout le monde. On ne force pas : on relance la machine, doucement.'
                  : 'Bloquée sur « ${t.title} » ? On ne force pas : on relance la machine, doucement.',
              pose: 'belly',
              ring: K.coral,
            ),

            const SectionLabel('Jusqu\'où je PEUX aller ?'),
            Text(
              'Pas « ce que je devrais », mais le maximum honnête avant de décrocher. Plus efficace que « juste commence 5 minutes ».',
              style: K.body(13, color: K.muted),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _goBtn(context, '1 étape', '10 min', 10)),
              const SizedBox(width: 6),
              Expanded(child: _goBtn(context, 'Un bloc', '25 min', 25)),
              const SizedBox(width: 6),
              Expanded(child: _goBtn(context, 'À fond', '60 min', 60)),
            ]),

            const SectionLabel('Relancer la machine'),
            _tool(
              context,
              Icons.fitness_center_rounded,
              'Relancer la machine · 5 min',
              '40 s d\'effort, 20 s de pause : squats, jumping jacks, montées de genoux…',
              K.coral,
              () => _run(context, const ExerciseTimer()),
            ),
            _tool(
              context,
              Icons.door_front_door_rounded,
              'L\'effet porte · 5 min',
              'Franchis deux portes, fais le tour du pâté de maisons, reviens. Ça redémarre la mémoire de travail.',
              K.gold,
              () => _run(context, const SimpleTimer(title: 'L\'effet porte', minutes: 5, hint: 'Lève-toi, passe deux portes, marche. Reviens quand ça sonne.', what: 'porte')),
            ),
            _tool(
              context,
              Icons.air_rounded,
              'Respiration alternée · 2 min',
              'Nadi shuddhi : une narine, puis l\'autre. Pour réguler avant d\'agir, pas pour attendre d\'être calme.',
              K.cyan,
              () => _run(context, const BreathTimer()),
            ),
            _tool(
              context,
              Icons.directions_walk_rounded,
              'Marche sans téléphone · 10 min',
              'Ennuie-toi volontairement : c\'est ta résistance à l\'ennui qui résiste aux écrans.',
              K.lime,
              () => _run(context, const SimpleTimer(title: 'Marche sans téléphone', minutes: 10, hint: 'Téléphone dans la poche ou à la maison. Rien à faire, juste marcher.', what: 'marche')),
            ),
            _tool(
              context,
              Icons.hourglass_bottom_rounded,
              'Minuteur de procrastination · 20 min',
              'Tu vas procrastiner ? OK, mais chronométré. À la fin : est-ce que ça valait le coup ?',
              K.pink,
              () => _run(context, const ProcrastinationTimer()),
            ),

            const SectionLabel('Petites vérités utiles'),
            for (final d in _drK)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.$1, style: K.display(15, color: K.gold)),
                      const SizedBox(height: 4),
                      Text(d.$2, style: K.body(13, color: K.muted)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 4),
            SecondaryButton(
              label: 'Regarder ce qui coince',
              onPressed: () => openScreen(context, ReflectionScreen(kind: 'pasfaite', taskId: t?.id ?? '', title: t?.title ?? '')),
            ),

            if (t != null) ...[
              const SectionLabel('Plus tard'),
              PostponeBlock(
                task: t,
                ts: t.plannedAt > 0 ? t.plannedAt : DateTime.now().millisecondsSinceEpoch,
                onDone: () => Navigator.pop(context),
                hideBlock: true,
              ),
            ] else if (store.openTasks.isNotEmpty) ...[
              const SectionLabel('Plus tard'),
              Text('Choisis la tâche à replanifier :', style: K.body(13, color: K.muted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final x in store.openTasks.take(8))
                    ActionChip(
                      label: Text(x.title, style: K.body(12)),
                      backgroundColor: K.raised,
                      side: BorderSide.none,
                      onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BlockScreen(task: x))),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _run(BuildContext context, Widget timer) async {
    await openScreen(context, timer);
  }

  Widget _goBtn(BuildContext context, String label, String sub, int minutes) => SizedBox(
        height: 64,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: K.card,
            side: const BorderSide(color: K.lime, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: EdgeInsets.zero,
          ),
          onPressed: () async {
            final store = AppScope.read(context);
            final t = widget.task;
            if (store.runningSession != null) {
              openScreen(context, const SessionScreen());
              return;
            }
            final ok = await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              builder: (_) => AppScope(store: store, child: StartSessionSheet(preselect: t?.id, minutes: minutes)),
            );
            if (ok == true && context.mounted) {
              Navigator.pop(context);
              final ctx = navKey.currentContext;
              if (ctx != null) openScreen(ctx, const SessionScreen());
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: K.display(15, color: K.lime)),
              Text(sub, style: K.body(11, color: K.muted)),
            ],
          ),
        ),
      );

  Widget _tool(BuildContext context, IconData icon, String title, String sub, Color c, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: K.card,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: K.line, width: 2)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: c, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: K.body(15, w: FontWeight.w800)),
                        Text(sub, style: K.body(12, color: K.muted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.play_circle_rounded, color: K.muted),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Grand chrono rond réutilisé par les coups de pouce.
class _Clock extends StatelessWidget {
  final double frac;
  final String big;
  final String small;
  final Color color;
  const _Clock({required this.frac, required this.big, required this.small, required this.color});

  @override
  Widget build(BuildContext context) => Center(
        child: SizedBox(
          width: 240,
          height: 240,
          child: CustomPaint(
            painter: _Arc(frac.clamp(0.0, 1.0), color),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(big, style: K.display(48, w: FontWeight.w700)),
                  Text(small, style: K.body(14, color: K.muted), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
}

class _Arc extends CustomPainter {
  final double value;
  final Color color;
  _Arc(this.value, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 12;
    canvas.drawCircle(c, r, Paint()..color = K.raised..style = PaintingStyle.stroke..strokeWidth = 16);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi / 2, 2 * pi * value, false,
        Paint()..color = color..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeWidth = 16);
  }

  @override
  bool shouldRepaint(covariant _Arc old) => old.value != value || old.color != color;
}

String _mmss(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

/// 5 minutes : 40 s d'effort, 20 s de pause, exercices qui tournent.
class ExerciseTimer extends StatefulWidget {
  const ExerciseTimer({super.key});
  @override
  State<ExerciseTimer> createState() => _ExerciseTimerState();
}

class _ExerciseTimerState extends State<ExerciseTimer> {
  static const _moves = ['Squats', 'Jumping jacks', 'Montées de genoux', 'Fentes', 'Gainage', 'Pompes contre le mur', 'Talons-fesses', 'Sauts sur place'];
  static const total = 300;
  int _elapsed = 0;
  Timer? _t;
  bool _running = false;
  bool _done = false;

  void _start() {
    _running = true;
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed++;
        final inRound = _elapsed % 60;
        if (inRound == 0 || inRound == 40) HapticFeedback.heavyImpact();
        if (_elapsed >= total) {
          _t?.cancel();
          _running = false;
          _done = true;
          AppScope.read(context).noteSerenity('exercice 5 min');
        }
      });
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final round = _elapsed ~/ 60;
    final inRound = _elapsed % 60;
    final effort = inRound < 40;
    final left = effort ? 40 - inRound : 60 - inRound;
    final move = _moves[round % _moves.length];
    return Scaffold(
      appBar: AppBar(title: const Text('Relancer la machine')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            Text(_done ? 'C\'est fait !' : effort ? 'EFFORT' : 'PAUSE', style: K.body(13, color: effort ? K.coral : K.cyan, w: FontWeight.w900)),
            Text(_done ? 'Le corps est relancé. Et maintenant, une étape ?' : move, style: K.display(28)),
            const SizedBox(height: 20),
            _Clock(
              frac: _elapsed / total,
              big: _done ? '5:00' : '$left',
              small: _done ? 'minutes' : 'série ${round + 1} / 5 · ${_mmss(total - _elapsed)} restantes',
              color: effort ? K.coral : K.cyan,
            ),
            const SizedBox(height: 20),
            Panel(
              child: Text(
                'Un changement de contexte (bouger, sortir d\'une pièce) libère la mémoire de travail coincée dans le conflit « je devrais / j\'ai envie ».',
                style: K.body(13, color: K.muted),
              ),
            ),
            const SizedBox(height: 20),
            if (!_running && !_done) PrimaryButton(label: 'C\'est parti', color: K.coral, onPressed: () => setState(_start)),
            if (_running) SecondaryButton(label: 'Arrêter', onPressed: () => Navigator.pop(context)),
            if (_done) PrimaryButton(label: 'Je lance une étape', onPressed: () {
              Navigator.pop(context);
              final ctx = navKey.currentContext;
              if (ctx != null) startFocus(ctx);
            }),
          ],
        ),
      ),
    );
  }
}

/// Chrono simple (porte, marche).
class SimpleTimer extends StatefulWidget {
  final String title;
  final int minutes;
  final String hint;
  final String what;
  const SimpleTimer({super.key, required this.title, required this.minutes, required this.hint, required this.what});
  @override
  State<SimpleTimer> createState() => _SimpleTimerState();
}

class _SimpleTimerState extends State<SimpleTimer> {
  int _elapsed = 0;
  Timer? _t;
  bool _running = false;
  bool _done = false;

  void _start() {
    _running = true;
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed++;
        if (_elapsed >= widget.minutes * 60) {
          _t?.cancel();
          _running = false;
          _done = true;
          HapticFeedback.heavyImpact();
          AppScope.read(context).noteSerenity(widget.what);
        }
      });
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.minutes * 60;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            Text(widget.hint, style: K.body(14, color: K.muted)),
            const SizedBox(height: 20),
            _Clock(frac: _elapsed / total, big: _mmss(max(0, total - _elapsed)), small: _done ? 'c\'est bon, reviens' : 'restantes', color: K.gold),
            const SizedBox(height: 24),
            if (!_running && !_done) PrimaryButton(label: 'C\'est parti', color: K.gold, onPressed: () => setState(_start)),
            if (_running) SecondaryButton(label: 'Arrêter', onPressed: () => Navigator.pop(context)),
            if (_done) PrimaryButton(label: 'Je suis de retour', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}

/// Respiration alternée guidée : 4 s inspire gauche, 4 s expire droite, 4 s inspire droite, 4 s expire gauche.
class BreathTimer extends StatefulWidget {
  const BreathTimer({super.key});
  @override
  State<BreathTimer> createState() => _BreathTimerState();
}

class _BreathTimerState extends State<BreathTimer> {
  static const total = 120;
  static const _steps = ['Inspire · narine gauche', 'Expire · narine droite', 'Inspire · narine droite', 'Expire · narine gauche'];
  int _elapsed = 0;
  Timer? _t;
  bool _running = false;
  bool _done = false;

  void _start() {
    _running = true;
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed++;
        if (_elapsed % 4 == 0) HapticFeedback.lightImpact();
        if (_elapsed >= total) {
          _t?.cancel();
          _running = false;
          _done = true;
          AppScope.read(context).noteSerenity('respiration');
        }
      });
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = (_elapsed ~/ 4) % 4;
    final inStep = _elapsed % 4;
    final inhale = step.isEven;
    return Scaffold(
      appBar: AppBar(title: const Text('Respiration alternée')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            Text('Pouce sur une narine, annulaire sur l\'autre. Suis le cercle.', style: K.body(14, color: K.muted)),
            const SizedBox(height: 20),
            Center(
              child: AnimatedContainer(
                duration: const Duration(seconds: 1),
                width: _running ? (inhale ? 120 + inStep * 30.0 : 240 - inStep * 30.0) : 160,
                height: _running ? (inhale ? 120 + inStep * 30.0 : 240 - inStep * 30.0) : 160,
                decoration: BoxDecoration(shape: BoxShape.circle, color: K.cyan.withValues(alpha: 0.25), border: Border.all(color: K.cyan, width: 4)),
                child: Center(
                  child: Text(_done ? 'Fini' : _running ? '${4 - inStep}' : '2 min', style: K.display(40, w: FontWeight.w700)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(child: Text(_done ? 'Tu peux agir maintenant, même sans être calme.' : _running ? _steps[step] : 'Prête ?', style: K.display(18, color: K.cyan))),
            const SizedBox(height: 6),
            Center(child: Text(_mmss(max(0, total - _elapsed)), style: K.body(13, color: K.muted))),
            const SizedBox(height: 24),
            if (!_running && !_done) PrimaryButton(label: 'C\'est parti', color: K.cyan, onPressed: () => setState(_start)),
            if (_running) SecondaryButton(label: 'Arrêter', onPressed: () => Navigator.pop(context)),
            if (_done) PrimaryButton(label: 'Je lance une étape', onPressed: () {
              Navigator.pop(context);
              final ctx = navKey.currentContext;
              if (ctx != null) startFocus(ctx);
            }),
          ],
        ),
      ),
    );
  }
}

/// 20 minutes de procrastination assumée, puis « ça valait le coup ? ».
class ProcrastinationTimer extends StatefulWidget {
  const ProcrastinationTimer({super.key});
  @override
  State<ProcrastinationTimer> createState() => _ProcrastinationTimerState();
}

class _ProcrastinationTimerState extends State<ProcrastinationTimer> {
  static const total = 20 * 60;
  int _elapsed = 0;
  Timer? _t;
  bool _running = false;
  bool _done = false;

  void _start() {
    _running = true;
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed++;
        if (_elapsed >= total) {
          _t?.cancel();
          _running = false;
          _done = true;
          HapticFeedback.heavyImpact();
        }
      });
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _answer(bool worth) async {
    final store = AppScope.read(context);
    await store.addLog(LogEntry(
      ts: DateTime.now().millisecondsSinceEpoch,
      kind: LogKind.free,
      note: 'Procrastination chronométrée ${(_elapsed / 60).round()} min · ${worth ? 'ça valait le coup' : 'ça ne valait pas le coup'}',
    ));
    await store.noteSerenity('procrastination chronométrée');
    if (!mounted) return;
    Navigator.pop(context);
    final ctx = navKey.currentContext;
    if (ctx != null) await askNext(ctx, worth ? 'Pause finie.' : 'OK, noté.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Procrastination chronométrée')),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
            children: [
              Text('Tu vas scroller, regarder une vidéo ? OK. Mais avec un minuteur, et on en reparle après.', style: K.body(14, color: K.muted)),
              const SizedBox(height: 20),
              _Clock(frac: _elapsed / total, big: _mmss(max(0, total - _elapsed)), small: _done ? 'les 20 min sont passées' : 'restantes', color: K.pink),
              const SizedBox(height: 24),
              if (!_running && !_done) PrimaryButton(label: 'Lancer les 20 min', color: K.pink, onPressed: () => setState(_start)),
              if (_running) SecondaryButton(label: 'J\'arrête avant', onPressed: () => setState(() {
                    _t?.cancel();
                    _running = false;
                    _done = true;
                  })),
              if (_done) ...[
                Text('Est-ce que ça valait le coup ?', style: K.display(18)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: SecondaryButton(label: 'Pas vraiment', onPressed: () => _answer(false))),
                  const SizedBox(width: 10),
                  Expanded(child: PrimaryButton(label: 'Oui', color: K.pink, onPressed: () => _answer(true))),
                ]),
              ],
            ],
          ),
        ),
      );
}
