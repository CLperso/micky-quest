import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'timetable.dart' show askText;

const _kindColors = {'resoudre': K.lime, 'traverser': Color(0xFFB9A7FF), 'deux': K.gold};
Color problemColor(Problem p) => _kindColors[p.kind] ?? K.lime;

String _dayLabel(String day) {
  const months = ['janv', 'févr', 'mars', 'avr', 'mai', 'juin', 'juil', 'août', 'sept', 'oct', 'nov', 'déc'];
  final d = DateTime.tryParse(day);
  return d == null ? day : '${d.day} ${months[d.month - 1]}';
}

/// Petite courbe d'intensité.
class _Spark extends StatelessWidget {
  final List<int> vals;
  final Color color;
  final double width;
  const _Spark(this.vals, this.color, {this.width = 110});

  @override
  Widget build(BuildContext context) => SizedBox(width: width, height: 30, child: CustomPaint(painter: _SparkPainter(vals, color)));
}

class _SparkPainter extends CustomPainter {
  final List<int> vals;
  final Color color;
  _SparkPainter(this.vals, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (vals.isEmpty) return;
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Offset at(int i) => Offset(vals.length == 1 ? size.width / 2 : i * size.width / (vals.length - 1), size.height - vals[i] * size.height / 10);
    if (vals.length == 1) {
      canvas.drawCircle(at(0), 3, p..style = PaintingStyle.fill);
      return;
    }
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < vals.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => true;
}

/// Bloc « Intensité du problème · 0 à 10 » : courbe, valeur, évolution.
class ProblemIntensity extends StatelessWidget {
  final Problem p;
  const ProblemIntensity(this.p, {super.key});

  @override
  Widget build(BuildContext context) {
    final col = problemColor(p);
    final h = p.history.map((e) => e.value).toList();
    final cur = p.current;
    final f = p.first;
    final d = cur == null || f == null ? 0 : cur - f;
    final dc = d < 0 ? K.lime : (d > 0 ? K.coral : K.muted);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('INTENSITÉ DU PROBLÈME · 0 À 10', style: K.body(10, color: K.dim, w: FontWeight.w900)),
      const SizedBox(height: 4),
      if (cur == null)
        Text('Pas encore notée.', style: K.body(12, color: K.muted))
      else
        Row(children: [
          _Spark(h, col),
          const SizedBox(width: 10),
          Text('$cur', style: K.display(22, color: col)),
          Text('/10', style: K.body(12, color: K.dim)),
          const Spacer(),
          if (h.length > 1)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${d < 0 ? '↓' : d > 0 ? '↑' : '→'} $f → $cur', style: K.body(13, color: dc, w: FontWeight.w900)),
              Text('depuis le ${_dayLabel(p.firstDay)}', style: K.body(10, color: K.dim)),
            ]),
        ]),
    ]);
  }
}

/// Échelle 0..10 en un tap.
class IntensityScale extends StatelessWidget {
  final int? value;
  final Color color;
  final ValueChanged<int> onChanged;
  const IntensityScale({super.key, required this.value, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i <= 10; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 10 ? 2 : 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(7),
                onTap: () => onChanged(i),
                child: Container(
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: value == i ? color : K.raised, borderRadius: BorderRadius.circular(7)),
                  child: Text('$i', style: K.body(11, color: value == i ? K.bg : K.muted, w: FontWeight.w900)),
                ),
              ),
            ),
          ),
      ]);
}

/// Ligne « prochaine étape » cochable.
Widget _nextRow(BuildContext context, AppStore store, Problem p) {
  final st = p.nextStep;
  final label = p.kind == 'traverser'
      ? 'PROCHAIN PAS QUI COMPTE, MALGRÉ ÇA'
      : 'PROCHAINE ÉTAPE · ${p.stepsDone} / ${p.steps.length} FAITES';
  return Container(
    padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
    decoration: BoxDecoration(color: K.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: K.lime, width: 2)),
    child: Row(children: [
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: st == null ? null : () => store.toggleProblemStep(p, st),
        icon: const Icon(Icons.radio_button_unchecked_rounded, color: K.lime),
      ),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: K.body(10, color: K.lime, w: FontWeight.w900)),
          Text(st == null ? (p.steps.isEmpty ? 'Aucune étape : ajoute-en une' : 'Toutes les étapes sont faites') : st['t'] as String, style: K.body(13)),
        ]),
      ),
    ]),
  );
}

