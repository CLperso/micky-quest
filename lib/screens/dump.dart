import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart' as mk;

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'notebook.dart' show isTablet;

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
  bool _pen = false;
  final _pad = GlobalKey<_InkPadState>();

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
          await store.addLog(LogEntry(ts: DateTime.now().millisecondsSinceEpoch, kind: LogKind.free, note: 'Rangement : ${l.text}'));
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
    final title = _cut ? 'Découper' : 'Se ranger la tête';
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
              if (isTablet(context)) ...[
                const SizedBox(height: 8),
                Row(children: [
                  ChoiceChip(
                    label: const Text('Clavier'),
                    selected: !_pen,
                    onSelected: (_) => setState(() => _pen = false),
                    selectedColor: K.cyan,
                    labelStyle: K.body(13, color: !_pen ? K.bg : K.ink),
                    backgroundColor: K.raised,
                    side: BorderSide.none,
                    showCheckmark: false,
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Stylet'),
                    selected: _pen,
                    onSelected: (_) => setState(() => _pen = true),
                    selectedColor: K.cyan,
                    labelStyle: K.body(13, color: _pen ? K.bg : K.ink),
                    backgroundColor: K.raised,
                    side: BorderSide.none,
                    showCheckmark: false,
                  ),
                ]),
              ],
              if (_pen) ...[
                const SizedBox(height: 10),
                _InkPad(key: _pad),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: SecondaryButton(label: 'Effacer', onPressed: () => _pad.currentState?.clear())),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Lire mon écriture',
                      color: K.cyan,
                      onPressed: () async {
                        final st = _pad.currentState;
                        if (st == null) return;
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.showSnackBar(const SnackBar(content: Text('Lecture de ton écriture…'), duration: Duration(seconds: 2)));
                        final lines = await st.recognize();
                        if (!mounted) return;
                        if (lines == null) {
                          messenger.showSnackBar(const SnackBar(content: Text('Lecture impossible pour l\'instant (il faut une connexion la première fois, pour télécharger le français).')));
                          return;
                        }
                        appendText(lines.join('\n'));
                        st.clear();
                        setState(() => _pen = false);
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Text('Une idée par ligne. « Lire mon écriture » la transforme en texte, que tu peux corriger avant de trier.', style: K.body(11, color: K.muted)),
              ],
              const SizedBox(height: 10),
              if (!_pen)
              TextField(
                controller: _text,
                autofocus: !isTablet(context),
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

/// Zone d'écriture au stylet, reconnue par ML Kit (français, sur l'appareil).
class _InkPad extends StatefulWidget {
  const _InkPad({super.key});

  @override
  State<_InkPad> createState() => _InkPadState();
}

class _InkPadState extends State<_InkPad> {
  final List<List<(Offset, int)>> _strokes = [];
  List<(Offset, int)>? _cur;

  void clear() => setState(() => _strokes.clear());

  /// Regroupe les traits en lignes (par hauteur), reconnaît chaque ligne. null si impossible.
  Future<List<String>?> recognize() async {
    if (_strokes.isEmpty) return [];
    try {
      const lang = 'fr';
      final manager = mk.DigitalInkRecognizerModelManager();
      if (!await manager.isModelDownloaded(lang)) {
        final ok = await manager.downloadModel(lang, isWifiRequired: false);
        if (!ok) return null;
      }
      final recognizer = mk.DigitalInkRecognizer(languageCode: lang);
      // lignes : traits dont le centre vertical est proche
      final groups = <List<List<(Offset, int)>>>[];
      final centers = <double>[];
      final sorted = [..._strokes]..sort((a, b) => _cy(a).compareTo(_cy(b)));
      for (final s in sorted) {
        final cy = _cy(s);
        if (centers.isNotEmpty && (cy - centers.last).abs() < 38) {
          groups.last.add(s);
          centers[centers.length - 1] = (centers.last * (groups.last.length - 1) + cy) / groups.last.length;
        } else {
          groups.add([s]);
          centers.add(cy);
        }
      }
      final out = <String>[];
      for (final g in groups) {
        g.sort((a, b) => a.first.$2.compareTo(b.first.$2));
        final ink = mk.Ink();
        ink.strokes = [
          for (final s in g)
            mk.Stroke()..points = [for (final p in s) mk.StrokePoint(x: p.$1.dx, y: p.$1.dy, t: p.$2)]
        ];
        final c = await recognizer.recognize(ink);
        if (c.isNotEmpty && c.first.text.trim().isNotEmpty) out.add(c.first.text.trim());
      }
      await recognizer.close();
      return out;
    } catch (e) {
      debugPrint('Encre : $e');
      return null;
    }
  }

  double _cy(List<(Offset, int)> s) {
    var minY = double.infinity, maxY = -double.infinity;
    for (final p in s) {
      minY = p.$1.dy < minY ? p.$1.dy : minY;
      maxY = p.$1.dy > maxY ? p.$1.dy : maxY;
    }
    return (minY + maxY) / 2;
  }

  @override
  Widget build(BuildContext context) => Container(
        height: 420,
        decoration: BoxDecoration(color: const Color(0xFFF7F4EC), borderRadius: BorderRadius.circular(16)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Listener(
            onPointerDown: (e) => setState(() {
              _cur = [(e.localPosition, DateTime.now().millisecondsSinceEpoch)];
              _strokes.add(_cur!);
            }),
            onPointerMove: (e) => setState(() => _cur?.add((e.localPosition, DateTime.now().millisecondsSinceEpoch))),
            onPointerUp: (_) => _cur = null,
            child: CustomPaint(painter: _InkPainter(_strokes), size: Size.infinite),
          ),
        ),
      );
}

class _InkPainter extends CustomPainter {
  final List<List<(Offset, int)>> strokes;
  _InkPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final lines = Paint()..color = const Color(0xFFE0DACB)..strokeWidth = 1;
    for (var y = 60.0; y < size.height; y += 60) {
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), lines);
    }
    final p = Paint()
      ..color = const Color(0xFF2A2450)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.length < 2) {
        canvas.drawCircle(s.first.$1, 1.4, p);
        continue;
      }
      final path = Path()..moveTo(s.first.$1.dx, s.first.$1.dy);
      for (final pt in s.skip(1)) {
        path.lineTo(pt.$1.dx, pt.$1.dy);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _InkPainter old) => true;
}
