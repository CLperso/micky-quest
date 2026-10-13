import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../notifications.dart';
import '../theme.dart';
import 'reflect.dart';

/// Choix de la tâche et du pari de durée.
class StartSessionSheet extends StatefulWidget {
  final String? preselect;
  const StartSessionSheet({super.key, this.preselect});

  @override
  State<StartSessionSheet> createState() => _StartSessionSheetState();
}

class _StartSessionSheetState extends State<StartSessionSheet> {
  String? _taskId;
  final _free = TextEditingController();
  int _min = 25;
  String _cat = '';
  bool _silent = true;
  static const _choices = [5, 10, 15, 20, 25, 30, 45, 60, 90, 120, 180, 240];

  @override
  void initState() {
    super.initState();
    _taskId = widget.preselect;
  }

  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.read(context);
    final t = _taskId == null ? null : store.taskById(_taskId!);
    if (t != null && t.estimateMin > 0) _min = t.estimateMin;
    if (!_init) {
      _init = true;
      _silent = !store.settings.checkinsDuringSession;
      if (t != null && t.category.isNotEmpty) _cat = t.category;
    }
  }

  @override
  void dispose() {
    _free.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final open = store.openTasks;
    // quêtes et « Faire maintenant » d'abord
    open.sort((a, b) {
      int rank(Task t) => t.category.isNotEmpty ? 0 : (t.quad == Quad.doNow ? 1 : (t.quad == Quad.plan ? 2 : 3));
      return rank(a).compareTo(rank(b));
    });
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            children: [
              Text('Nouvelle session', style: K.display(22)),
              const SizedBox(height: 4),
              Text('Sur quoi tu pars ?', style: K.body(14, color: K.muted)),
              const SizedBox(height: 8),
              for (final t in open.take(12))
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() {
                    _taskId = t.id;
                    if (t.estimateMin > 0) _min = t.estimateMin;
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _taskId == t.id ? K.raised : K.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _taskId == t.id ? K.lime : K.line, width: 2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: K.quadColors[t.quad], shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(t.title, style: K.body(14))),
                        if (t.category.isNotEmpty) Pill(t.category.toUpperCase(), color: t.category == 'pro' ? K.lime : K.pink),
                      ],
                    ),
                  ),
                ),
              TextField(
                controller: _free,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() => _taskId = null),
                decoration: const InputDecoration(hintText: 'Ou autre chose… (tatoueur, transport, ménage)'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in [...Act.presets[Act.perso]!, ...Act.presets[Act.pro]!])
                    ActionChip(
                      label: Text(p, style: K.body(12)),
                      backgroundColor: K.raised,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() {
                        _free.text = p;
                        _taskId = null;
                        _cat = Act.presets[Act.perso]!.contains(p) ? Act.perso : Act.pro;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Compter en', style: K.body(13, color: K.muted)),
                  const SizedBox(width: 8),
                  for (final c in [Act.pro, Act.perso])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(c == Act.pro ? 'Pro' : 'Perso'),
                        selected: _cat == c,
                        onSelected: (_) => setState(() => _cat = _cat == c ? '' : c),
                        selectedColor: c == Act.pro ? K.lime : K.pink,
                        labelStyle: K.body(13, color: _cat == c ? K.bg : K.ink),
                        backgroundColor: K.raised,
                        side: BorderSide.none,
                        showCheckmark: false,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Ton pari : ${_min >= 60 ? '${_min ~/ 60} h${_min % 60 == 0 ? '' : ' ${_min % 60}'}' : '$_min min'}',
                  style: K.display(18, color: K.cyan)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final m in _choices)
                    ChoiceChip(
                      label: Text('$m'),
                      selected: _min == m,
                      onSelected: (_) => setState(() => _min = m),
                      selectedColor: K.cyan,
                      labelStyle: K.body(14, color: _min == m ? K.bg : K.ink),
                      backgroundColor: K.raised,
                      side: BorderSide.none,
                      showCheckmark: false,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Finis entre ${(_min * 0.8).round()} et ${(_min * 1.2).round()} min pour gagner un coffre.',
                  style: K.body(13, color: K.muted)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Pas de check-in pendant la session', style: K.body(14)),
                subtitle: Text('Le temps est compté d\'un bloc sur cette activité.', style: K.body(12, color: K.muted)),
                value: _silent,
                onChanged: (v) => setState(() => _silent = v),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: 'Je parie $_min min',
                onPressed: (_taskId == null && _free.text.trim().isEmpty)
                    ? null
                    : () async {
                        final id = _taskId ?? '';
                        final title = id.isEmpty ? _free.text.trim() : (store.taskById(id)?.title ?? '');
                        await store.startSession(id, title, _min, category: _cat, silent: _silent);
                        if (context.mounted) Navigator.pop(context, true);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _end(bool finished) async {
    final store = AppScope.read(context);
    final s = store.runningSession;
    if (s == null) return;
    final perso = store.sessionCategory(s) == Act.perso;
    final chest = await store.endSession(s, finished: finished);
    if (perso) {
      if (finished && s.taskId.isNotEmpty) {
        final t = store.taskById(s.taskId);
        if (t != null && !t.done) await store.completeTask(t);
      }
      await rescheduleAll(store);
      await showNextQuestion(context: '${s.title} : ${s.actualMin.round()} min.');
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }
    if (finished && s.taskId.isNotEmpty) {
      final t = store.taskById(s.taskId);
      if (t != null && !t.done) await store.completeTask(t);
    }
    await rescheduleAll(store);
    await showNextQuestion(context: finished ? 'Étape finie !' : '');
    if (!mounted) return;
    if (chest.isNotEmpty) await showChest(context, chest);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AppScope(store: store, child: RateSheet(session: s)),
    );
    if (!mounted) return;
    Navigator.pop(context);
    if (!finished) openScreen(context, ReflectionScreen(kind: 'decroche', taskId: s.taskId, title: s.title));
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.runningSession;
    if (s == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Aucune session en cours', style: K.body(16, color: K.muted))),
      );
    }
    final t = store.taskById(s.taskId);
    final elapsed = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(s.start));
    final frac = elapsed.inSeconds / (s.predictedMin * 60);
    final over = frac > 1;
    final mm = elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final inWindow = frac >= 0.8 && frac <= 1.2;
    final perso = store.sessionCategory(s) == Act.perso;

    if (perso) {
      return Scaffold(
        appBar: AppBar(
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(child: Pill(s.silent ? 'Check-ins en pause' : 'Check-ins actifs', color: K.pink)),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            children: [
              Text('PERSO', style: K.body(12, color: K.pink, w: FontWeight.w900)),
              Text(s.title, style: K.display(24)),
              Text('Commencé à ${hm(DateTime.fromMillisecondsSinceEpoch(s.start))} · prévu ${s.predictedMin >= 60 ? '${s.predictedMin ~/ 60} h${s.predictedMin % 60 == 0 ? '' : ' ${s.predictedMin % 60}'}' : '${s.predictedMin} min'}',
                  style: K.body(13, color: K.muted)),
              const SizedBox(height: 28),
              Center(
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: CustomPaint(
                    painter: _Ring(min(1.0, frac), K.pink, 0),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(elapsed.inHours > 0 ? '${elapsed.inHours}:${(elapsed.inMinutes % 60).toString().padLeft(2, '0')}:$ss' : '$mm:$ss',
                              style: K.display(48, w: FontWeight.w700)),
                          Text('temps perso', style: K.body(14, color: K.muted)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Panel(
                child: Text(
                  'Pas de pari, pas de coffre : ce temps est pour toi. Il sera compté en Perso dans ton replay.',
                  style: K.body(13, color: K.muted),
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(label: 'Terminé', color: K.pink, onPressed: () => _end(true)),
              const SizedBox(height: 10),
              SecondaryButton(label: 'Arrêter sans finir', onPressed: () => _end(false)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Pill(s.silent ? 'Check-ins en pause' : 'Check-ins actifs'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          children: [
            if (t != null && t.category.isNotEmpty)
              Text('QUÊTE ${t.category.toUpperCase()}', style: K.body(12, color: t.category == 'pro' ? K.lime : K.pink, w: FontWeight.w900)),
            if (t != null && t.isBoss)
              Text('COMBAT CONTRE LE BOSS · ${t.bossHp} PV', style: K.body(12, color: K.coral, w: FontWeight.w900)),
            Text(s.title, style: K.display(24)),
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                width: 260,
                height: 260,
                child: CustomPaint(
                  painter: _Ring(min(1.0, frac), over ? K.coral : (inWindow ? K.gold : K.lime), over ? frac - 1 : 0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$mm:$ss', style: K.display(52, w: FontWeight.w700)),
                        Text('ton pari : ${s.predictedMin} min', style: K.body(14, color: K.muted)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Panel(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(K.micky['bed']!, width: 64, height: 64, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Micky travaille avec toi', style: K.body(14, w: FontWeight.w800)),
                        Text(over ? 'Le pari est dépassé, ce n\'est pas grave : on note et on apprend.' : 'Elle reste là tant que la session tourne.',
                            style: K.body(13, color: K.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Panel(
              border: K.gold,
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, color: K.gold, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      inWindow
                          ? 'Tu es dans la zone du coffre : c\'est le moment de finir !'
                          : 'Finis entre ${(s.predictedMin * 0.8).round()} et ${(s.predictedMin * 1.2).round()} min et tu gagnes un coffre.',
                      style: K.body(13),
                    ),
                  ),
                ],
              ),
            ),
            if (store.today.planThen.isNotEmpty) ...[
              const SizedBox(height: 10),
              Panel(
                child: Text('Ton plan B : si ${store.today.planIf}, alors ${store.today.planThen}.', style: K.body(13, color: K.muted)),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: SecondaryButton(label: 'J\'ai décroché', onPressed: () => _end(false))),
                const SizedBox(width: 10),
                Expanded(child: PrimaryButton(label: 'Étape finie', onPressed: () => _end(true))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Ring extends CustomPainter {
  final double value;
  final Color color;
  final double overflow;
  _Ring(this.value, this.color, this.overflow);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 12;
    final bg = Paint()
      ..color = K.raised
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;
    canvas.drawCircle(c, r, bg);
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 18;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi / 2, 2 * pi * value, false, fg);
    if (overflow > 0) {
      final o = Paint()
        ..color = K.coral.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 8;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r - 22), -pi / 2, 2 * pi * min(1.0, overflow), false, o);
    }
  }

  @override
  bool shouldRepaint(covariant _Ring old) => old.value != value || old.color != color || old.overflow != overflow;
}