/// « Mes problèmes » : ouverts, apaisés, résolus.
class ProblemsScreen extends StatefulWidget {
  const ProblemsScreen({super.key});

  @override
  State<ProblemsScreen> createState() => _ProblemsScreenState();
}

class _ProblemsScreenState extends State<ProblemsScreen> {
  String _filter = 'ouvert';

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final list = store.problems.where((p) => _filter == 'ouvert' ? p.open : (_filter == 'apaise' ? p.status == 'apaise' || p.status == 'accepte' : p.status == 'resolu')).toList()
      ..sort((a, b) => b.ts.compareTo(a.ts));
    int n(String f) => store.problems.where((p) => f == 'ouvert' ? p.open : (f == 'apaise' ? p.status == 'apaise' || p.status == 'accepte' : p.status == 'resolu')).length;
    final calm = store.openProblems.where(store.problemCalm).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Mes problèmes'), actions: [
        TextButton(
          onPressed: () async {
            final t = await askText(context, 'Nouveau problème', hint: 'concret : « mon article n\'avance pas »');
            if (t == null || t.trim().isEmpty) return;
            final p = await store.addProblem(t.trim());
            if (context.mounted) openScreen(context, ProblemScreen(problem: p, guided: true));
          },
          child: Text('+ nouveau', style: K.body(13, color: K.cyan, w: FontWeight.w800)),
        ),
      ]),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            Wrap(spacing: 6, children: [
              for (final f in const [('ouvert', 'ouverts'), ('apaise', 'apaisés'), ('resolu', 'résolus')])
                ChoiceChip(
                  label: Text('${f.$2} · ${n(f.$1)}'),
                  selected: _filter == f.$1,
                  onSelected: (_) => setState(() => _filter = f.$1),
                  selectedColor: const Color(0xFFB9A7FF),
                  labelStyle: K.body(12, w: FontWeight.w800, color: _filter == f.$1 ? K.bg : K.muted),
                  backgroundColor: K.raised,
                  side: BorderSide.none,
                  showCheckmark: false,
                ),
            ]),
            const SizedBox(height: 10),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  _filter == 'ouvert' ? 'Aucun problème ouvert. Tu peux en noter un ici, ou depuis la cabane de Micky.' : 'Rien ici pour l\'instant.',
                  style: K.body(13, color: K.muted),
                ),
              ),
            for (final p in list) ...[
              Panel(
                child: InkWell(
                  onTap: () => openScreen(context, ProblemScreen(problem: p)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(p.title, style: K.body(14, w: FontWeight.w800))),
                      Pill(p.open ? Problem.kinds[p.kind]! : Problem.statuses[p.status]!, color: K.bg, fill: problemColor(p)),
                    ]),
                    const SizedBox(height: 6),
                    ProblemIntensity(p),
                    if (p.open) ...[
                      const SizedBox(height: 8),
                      _nextRow(context, store, p),
                    ],
                    if (!p.open && p.closedWhy.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Ce qui a aidé : ${p.closedWhy}', style: K.body(12, color: K.muted)),
                    ],
                  ]),
                ),
              ),
              const SizedBox(height: 10),
            ],
            for (final p in calm.where((p) => _filter == 'ouvert'))
              CalmSuggestion(p),
          ],
        ),
      ),
    );
  }
}

/// « X est passé de a à b et y reste depuis 3 jours. On le range ? »
class CalmSuggestion extends StatelessWidget {
  final Problem p;
  const CalmSuggestion(this.p, {super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1E2A1A), borderRadius: BorderRadius.circular(16), border: Border.all(color: K.lime, width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('« ${p.title} » est passé de ${p.first} à ${p.current} et y reste depuis 3 relevés. On le range ?', style: K.body(13)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in p.kind == 'traverser' ? const ['apaise', 'accepte'] : const ['resolu', 'apaise'])
            ActionChip(
              label: Text(Problem.statuses[s]!),
              onPressed: () => closeProblemDialog(context, store, p, s),
              backgroundColor: K.lime,
              labelStyle: K.body(12, color: K.bg, w: FontWeight.w800),
              side: BorderSide.none,
            ),
          ActionChip(
            label: const Text('pas encore'),
            onPressed: () => store.snoozeCalm(p),
            backgroundColor: K.raised,
            labelStyle: K.body(12, color: K.muted, w: FontWeight.w800),
            side: BorderSide.none,
          ),
        ]),
      ]),
    );
  }
}

