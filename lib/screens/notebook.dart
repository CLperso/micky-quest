import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../notes_io.dart';
import '../store.dart';
import '../theme.dart';

bool isTablet(BuildContext context) => MediaQuery.of(context).size.shortestSide >= 600;

/// Liste des pages manuscrites (tablette).
class NotebookScreen extends StatelessWidget {
  const NotebookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final pages = store.liveNotes;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Carnet', style: K.display(28)),
                  Text('Écris au stylet. Le bouton du S Pen sert de gomme.', style: K.body(14, color: K.muted)),
                ],
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: K.lime, foregroundColor: K.bg, minimumSize: const Size(0, 52)),
              onPressed: () async {
                final n = NoteMeta(day: store.todayKey, kind: 'libre', title: 'Page libre');
                store.notes.add(n);
                await store.commit();
                if (context.mounted) openScreen(context, HandwritingPage(note: n));
              },
              icon: const Icon(Icons.add_rounded),
              label: Text('Nouvelle page', style: K.body(15, color: K.bg, w: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (pages.isEmpty)
          Panel(child: Text('Aucune page pour l\'instant. Le briefing et le feu de camp ont aussi leur page manuscrite.',
              style: K.body(14, color: K.muted))),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final n in pages)
              SizedBox(
                width: 220,
                child: Material(
                  color: K.card,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => openScreen(context, HandwritingPage(note: n)),
                    onLongPress: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: K.card,
                          title: const Text('Supprimer cette page ?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        n.removed = true;
                        await store.commit();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 110,
                            decoration: BoxDecoration(color: const Color(0xFFF7F4EA), borderRadius: BorderRadius.circular(10)),
                            child: FutureBuilder<List<Stroke>>(
                              future: NotesIO.load(n.id),
                              builder: (_, snap) => ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CustomPaint(painter: _StrokesPainter(snap.data ?? const [], null), size: Size.infinite),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(n.title.isEmpty ? (NoteMeta.kinds[n.kind] ?? 'Page') : n.title, style: K.body(15, w: FontWeight.w800)),
                          Text(_fr(n.day), style: K.body(12, color: K.muted)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  static String _fr(String k) {
    final d = parseDay(k);
    return '${d.day}/${d.month}/${d.year}';
  }
}

/// Page où l'on écrit au stylet.
class HandwritingPage extends StatefulWidget {
  final NoteMeta note;
  const HandwritingPage({super.key, required this.note});

  @override
  State<HandwritingPage> createState() => _HandwritingPageState();
}

class _HandwritingPageState extends State<HandwritingPage> {
  List<Stroke> _strokes = [];
  final List<List<Stroke>> _undo = [];
  Stroke? _current;
  bool _loaded = false;
  bool _eraser = false;
  bool _highlighter = false;
  int _color = 0xFF1B1830;
  double _width = 2.2;
  bool _dirty = false;
  bool _erasingNow = false;
  late AppStore _store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store = AppScope.read(context);
  }

  static const _inks = [0xFF1B1830, 0xFF2F5BD3, 0xFFD3412F, 0xFF2E8B57, 0xFF8A3FD1];
  static const _highs = [0x66FFE14D, 0x6680FF5C, 0x664FE3FF, 0x66FF6FD8];

  @override
  void initState() {
    super.initState();
    NotesIO.load(widget.note.id).then((s) {
      if (mounted) {
        setState(() {
          _strokes = s;
          _loaded = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _save();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_dirty) return;
    _dirty = false;
    await NotesIO.save(widget.note.id, _strokes);
    final store = _store;
    widget.note.mod = DateTime.now().millisecondsSinceEpoch;
    if (!store.notes.contains(widget.note)) store.notes.add(widget.note);
    await store.commit();
  }

  bool _accept(PointerEvent e) {
    final stylusOnly = _store.settings.stylusOnly;
    final stylus = e.kind == PointerDeviceKind.stylus || e.kind == PointerDeviceKind.invertedStylus;
    return stylus || !stylusOnly;
  }

  bool _wantsErase(PointerEvent e) =>
      _eraser || e.kind == PointerDeviceKind.invertedStylus || (e.buttons & kSecondaryButton) != 0;

  void _down(PointerDownEvent e, double w) {
    if (!_accept(e)) return;
    _undo.add(List.of(_strokes));
    if (_undo.length > 40) _undo.removeAt(0);
    if (_wantsErase(e)) {
      _erasingNow = true;
      _eraseAt(e.localPosition, w);
      return;
    }
    _erasingNow = false;
    _current = Stroke(color: _highlighter ? _highs[_inks.indexOf(_color).clamp(0, _highs.length - 1)] : _color,
        width: _highlighter ? 14 : _width, highlighter: _highlighter);
    _addPoint(e, w);
  }

  void _move(PointerMoveEvent e, double w) {
    if (!_accept(e)) return;
    if (_erasingNow) {
      _eraseAt(e.localPosition, w);
      return;
    }
    if (_current == null) return;
    _addPoint(e, w);
  }

  void _up(PointerEvent e) {
    if (_current != null && _current!.pts.length >= 3) {
      setState(() {
        _strokes.add(_current!);
        _current = null;
        _dirty = true;
      });
    } else {
      setState(() => _current = null);
    }
    _erasingNow = false;
    _save();
  }

  void _addPoint(PointerEvent e, double w) {
    final p = e.kind == PointerDeviceKind.stylus ? (e.pressure > 0 ? e.pressure : 0.5) : 0.5;
    setState(() => _current!.pts.addAll([e.localPosition.dx / w, e.localPosition.dy / w, p.clamp(0.05, 1.0)]));
  }

  void _eraseAt(Offset o, double w) {
    final x = o.dx / w, y = o.dy / w;
    const r = 0.018;
    final before = _strokes.length;
    _strokes.removeWhere((s) {
      for (var i = 0; i + 1 < s.pts.length; i += 3) {
        final dx = s.pts[i] - x, dy = s.pts[i + 1] - y;
        if (dx * dx + dy * dy < r * r) return true;
      }
      return false;
    });
    if (_strokes.length != before) {
      setState(() => _dirty = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final n = widget.note;
    final title = n.title.isEmpty ? (NoteMeta.kinds[n.kind] ?? 'Page') : n.title;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Annuler',
            onPressed: _undo.isEmpty
                ? null
                : () => setState(() {
                      _strokes = _undo.removeLast();
                      _dirty = true;
                      _save();
                    }),
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Tout effacer',
            onPressed: () => setState(() {
              _undo.add(List.of(_strokes));
              _strokes = [];
              _dirty = true;
              _save();
            }),
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final c in _inks)
                    _tool(
                      selected: !_eraser && _color == c,
                      onTap: () => setState(() {
                        _color = c;
                        _eraser = false;
                      }),
                      child: Container(width: 22, height: 22, decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle)),
                      label: 'Encre',
                    ),
                  const SizedBox(width: 6),
                  _tool(
                    selected: !_eraser && !_highlighter && _width < 2,
                    onTap: () => setState(() {
                      _width = 1.4;
                      _highlighter = false;
                      _eraser = false;
                    }),
                    child: const Icon(Icons.edit_rounded, size: 18, color: K.ink),
                    label: 'Fin',
                  ),
                  _tool(
                    selected: !_eraser && !_highlighter && _width >= 2,
                    onTap: () => setState(() {
                      _width = 2.6;
                      _highlighter = false;
                      _eraser = false;
                    }),
                    child: const Icon(Icons.brush_rounded, size: 20, color: K.ink),
                    label: 'Épais',
                  ),
                  _tool(
                    selected: _highlighter && !_eraser,
                    onTap: () => setState(() {
                      _highlighter = true;
                      _eraser = false;
                    }),
                    child: const Icon(Icons.highlight_rounded, size: 20, color: K.gold),
                    label: 'Surligneur',
                  ),
                  _tool(
                    selected: _eraser,
                    onTap: () => setState(() => _eraser = !_eraser),
                    child: const Icon(Icons.cleaning_services_rounded, size: 20, color: K.pink),
                    label: 'Gomme',
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    label: const Text('Doigt aussi'),
                    selected: !store.settings.stylusOnly,
                    onSelected: (v) async {
                      store.settings.stylusOnly = !v;
                      await store.updateSettings();
                    },
                    selectedColor: K.cyan,
                    backgroundColor: K.raised,
                    side: BorderSide.none,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: LayoutBuilder(builder: (context, c) {
                  final w = c.maxWidth;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: const Color(0xFFF7F4EA),
                      child: !_loaded
                          ? const Center(child: CircularProgressIndicator())
                          : Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: (e) => _down(e, w),
                              onPointerMove: (e) => _move(e, w),
                              onPointerUp: _up,
                              onPointerCancel: _up,
                              child: Stack(
                                children: [
                                  Positioned.fill(child: CustomPaint(painter: _LinesPainter())),
                                  Positioned.fill(
                                    child: RepaintBoundary(
                                      child: CustomPaint(painter: _StrokesPainter(_strokes, null, version: _strokes.length)),
                                    ),
                                  ),
                                  Positioned.fill(child: CustomPaint(painter: _StrokesPainter(const [], _current, version: _current?.pts.length ?? 0))),
                                ],
                              ),
                            ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tool({required bool selected, required VoidCallback onTap, required Widget child, required String label}) =>
      Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? K.raised : K.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? K.lime : K.line, width: 2),
            ),
            child: child,
          ),
        ),
      );
}

class _LinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFDCD6C3)
      ..strokeWidth = 1;
    final gap = size.width / 26;
    for (var y = gap * 2; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _StrokesPainter extends CustomPainter {
  final List<Stroke> strokes;
  final Stroke? current;
  final int version;
  _StrokesPainter(this.strokes, this.current, {this.version = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final scale = w / 700; // épaisseur proportionnelle à la largeur de la page
    void draw(Stroke s) {
      final paint = Paint()
        ..color = Color(s.color)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      if (s.highlighter) paint.blendMode = BlendMode.multiply;
      final p = s.pts;
      if (p.length < 3) return;
      if (p.length == 3) {
        canvas.drawCircle(Offset(p[0] * w, p[1] * w), s.width * scale, paint..style = PaintingStyle.fill);
        return;
      }
      for (var i = 0; i + 5 < p.length; i += 3) {
        final pressure = s.highlighter ? 1.0 : (p[i + 2] + p[i + 5]) / 2;
        paint.strokeWidth = max(0.6, s.width * scale * (0.35 + 1.3 * pressure));
        canvas.drawLine(Offset(p[i] * w, p[i + 1] * w), Offset(p[i + 3] * w, p[i + 4] * w), paint);
      }
    }

    for (final s in strokes) {
      draw(s);
    }
    if (current != null) draw(current!);
  }

  @override
  bool shouldRepaint(covariant _StrokesPainter old) =>
      old.version != version || old.strokes != strokes || old.current != current || current != null;
}
