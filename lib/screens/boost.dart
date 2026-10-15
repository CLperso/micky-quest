import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'dump.dart';

/// « Ça flotte » : trouver pourquoi, et la relance qui va avec.
class BoostScreen extends StatefulWidget {
  final SessionRec? session;
  const BoostScreen({super.key, this.session});

  @override
  State<BoostScreen> createState() => _BoostScreenState();
}

class _BoostScreenState extends State<BoostScreen> {
  String _cause = '';
  int _min = 15;
  final _next = TextEditingController();
  final _goal = TextEditingController();
  final _knot = TextEditingController();
  String _body = '';

  static const _causes = [
    ('flou', 'Je ne sais pas trop quoi faire ensuite', 'la tâche est floue'),
    ('pression', 'Ça manque de pression', 'tout est mou, rien ne presse'),
    ('rond', 'Je tourne en rond', 'je réécris, je peaufine'),
    ('dur', 'J\'évite la partie difficile', 'je fais le facile autour'),
    ('corps', 'Mon corps', 'faim, fatigue, assise depuis trop longtemps'),
  ];

  @override
  void dispose() {
    _next.dispose();
    _goal.dispose();
    _knot.dispose();
    super.dispose();
  }

  Widget _field(String label, TextEditingController c, String hint, Color col) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: K.body(12, w: FontWeight.w800, color: col)),
          const SizedBox(height: 4),
          TextField(controller: c, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(hintText: hint)),
        ]),
      );

  Widget _minutes() => Row(children: [
        for (final m in const [10, 15, 25])
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: m == 25 ? 0 : 6),
              child: ChoiceChip(
                label: SizedBox(width: double.infinity, child: Text('$m min', textAlign: TextAlign.center)),
                selected: _min == m,
                onSelected: (_) => setState(() => _min = m),
                selectedColor: K.cyan,
                labelStyle: K.body(13, w: FontWeight.w800, color: _min == m ? K.bg : K.ink),
                backgroundColor: K.raised,
                side: BorderSide.none,
                showCheckmark: false,
              ),
            ),
          ),
      ]);

  Future<void> _sprint(String goal, {String hint = '', bool draft = false}) async {
    final store = AppScope.read(context);
    await store.addBoost(widget.session, _cause);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => SprintScreen(minutes: _min, goal: goal, hint: hint, draft: draft),
    ));
  }

  List<Widget> _help() {
    switch (_cause) {
      case 'flou':
        return [
          _field('La toute prochaine chose visible', _next, 'ex. : relire le 2e paragraphe des limites', K.gold),
          _field('Dans $_min min, j\'aurai…', _goal, 'ex. : réécrit ce paragraphe en 5 phrases', K.lime),
          _minutes(),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Sprint · c\'est parti',
            onPressed: () => _sprint(_goal.text.trim().isNotEmpty ? _goal.text.trim() : _next.text.trim(), hint: _next.text.trim()),
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Trop flou : découper la tâche',
            onPressed: () async {
              final store = AppScope.read(context);
              await store.addBoost(widget.session, _cause);
              final t = widget.session == null ? null : store.taskById(widget.session!.taskId);
              if (!mounted) return;
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => DumpScreen(cut: t)));
            },
          ),
        ];
      case 'pression':
        return [
          Text('On recrée un peu d\'urgence : un résultat précis, un chrono visible, un pari avec toi-même.', style: K.body(13, color: K.muted)),
          const SizedBox(height: 10),
          _field('Mon pari : en $_min min, j\'aurai…', _goal, 'ex. : 3 paragraphes, 20 références triées', K.lime),
          _minutes(),
          const SizedBox(height: 10),
          Text('Et pour réveiller la machine, change une chose : te lever, dicter, passer au papier, changer de pièce, mettre du bruit de fond.',
              style: K.body(12, color: K.muted)),
          const SizedBox(height: 12),
          PrimaryButton(label: 'Je relève le pari', onPressed: () => _sprint(_goal.text.trim())),
        ];
      case 'rond':
        return [
          Text('Mode brouillon moche : tu écris vite, sans relire, sans corriger. Ce qui coince, tu le marques [À REVOIR] et tu passes. La correction, ce sera une autre session.',
              style: K.body(13, color: K.muted)),
          const SizedBox(height: 10),
          _field('En $_min min, je sors un brouillon de…', _goal, 'ex. : toute la fin de la discussion', K.lime),
          _minutes(),
          const SizedBox(height: 12),
          PrimaryButton(label: 'Brouillon moche · go', onPressed: () => _sprint(_goal.text.trim(), draft: true)),
        ];
      case 'dur':
        return [
          _field('Le nœud, en une phrase', _knot, 'ex. : je ne sais pas comment répondre au relecteur 2', K.gold),
          Text('5 minutes dessus, en premier. Après, tu as le droit de revenir au facile.', style: K.body(13, color: K.muted)),
          const SizedBox(height: 12),
          PrimaryButton(
            label: '5 min sur le nœud',
            onPressed: () {
              _min = 5;
              _sprint(_knot.text.trim().isEmpty ? 'le morceau difficile' : _knot.text.trim(), hint: 'Seulement ça. Même mal.');
            },
          ),
        ];
      case 'corps':
        return [
          Text('D\'abord le corps, le cerveau suit. Choisis un geste, puis on repart.', style: K.body(13, color: K.muted)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final g in const ['Un verre d\'eau', 'Manger un truc', '2 min debout, bouger', 'Ouvrir la fenêtre', '5 min allongée'])
              ChoiceChip(
                label: Text(g),
                selected: _body == g,
                onSelected: (_) => setState(() => _body = g),
                selectedColor: K.gold,
                labelStyle: K.body(13, w: FontWeight.w800, color: _body == g ? K.bg : K.ink),
                backgroundColor: K.raised,
                side: BorderSide.none,
                showCheckmark: false,
              ),
          ]),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'C\'est fait, je reprends',
            onPressed: () async {
              final store = AppScope.read(context);
              await store.addBoost(widget.session, _cause);
              if (!mounted) return;
              Navigator.pop(context);
            },
          ),
        ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.session?.title ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Me relancer')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            Text(title.isEmpty ? 'Ça flotte. Plutôt… ?' : 'Ça flotte sur « $title ». Plutôt… ?', style: K.body(14, color: K.muted)),
            const SizedBox(height: 12),
            for (final c in _causes)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: _cause == c.$1 ? K.gold.withValues(alpha: 0.14) : K.card,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _cause = _cause == c.$1 ? '' : c.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _cause == c.$1 ? K.gold : K.line, width: 2),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.$2, style: K.body(14, w: FontWeight.w800)),
                        Text(c.$3, style: K.body(12, color: K.muted)),
                      ]),
                    ),
                  ),
                ),
              ),
            if (_cause.isNotEmpty) ...[
              const SizedBox(height: 8),
              Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _help())),
            ],
            const SizedBox(height: 12),
            Text('Chaque cause choisie est notée : Découvertes te dira ce qui te fait flotter, et quelle relance marche pour toi.',
                style: K.body(11, color: K.dim)),
          ],
        ),
      ),
    );
  }
}