Future<void> closeProblemDialog(BuildContext context, AppStore store, Problem p, String status) async {
  final why = await askText(context, 'Qu\'est-ce qui a aidé ?', hint: 'facultatif, mais précieux pour la prochaine fois');
  await store.closeProblem(p, status, why: (why ?? '').trim());
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('« ${p.title} » : ${Problem.statuses[status]} · +10 XP')));
  }
}

/// La fiche d'un problème. [guided] = mode résolution pas à pas (depuis la cabane ou à la création).
class ProblemScreen extends StatefulWidget {
  final Problem problem;
  final bool guided;
  const ProblemScreen({super.key, required this.problem, this.guided = false});

  @override
  State<ProblemScreen> createState() => _ProblemScreenState();
}

class _ProblemScreenState extends State<ProblemScreen> {
  late final _title = TextEditingController(text: widget.problem.title);
  late final _goal = TextEditingController(text: widget.problem.goal);

  @override
  void dispose() {
    _title.dispose();
    _goal.dispose();
    super.dispose();
  }

  Future<void> _saveText(AppStore store) async {
    final p = widget.problem;
    if (_title.text.trim().isNotEmpty) p.title = _title.text.trim();
    p.goal = _goal.text.trim();
    await store.commit();
  }

  Widget _h(String n, String t, Color c) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(widget.guided ? '$n · $t' : t, style: K.body(13, color: c, w: FontWeight.w800)),
      );

  Widget _dots(int v, Color c, ValueChanged<int> on) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 3; i++)
          GestureDetector(
            onTap: () => on(v == i ? 0 : i),
            child: Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.only(left: 3),
              decoration: BoxDecoration(color: i <= v ? c : K.line, shape: BoxShape.circle),
            ),
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = widget.problem;
    final col = problemColor(p);
    final solve = p.kind != 'traverser';
    final ideas = [...p.ideas]..sort((a, b) => ((b['f'] as int? ?? 0) + (b['e'] as int? ?? 0)).compareTo((a['f'] as int? ?? 0) + (a['e'] as int? ?? 0)));
    return PopScope(
      onPopInvokedWithResult: (_, __) => _saveText(store),
      child: Scaffold(
        appBar: AppBar(title: Text(widget.guided && solve ? 'Résoudre' : 'Le problème')),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              _h('1', 'Le problème, concrètement', col),
              TextField(controller: _title, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'un fait, pas un jugement sur toi')),
              const SizedBox(height: 10),
              Wrap(spacing: 6, children: [
                for (final k in Problem.kinds.entries)
                  ChoiceChip(
                    label: Text(k.value),
                    selected: p.kind == k.key,
                    onSelected: (_) => setState(() {
                      p.kind = k.key;
                      store.commit();
                    }),
                    selectedColor: _kindColors[k.key],
                    labelStyle: K.body(12, w: FontWeight.w800, color: p.kind == k.key ? K.bg : K.ink),
                    backgroundColor: K.raised,
                    side: BorderSide.none,
                    showCheckmark: false,
                  ),
              ]),
              const SizedBox(height: 12),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ProblemIntensity(p),
                  const SizedBox(height: 8),
                  Text('Aujourd\'hui (0 = plus là · 10 = au maximum)', style: K.body(11, color: K.muted)),
                  const SizedBox(height: 4),
                  IntensityScale(value: p.rates[store.todayKey], color: col, onChanged: (v) => store.rateProblem(p, v)),
                ]),
              ),
              if (solve) ...[
                _h('2', 'À quoi je verrai que c\'est mieux ?', col),
                TextField(controller: _goal, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'un signe concret et réaliste')),
                _h('3 · 4', 'Toutes les idées, sans juger, puis choisir', col),
                Text('Note chaque idée : faisable (bleu) et effet probable (jaune). Garde-en une ou deux.', style: K.body(11, color: K.muted)),
                const SizedBox(height: 6),
                for (final i in ideas)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                    decoration: BoxDecoration(
                      color: i['c'] == true ? K.lime.withValues(alpha: 0.12) : K.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: i['c'] == true ? K.lime : K.line, width: 2),
                    ),
                    child: Row(children: [
                      Expanded(child: Text(i['t'] as String, style: K.body(13, w: FontWeight.w700))),
                      _dots(i['f'] as int? ?? 0, K.cyan, (v) => setState(() {
                            i['f'] = v;
                            store.commit();
                          })),
                      const SizedBox(width: 6),
                      _dots(i['e'] as int? ?? 0, K.gold, (v) => setState(() {
                            i['e'] = v;
                            store.commit();
                          })),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Choisir',
                        onPressed: () async {
                          final chosen = i['c'] != true;
                          i['c'] = chosen;
                          if (chosen && !p.steps.any((s) => s['t'] == i['t'])) await store.addProblemStep(p, i['t'] as String);
                          await store.commit();
                          setState(() {});
                        },
                        icon: Icon(i['c'] == true ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, color: i['c'] == true ? K.lime : K.muted),
                      ),
                    ]),
                  ),
                TextButton(
                  onPressed: () async {
                    final t = await askText(context, 'Une idée', hint: 'même farfelue : on trie après');
                    if (t == null || t.trim().isEmpty) return;
                    p.ideas.add({'t': t.trim(), 'f': 0, 'e': 0, 'c': false});
                    await store.commit();
                    setState(() {});
                  },
                  child: Align(alignment: Alignment.centerLeft, child: Text('+ une idée', style: K.body(13, color: K.cyan, w: FontWeight.w800))),
                ),
              ],
              _h(solve ? '5' : '2', solve ? 'Étapes de solution' : 'Petits pas qui comptent, malgré ça', K.lime),
              if (!solve)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('Ce qu\'on traverse peut rester un moment. Un petit pas vers ce qui compte pour toi aide à se remettre en mouvement.', style: K.body(11, color: K.muted)),
                ),
              for (final st in p.steps) _stepRow(store, p, st),
              TextButton(
                onPressed: () async {
                  final t = await askText(context, solve ? 'Une étape' : 'Un petit pas', hint: solve ? 'concrète, faisable en une fois' : 'ex. : marcher 20 min avec quelqu\'un');
                  if (t == null || t.trim().isEmpty) return;
                  await store.addProblemStep(p, t.trim());
                  setState(() {});
                },
                child: Align(alignment: Alignment.centerLeft, child: Text(solve ? '+ une étape' : '+ un petit pas', style: K.body(13, color: K.cyan, w: FontWeight.w800))),
              ),
              Text('Les étapes restent ici. Tu peux en faire une tâche, ou les lier à une tâche qui existe déjà : quand la tâche est faite, l\'étape aussi.',
                  style: K.body(11, color: K.dim)),
              const SizedBox(height: 18),
              if (p.open) ...[
                Text('Clore', style: K.body(13, color: K.muted, w: FontWeight.w800)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final s in const ['resolu', 'apaise', 'accepte'])
                    ActionChip(
                      label: Text(Problem.statuses[s]!),
                      onPressed: () async {
                        await _saveText(store);
                        if (!context.mounted) return;
                        await closeProblemDialog(context, store, p, s);
                        if (context.mounted) Navigator.pop(context);
                      },
                      backgroundColor: K.raised,
                      labelStyle: K.body(12, w: FontWeight.w800),
                      side: BorderSide.none,
                    ),
                ]),
              ] else
                SecondaryButton(label: 'Rouvrir', onPressed: () => store.closeProblem(p, 'ouvert')),
              if (widget.guided) ...[
                const SizedBox(height: 14),
                PrimaryButton(
                  label: 'C\'est bon',
                  onPressed: () async {
                    await _saveText(store);
                    if (context.mounted) Navigator.pop(context, true);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepRow(AppStore store, Problem p, Map<String, dynamic> st) {
    final task = store.taskById((st['task'] as String?) ?? '');
    final done = st['done'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () async {
            await store.toggleProblemStep(p, st);
            setState(() {});
          },
          icon: Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: K.lime),
        ),
        Expanded(
          child: Text(st['t'] as String,
              style: K.body(13, color: done ? K.muted : K.ink).copyWith(decoration: done ? TextDecoration.lineThrough : null)),
        ),
        PopupMenuButton<String>(
          color: K.card,
          onSelected: (v) async {
            if (v == 'task') await store.stepToTask(p, st);
            if (v == 'link') {
              final t = await _pickTask(store);
              if (t != null) {
                st['task'] = t.id;
                await store.commit();
              }
            }
            if (v == 'unlink') {
              st['task'] = '';
              await store.commit();
            }
            if (v == 'del') {
              p.steps.remove(st);
              await store.commit();
            }
            setState(() {});
          },
          itemBuilder: (_) => [
            if (task == null) const PopupMenuItem(value: 'task', child: Text('En faire une tâche')),
            if (task == null) const PopupMenuItem(value: 'link', child: Text('Lier à une tâche existante')),
            if (task != null) const PopupMenuItem(value: 'unlink', child: Text('Délier')),
            const PopupMenuItem(value: 'del', child: Text('Supprimer')),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Pill(task == null ? '+ lier' : '↔ ${task.title.length > 18 ? '${task.title.substring(0, 18)}…' : task.title}',
                color: task == null ? K.muted : K.bg, fill: task == null ? K.raised : K.cyan),
          ),
        ),
      ]),
    );
  }

  Future<Task?> _pickTask(AppStore store) {
    final open = store.tasks.where((t) => !t.done && !t.removed).toList();
    return showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              Text('Lier à quelle tâche ?', style: K.display(18)),
              const SizedBox(height: 8),
              if (open.isEmpty) Text('Aucune tâche ouverte.', style: K.body(13, color: K.muted)),
              for (final t in open)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.title, style: K.body(14)),
                  onTap: () => Navigator.pop(ctx, t),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Feu de camp : intensité de chaque problème ouvert, étapes faites aujourd'hui, problème qui ne baisse pas.
