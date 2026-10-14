import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';

/// Vider la tête (toutes les idées → trier) ou Découper une tâche (→ étapes avec pari).
/// En mode découpe, renvoie la première étape créée (pour la lancer tout de suite).
class DumpScreen extends StatefulWidget {
  final Task? cut;
  final int minutes; // minuteur facultatif (0 = aucun)
  const DumpScreen({super.key, this.cut, this.minutes = 0});

  @override
  State<DumpScreen> createState() => _DumpScreenState();
}

class _Line {
  String text;
  String choice; // dump : task, pro, perso, keep ; cut : pari
  int pari;
  _Line(this.text, {this.choice = '', this.pari = 25});
}

class _DumpScreenState extends State<DumpScreen> {
  final _text = TextEditingController();
  List<_Line>? _lines;
  Timer? _timer;
  int _left = 0;

  bool get _cut => widget.cut != null;

  @override
  void initState() {
    super.initState();
    if (widget.minutes > 0) {
      _left = widget.minutes * 60;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _left--);
        if (_left <= 0) {
          _timer?.cancel();
          if (_lines == null) _split();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    super.dispose();
  }

  /// Texte reconnu ailleurs (stylet) : ajouté à la suite.
  void appendText(String t) {
    final cur = _text.text.trimRight();
    _text.text = cur.isEmpty ? t : '$cur\n$t';
  }

  void _split() {
    final lines = _text.text
        .split('\n')
        .map((l) => l.trim().replaceFirst(RegExp(r'^[-•*·\d.)]+\s*'), ''))
        .where((l) => l.isNotEmpty)
        .toList();
    setState(() => _lines = [for (final l in lines) _Line(l, choice: _cut ? 'step' : '')]);
  }

  Future<void> _apply() async {
    final store = AppScope.read(context);
    final lines = _lines ?? [];
    if (_cut) {
      final parent = widget.cut!;
      Task? first;
      for (final l in lines.where((l) => l.choice == 'step')) {
        final t = await store.addTask(
          parent.inQuest ? l.text : '${parent.title} › ${l.text}',
          category: parent.category,
          estimate: l.pari,
          quad: Quad.doNow,
          inQuest: parent.inQuest,
        );
        first ??= t;
      }
      // la tâche d'origine devient le chapeau : elle ne réclame plus de pari
      if (first != null && !parent.inQuest) {
        parent.quad = parent.quad == Quad.inbox ? Quad.plan : parent.quad;
        await store.commit();
      }
      if (mounted) Navigator.pop(context, first);
      return;
    }
    var n = 0;
    for (final l in lines) {
      switch (l.choice) {
        case 'task':
          await store.addTask(l.text, inQuest: false);
          n++;
          break;
        case 'pro':
        case 'perso':
          await store.addTask(l.text, category: l.choice, inQuest: true);
          n++;
          break;
        case 'keep':
          await store.addLog(LogEntry(ts: DateTime.now().millisecondsSinceEpoch, kind: LogKind.free, note: 'Vide-tête : ${l.text}'));
          break;
      }
    }
    await store.noteSerenity('vide-tête');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(n == 0 ? 'Tête vidée. Rien à faire de plus.' : '$n tâche${n > 1 ? 's' : ''} ajoutée${n > 1 ? 's' : ''}')));
    Navigator.pop(context);
  }

  Widget _chip(String label, bool on, Color c, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6, bottom: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: on ? c : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: on ? c : K.line, width: 2),
            ),
            child: Text(label, style: K.body(11, color: on ? K.bg : K.ink, w: FontWeight.w800)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final title = _cut ? 'Découper' : 'Vider la tête';
    final lines = _lines;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.minutes > 0 && _left > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Text('${_left ~/ 60}:${(_left % 60).toString().padLeft(2, '0')}', style: K.display(16, color: K.gold)),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (lines == null) ...[
              Text(
                _cut
                    ? '« ${widget.cut!.title} » : écris les morceaux, un par ligne. Le premier doit être faisable tout de suite.'
                    : 'Tout ce qui te passe par la tête, une idée par ligne. Pas de tri, pas de jugement : on range après.',
                style: K.body(13, color: K.muted),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _text,
                autofocus: true,
                maxLines: null,
                minLines: 10,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: _cut ? 'ouvrir le fichier\nrelire la partie 2\nreprendre la figure 3' : 'appeler la banque\nidée pour le cours\nacheter du lait\nj\'ai peur de ne pas finir…',
                ),
              ),
              const SizedBox(height: 14),
              PrimaryButton(label: _cut ? 'Voir mes étapes' : 'Trier mes idées', onPressed: _text.text.trim().isEmpty ? null : _split),
              Builder(builder: (_) {
                // rafraîchit l'état du bouton
                _text.removeListener(_refresh);
                _text.addListener(_refresh);
                return const SizedBox.shrink();
              }),
            ] else ...[
              Text(
                _cut ? 'Un pari par étape. Décoche ce qui n\'est pas une étape.' : 'Pour chaque idée : une tâche, une étape de ta quête du jour, ou juste la laisser là (elle est notée).',
                style: K.body(13, color: K.muted),
              ),
              const SizedBox(height: 10),
              for (final l in lines)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(14)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      if (_cut)
                        Checkbox(
                          value: l.choice == 'step',
                          activeColor: K.lime,
                          onChanged: (v) => setState(() => l.choice = v == true ? 'step' : ''),
                        ),
                      Expanded(child: Text(l.text, style: K.body(14, w: FontWeight.w800))),
                    ]),
                    const SizedBox(height: 6),
                    Wrap(children: _cut
                        ? [for (final m in [10, 15, 25, 45, 60]) _chip('$m min', l.pari == m, K.cyan, () => setState(() => l.pari = m))]
                        : [
                            _chip('Tâche', l.choice == 'task', K.gold, () => setState(() => l.choice = l.choice == 'task' ? '' : 'task')),
                            _chip('Étape pro${store.today.pro.isNotEmpty ? ' · ${store.today.pro}' : ''}', l.choice == 'pro', K.lime, () => setState(() => l.choice = l.choice == 'pro' ? '' : 'pro')),
                            _chip('Étape perso', l.choice == 'perso', K.pink, () => setState(() => l.choice = l.choice == 'perso' ? '' : 'perso')),
                            _chip('Laisser', l.choice == 'keep', K.muted, () => setState(() => l.choice = l.choice == 'keep' ? '' : 'keep')),
                          ]),
                  ]),
                ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: SecondaryButton(label: 'Réécrire', onPressed: () => setState(() => _lines = null))),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: _cut ? 'Créer les étapes' : 'Ranger',
                    onPressed: _apply,
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  void _refresh() {
    if (mounted) setState(() {});
  }
}