/// Sprint court avec un résultat visé, à l'intérieur d'une session.
class SprintScreen extends StatefulWidget {
  final int minutes;
  final String goal;
  final String hint;
  final bool draft;
  const SprintScreen({super.key, required this.minutes, required this.goal, this.hint = '', this.draft = false});

  @override
  State<SprintScreen> createState() => _SprintScreenState();
}

class _SprintScreenState extends State<SprintScreen> {
  int _elapsed = 0;
  Timer? _t;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed++;
        if (_elapsed >= widget.minutes * 60) {
          _t?.cancel();
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

  Future<void> _finish(String how) async {
    final store = AppScope.read(context);
    await store.addLog(LogEntry(
      ts: DateTime.now().millisecondsSinceEpoch,
      kind: LogKind.free,
      note: 'Sprint ${widget.minutes} min${widget.goal.isEmpty ? '' : ' · « ${widget.goal} »'} : $how',
    ));
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.minutes * 60;
    final left = (total - _elapsed).clamp(0, total);
    final mmss = '${(left ~/ 60).toString().padLeft(2, '0')}:${(left % 60).toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(title: Text(widget.draft ? 'Brouillon moche' : 'Sprint')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            if (widget.goal.isNotEmpty) ...[
              Text('DANS ${widget.minutes} MIN, J\'AURAI', style: K.body(11, color: K.lime, w: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(widget.goal, style: K.display(20)),
            ],
            if (widget.hint.isNotEmpty && widget.hint != widget.goal) ...[
              const SizedBox(height: 6),
              Text(widget.hint, style: K.body(13, color: K.muted)),
            ],
            if (widget.draft) ...[
              const SizedBox(height: 6),
              Text('Pas de relecture, pas de correction. [À REVOIR] et tu passes.', style: K.body(13, color: K.muted)),
            ],
            const SizedBox(height: 28),
            Center(
              child: SizedBox(
                width: 220,
                height: 220,
                child: Stack(fit: StackFit.expand, children: [
                  CircularProgressIndicator(value: _elapsed / total, strokeWidth: 12, color: K.lime, backgroundColor: K.raised),
                  Center(child: Text(_done ? 'Fini !' : mmss, style: K.display(44))),
                ]),
              ),
            ),
            const SizedBox(height: 28),
            if (!_done) SecondaryButton(label: 'J\'ai fini avant', onPressed: () => setState(() {
                  _t?.cancel();
                  _done = true;
                })),
            if (_done) ...[
              Text('C\'est fait ?', style: K.body(15, w: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: PrimaryButton(label: 'Oui', onPressed: () => _finish('fait'))),
                const SizedBox(width: 6),
                Expanded(child: PrimaryButton(label: 'En partie', color: K.gold, onPressed: () => _finish('en partie'))),
                const SizedBox(width: 6),
                Expanded(child: SecondaryButton(label: 'Non', onPressed: () => _finish('pas fait'))),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