class ProblemsFireCard extends StatelessWidget {
  final String day;
  const ProblemsFireCard({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final open = store.openProblems;
    if (open.isEmpty) return const SizedBox.shrink();
    final stuck = open.where((p) {
      final h = p.history;
      return h.length >= 3 && h.sublist(h.length - 3).every((e) => e.value >= 7);
    }).toList();
    final calm = open.where(store.problemCalm).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('INTENSITÉ DE CHAQUE PROBLÈME AUJOURD\'HUI', style: K.body(11, color: const Color(0xFFB9A7FF), w: FontWeight.w900))),
            TextButton(onPressed: () => openScreen(context, const ProblemsScreen()), child: Text('tout voir', style: K.body(12, color: K.cyan))),
          ]),
          Text('0 = plus là · 10 = au maximum. Un tap par problème, tu peux passer.', style: K.body(11, color: K.muted)),
          const SizedBox(height: 8),
          for (final p in open) ...[
            Text(p.title, style: K.body(13, w: FontWeight.w800)),
            const SizedBox(height: 4),
            IntensityScale(value: p.rates[day], color: problemColor(p), onChanged: (v) => store.rateProblem(p, v, day: day)),
            const SizedBox(height: 10),
          ],
        ]),
      ),
      for (final p in stuck)
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF2A2516), borderRadius: BorderRadius.circular(16), border: Border.all(color: K.gold, width: 2)),
          child: Row(children: [
            Expanded(child: Text('« ${p.title} » reste haut. Une étape pour demain ?', style: K.body(13))),
            TextButton(onPressed: () => openScreen(context, ProblemScreen(problem: p)), child: Text('Ouvrir', style: K.body(13, color: K.gold, w: FontWeight.w900))),
          ]),
        ),
      for (final p in calm) Padding(padding: const EdgeInsets.only(top: 8), child: CalmSuggestion(p)),
    ]);
  }
}
