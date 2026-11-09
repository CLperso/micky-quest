import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart' as mk;

import 'guides.dart';
import 'ink.dart';
import 'model.dart';
import 'store.dart';
import 'theme.dart';

const pageW = 600.0;
const pageH = 860.0;

enum Mode { use, pen, deco }

/// L'état de l'atelier : mode, outil, élément sélectionné, page visée.
class Desk extends ChangeNotifier {
  Mode mode = Mode.use;
  String selected = '';
  String focusPage = '';
  Map<String, dynamic>? washi; // rouleau armé : on le tire sur la page
  String tool = 'stylo'; // une pointe, ou gomme, lasso, forme
  String shape = 'ligne';
  int penColor = 0xFF4A3F3C;
  final Map<String, double> _widths = {};
  double eraserSize = 12;
  bool eraseWhole = false;
  final Map<String, int> inkFrom = {}; // page → premier trait pas encore converti en texte
  String selPage = '';
  List<Stroke> sel = [];
  Rect? _selBox;

  bool textEraser = false; // gomme à texte (mode ✋)
  void toggleTextEraser() {
    textEraser = !textEraser;
    notifyListeners();
  }

  void setMode(Mode m) {
    mode = m;
    textEraser = false;
    selected = '';
    washi = null;
    clearSel(notify: false);
    notifyListeners();
  }

  void select(String id) {
    selected = id;
    notifyListeners();
  }

  void focus(String page) {
    if (focusPage == page) return;
    focusPage = page;
    notifyListeners();
  }

  void arm(Map<String, dynamic>? w) {
    washi = w;
    selected = '';
    notifyListeners();
  }

  void setTool(String t) {
    tool = t;
    if (t != 'lasso') clearSel(notify: false);
    notifyListeners();
  }

  void setShape(String s) {
    shape = s;
    notifyListeners();
  }

  void setColor(int c) {
    penColor = c;
    if (tool == 'gomme' || tool == 'lasso') tool = 'stylo';
    notifyListeners();
  }

  double widthOf(String nib) => _widths[nib] ?? nibOf(nib).width;
  void setWidth(String nib, double w) {
    _widths[nib] = w;
    notifyListeners();
  }

  void setEraser(double v) {
    eraserSize = v;
    notifyListeners();
  }

  void toggleEraseWhole() {
    eraseWhole = !eraseWhole;
    notifyListeners();
  }

  void setSel(String page, List<Stroke> l) {
    selPage = page;
    sel = l;
    _selBox = l.isEmpty ? null : strokesBounds(l);
    notifyListeners();
  }

  void refreshSel() {
    _selBox = sel.isEmpty ? null : strokesBounds(sel);
    notifyListeners();
  }

  Rect? selBox(String page) => page == selPage ? _selBox : null;

  void clearSel({bool notify = true}) {
    sel = [];
    selPage = '';
    _selBox = null;
    if (notify) notifyListeners();
  }

  void set() => notifyListeners();
}

class DeskScope extends InheritedNotifier<Desk> {
  const DeskScope({super.key, required Desk desk, required super.child}) : super(notifier: desk);
  static Desk of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<DeskScope>()!.notifier!;
}

class _Scale extends InheritedWidget {
  final double scale;
  const _Scale({required this.scale, required super.child});
  static double of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<_Scale>()?.scale ?? 1;
  @override
  bool updateShouldNotify(_Scale old) => old.scale != scale;
}

/// Une page du carnet : papier, contenu, décoration libre, encre.
class PageSheet extends StatefulWidget {
  final String pageKey;
  final Widget child;
  final double tilt;
  final void Function(List<String> lines)? onInkLines;
  final bool flat; // dans l'agenda : pas d'ombre, coins discrets
  final bool ornaments;
  final bool bare; // sans marges (couverture)
  final Color? paperOverride;
  const PageSheet(
      {super.key, required this.pageKey, required this.child, this.tilt = 0, this.onInkLines, this.flat = false, this.ornaments = true, this.bare = false, this.paperOverride});

  @override
  State<PageSheet> createState() => _PageSheetState();
}

class _PageSheetState extends State<PageSheet> {
  Offset? _washiA, _washiB;

  Future<void> _endWashi(Store store, Desk desk) async {
    final a = _washiA, b = _washiB, w = desk.washi;
    setState(() {
      _washiA = null;
      _washiB = null;
    });
    if (a == null || b == null || w == null) return;
    final len = (b - a).distance;
    if (len < 24) return;
    final d = Deco(
      page: widget.pageKey,
      type: 'washi',
      x: (a.dx + b.dx) / 2,
      y: (a.dy + b.dy) / 2,
      w: len,
      h: (w['h'] as num?)?.toDouble() ?? 26,
      rot: atan2(b.dy - a.dy, b.dx - a.dx),
      style: Map<String, dynamic>.from(w)..remove('h'),
    );
    await store.addDeco(d);
    desk.select(d.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final desk = DeskScope.of(context);
    final pal = Pal.byId(store.settings.theme);
    final paper = store.paper(widget.pageKey);
    final decos = store.pageDecos(widget.pageKey);
    final focused = desk.focusPage == widget.pageKey && desk.mode != Mode.use;
    if (widget.ornaments && !widget.bare && !store.seeded.contains(widget.pageKey)) {
      final key = widget.pageKey;
      WidgetsBinding.instance.addPostFrameCallback((_) => store.seedPage(key, seedDoodles(key, store.settings.decoLevel)));
    }
    final paperColor = widget.paperOverride ?? (paper.color == 0 ? pal.paper : Color(paper.color));
    final right = widget.pageKey.endsWith(':R');
    final darkPaper = paperColor.computeLuminance() < 0.3;

    final sheet = Stack(clipBehavior: Clip.none, children: [
      // papier
      Positioned.fill(
        child: Container(
          decoration: BoxDecoration(
            color: paperColor,
            borderRadius: BorderRadius.circular(widget.flat ? 8 : 12),
            border: focused ? Border.all(color: pal.acc.withValues(alpha: 0.45), width: 2.5) : null,
            boxShadow: widget.flat ? null : const [BoxShadow(color: Color(0x33000000), blurRadius: 22, offset: Offset(0, 6))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.flat ? 8 : 12),
            child: CustomPaint(painter: _PaperPainter(paper.pattern, darkPaper ? pal.line : (paper.color == 0 ? pal.dot : Color.alphaBlend(const Color(0x22000000), paperColor)))),
          ),
        ),
      ),
      // contenu
      Positioned.fill(
        child: IgnorePointer(
          ignoring: desk.mode != Mode.use,
          child: Listener(
            onPointerDown: (_) => desk.focus(widget.pageKey),
            child: widget.bare ? widget.child : Padding(padding: const EdgeInsets.fromLTRB(34, 30, 34, 26), child: widget.child),
          ),
        ),
      ),
      // fond cliquable en mode déco : désélectionner, ou tirer un washi
      if (desk.mode == Mode.deco)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (_) => desk.focus(widget.pageKey),
            onTap: () => desk.select(''),
            onPanStart: desk.washi == null
                ? null
                : (d) => setState(() {
                      desk.focus(widget.pageKey);
                      _washiA = d.localPosition;
                      _washiB = d.localPosition;
                    }),
            onPanUpdate: desk.washi == null ? null : (d) => setState(() => _washiB = d.localPosition),
            onPanEnd: desk.washi == null ? null : (_) => _endWashi(store, desk),
          ),
        ),
      // décoration
      for (final d in decos)
        _DecoView(key: ValueKey(d.id), deco: d, locked: desk.mode != Mode.deco, selected: desk.mode == Mode.deco && desk.selected == d.id),
      // washi en train d'être tiré
      if (_washiA != null && _washiB != null && desk.washi != null)
        Builder(builder: (_) {
          final a = _washiA!, b = _washiB!;
          final len = max(1.0, (b - a).distance);
          final h = (desk.washi!['h'] as num?)?.toDouble() ?? 26;
          return Positioned(
            left: (a.dx + b.dx) / 2 - len / 2,
            top: (a.dy + b.dy) / 2 - h / 2,
            width: len,
            height: h,
            child: IgnorePointer(child: Transform.rotate(angle: atan2(b.dy - a.dy, b.dx - a.dx), child: renderDeco(Deco(page: '', type: 'washi', w: len, h: h, style: desk.washi), store))),
          );
        }),
      // calque d'aide, sous l'encre
      Positioned.fill(child: GuideLayer(page: widget.pageKey)),
      // encre
      Positioned.fill(child: InkLayer(pageKey: widget.pageKey)),
      // barre de l'élément sélectionné
      if (desk.mode == Mode.deco && desk.selected.isNotEmpty && decos.any((d) => d.id == desk.selected))
        Positioned(top: 8, left: 0, right: 0, child: Center(child: _DecoBar(deco: decos.firstWhere((d) => d.id == desk.selected)))),
      if (desk.mode == Mode.deco && desk.washi != null && focused)
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: IgnorePointer(child: Center(child: _hint('Tire le washi sur la page, du début à la fin', pal))),
        ),
    ]);

    return Transform.rotate(
      angle: widget.tilt * pi / 180,
      child: AspectRatio(
        aspectRatio: pageW / pageH,
        child: LayoutBuilder(builder: (context, box) {
          return FittedBox(
            child: SizedBox(width: pageW, height: pageH, child: _Scale(scale: box.maxWidth / pageW, child: sheet)),
          );
        }),
      ),
    );
  }

  Widget _hint(String t, Pal pal) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: pal.ink.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(999)),
        child: Text(t, style: body(14, pal.paper)),
      );
}

/// Reconnaissance de l'écriture (Android seulement) : les traits pas encore convertis deviennent des lignes de texte.
Future<List<String>?> recognizeInk(Store store, Desk desk, String page) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  final ink = store.inks[page];
  if (ink == null) return [];
  final from = (desk.inkFrom[page] ?? 0).clamp(0, ink.strokes.length);
  final todo = ink.strokes.sublist(from).where((s) => !s.hl).toList();
  if (todo.isEmpty) return [];
  try {
    const lang = 'fr';
    final manager = mk.DigitalInkRecognizerModelManager();
    if (!await manager.isModelDownloaded(lang)) {
      final ok = await manager.downloadModel(lang, isWifiRequired: false);
      if (!ok) return null;
    }
    final recognizer = mk.DigitalInkRecognizer(languageCode: lang);
    double cy(Stroke s) {
      var a = double.infinity, b = -double.infinity;
      for (var i = 1; i < s.pts.length; i += 3) {
        a = min(a, s.pts[i]);
        b = max(b, s.pts[i]);
      }
      return (a + b) / 2;
    }

    final groups = <List<Stroke>>[];
    final centers = <double>[];
    for (final s in [...todo]..sort((a, b) => cy(a).compareTo(cy(b)))) {
      final c = cy(s);
      if (centers.isNotEmpty && (c - centers.last).abs() < 22) {
        groups.last.add(s);
      } else {
        groups.add([s]);
        centers.add(c);
      }
    }
    final out = <String>[];
    var t = 0;
    for (final g in groups) {
      g.sort((a, b) => a.pts[0].compareTo(b.pts[0]));
      final mi = mk.Ink();
      mi.strokes = [
        for (final s in g)
          mk.Stroke()
            ..points = [
              for (var i = 0; i + 1 < s.pts.length; i += 3) mk.StrokePoint(x: s.pts[i] * 3, y: s.pts[i + 1] * 3, t: (t += 16))
            ]
      ];
      final c = await recognizer.recognize(mi);
      if (c.isNotEmpty && c.first.text.trim().isNotEmpty) out.add(c.first.text.trim());
    }
    await recognizer.close();
    store.snapshot(page);
    ink.strokes.removeWhere((s) => todo.contains(s));
    desk.inkFrom[page] = ink.strokes.length;
    await store.touchInk(page);
    return out;
  } catch (e) {
    debugPrint('Encre : $e');
    return null;
  }
}

const doodleKinds = [
  ('etincelle', 'Étincelle', 26.0, 26.0),
  ('etoile', 'Petite étoile', 14.0, 14.0),
  ('lune', 'Lune', 26.0, 26.0),
  ('branche', 'Branche', 300.0, 34.0),
  ('noeud', 'Nœud', 60.0, 46.0),
  ('coeurs', 'Cœurs', 74.0, 22.0),
];

/// Les petits dessins de déco (étoiles, lune, branche, nœud, cœurs) : de vrais stickers.
class DoodlePainter extends CustomPainter {
  final String kind;
  final Pal pal;
  final int? color;
  DoodlePainter(this.kind, this.pal, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final o = Ornaments(1, pal, false);
    final w = size.width, h = size.height;
    final c = color == null ? null : Color(color!);
    final gold = Paint()
      ..color = c ?? pal.acc3
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    switch (kind) {
      case 'etincelle':
        o._spark(canvas, Offset(w / 2, h / 2), min(w, h) / 2 - 1, gold);
        break;
      case 'etoile':
        o._spark(canvas, Offset(w / 2, h / 2), min(w, h) / 2, Paint()..color = c ?? pal.acc3);
        break;
      case 'lune':
        canvas.drawPath(Path()..addArc(Rect.fromCircle(center: Offset(w / 2, h / 2), radius: min(w, h) / 2 - 2), -pi / 2.2, pi * 1.3), gold..strokeWidth = 1.6);
        break;
      case 'branche':
        final stem = Paint()
          ..color = pal.soft.withValues(alpha: .8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1;
        o._vine(canvas, Offset(0, h / 2), w - 14, stem, Paint()..color = (c ?? pal.acc2).withValues(alpha: .55));
        break;
      case 'noeud':
        final k = min(w / 60, h / 46);
        o._bow(canvas, Offset(w / 2, h * 0.36), k, Paint()..color = c ?? pal.tint, Paint()
          ..color = pal.acc
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3);
        break;
      case 'coeurs':
        for (var i = 0; i < 3; i++) {
          final cx = w / 6 + i * w / 3, cy = h / 2;
          final s = min(w / 3, h) / 14;
          final heart = Path()
            ..moveTo(cx, cy + 6 * s)
            ..cubicTo(cx - 7 * s, cy + 1 * s, cx - 8 * s, cy - 4 * s, cx - 4.5 * s, cy - 5.5 * s)
            ..cubicTo(cx - 2 * s, cy - 7 * s, cx, cy - 4.5 * s, cx, cy - 3 * s)
            ..cubicTo(cx, cy - 4.5 * s, cx + 2 * s, cy - 7 * s, cx + 4.5 * s, cy - 5.5 * s)
            ..cubicTo(cx + 8 * s, cy - 4 * s, cx + 7 * s, cy + 1 * s, cx, cy + 6 * s)
            ..close();
          canvas.drawPath(heart, Paint()..color = c ?? (i.isEven ? pal.acc : pal.tint));
        }
        break;
    }
  }

  @override
  bool shouldRepaint(DoodlePainter o) => o.kind != kind || o.pal != pal || o.color != color;
}

/// Les petits dessins posés d'office sur une nouvelle page, selon le niveau de déco.
List<Deco> seedDoodles(String page, double level) {
  if (level <= 0.3) return [];
  final right = page.endsWith(':R');
  final l = <Deco>[
    Deco(page: page, type: 'doodle', x: pageW - (right ? 54 : 92), y: right ? 46 : 40, w: 18, h: 18, style: {'kind': 'etincelle'}),
    Deco(page: page, type: 'doodle', x: pageW - (right ? 36 : 70), y: right ? 66 : 60, w: 8, h: 8, style: {'kind': 'etoile'}),
    if (!right) Deco(page: page, type: 'doodle', x: pageW - 46, y: 38, w: 22, h: 22, style: {'kind': 'lune'}),
    Deco(page: page, type: 'doodle', x: pageW / 2, y: pageH - 32, w: pageW * (right ? 0.5 : 0.6), h: 30, style: {'kind': 'branche'}),
  ];
  if (level > 1.4) {
    l.add(Deco(page: page, type: 'doodle', x: right ? pageW - 40 : 44, y: pageH - 64, w: 60, h: 46, style: {'kind': 'noeud'}));
    l.add(Deco(page: page, type: 'doodle', x: right ? 70 : pageW - 88, y: 22, w: 74, h: 22, style: {'kind': 'coeurs'}));
  }
  return l;
}

/// Étoiles, lune, feuillage et nœud dessinés sur la page (niveau de déco).
class Ornaments extends CustomPainter {
  final double level;
  final Pal pal;
  final bool right;
  Ornaments(this.level, this.pal, this.right);

  void _spark(Canvas c, Offset o, double s, Paint p) {
    final path = Path()
      ..moveTo(o.dx, o.dy - s)
      ..quadraticBezierTo(o.dx + s * .15, o.dy - s * .15, o.dx + s, o.dy)
      ..quadraticBezierTo(o.dx + s * .15, o.dy + s * .15, o.dx, o.dy + s)
      ..quadraticBezierTo(o.dx - s * .15, o.dy + s * .15, o.dx - s, o.dy)
      ..quadraticBezierTo(o.dx - s * .15, o.dy - s * .15, o.dx, o.dy - s)
      ..close();
    c.drawPath(path, p);
  }

  void _vine(Canvas c, Offset a, double len, Paint stem, Paint leaf) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(a.dx + len * .3, a.dy - 8, a.dx + len * .6, a.dy + 8, a.dx + len, a.dy);
    c.drawPath(path, stem);
    for (var i = 1; i < 7; i++) {
      final x = a.dx + len * i / 7;
      final d = i.isOdd ? -1.0 : 1.0;
      final l = Path()
        ..moveTo(x, a.dy)
        ..quadraticBezierTo(x + 6, a.dy - 10 * d, x + 13, a.dy - 11 * d)
        ..quadraticBezierTo(x + 5, a.dy - 3 * d, x, a.dy)
        ..close();
      c.drawPath(l, leaf);
      c.drawPath(l, stem);
    }
  }

  void _bow(Canvas c, Offset o, double k, Paint fill, Paint line) {
    for (final sgn in [-1.0, 1.0]) {
      final w = Path()
        ..moveTo(o.dx, o.dy)
        ..cubicTo(o.dx + sgn * 14 * k, o.dy - 14 * k, o.dx + sgn * 28 * k, o.dy - 8 * k, o.dx + sgn * 24 * k, o.dy + 2 * k)
        ..cubicTo(o.dx + sgn * 20 * k, o.dy + 12 * k, o.dx + sgn * 8 * k, o.dy + 6 * k, o.dx, o.dy)
        ..close();
      c.drawPath(w, fill);
      c.drawPath(w, line);
      final t = Path()
        ..moveTo(o.dx + sgn * 2 * k, o.dy + 2 * k)
        ..lineTo(o.dx + sgn * 10 * k, o.dy + 20 * k)
        ..lineTo(o.dx + sgn * 5 * k, o.dy + 18 * k)
        ..lineTo(o.dx + sgn * 3 * k, o.dy + 24 * k)
        ..close();
      c.drawPath(t, fill);
      c.drawPath(t, line);
    }
    c.drawCircle(o.translate(0, 1), 5 * k, fill);
    c.drawCircle(o.translate(0, 1), 5 * k, line);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..color = pal.acc3
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final goldFill = Paint()..color = pal.acc3;
    final stem = Paint()
      ..color = pal.soft.withValues(alpha: .8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final leaf = Paint()..color = pal.acc2.withValues(alpha: .55);
    final w = size.width, h = size.height;
    if (!right) {
      _spark(canvas, Offset(w - 92, 40), 8, gold);
      _spark(canvas, Offset(w - 70, 60), 4, goldFill);
      final moon = Path()
        ..addArc(Rect.fromCircle(center: Offset(w - 46, 38), radius: 9), -pi / 2.2, pi * 1.3);
      canvas.drawPath(moon, gold);
      _vine(canvas, Offset(w * .2, h - 34), w * .6, stem, leaf);
    } else {
      _spark(canvas, Offset(w - 54, 46), 7, gold);
      _spark(canvas, Offset(w - 36, 66), 3.5, goldFill);
      _vine(canvas, Offset(w * .25, h - 30), w * .5, stem, leaf);
    }
    if (level > 1.4) {
      final fill = Paint()..color = pal.tint;
      final line = Paint()
        ..color = pal.acc
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3;
      _bow(canvas, Offset(right ? w - 40 : 44, right ? h - 70 : h - 72), 1.0, fill, line);
      for (var i = 0; i < 3; i++) {
        final o = Offset((right ? 36.0 : w - 110) + i * 22, 22);
        final heart = Path()
          ..moveTo(o.dx, o.dy + 6)
          ..cubicTo(o.dx - 7, o.dy + 1, o.dx - 8, o.dy - 4, o.dx - 4.5, o.dy - 5.5)
          ..cubicTo(o.dx - 2, o.dy - 7, o.dx, o.dy - 4.5, o.dx, o.dy - 3)
          ..cubicTo(o.dx, o.dy - 4.5, o.dx + 2, o.dy - 7, o.dx + 4.5, o.dy - 5.5)
          ..cubicTo(o.dx + 8, o.dy - 4, o.dx + 7, o.dy + 1, o.dx, o.dy + 6)
          ..close();
        canvas.drawPath(heart, Paint()..color = (i.isEven ? pal.acc : pal.tint));
      }
    }
  }

  @override
  bool shouldRepaint(Ornaments o) => o.level != level || o.pal != pal || o.right != right;
}

class _PaperPainter extends CustomPainter {
  final String pattern;
  final Color c;
  _PaperPainter(this.pattern, this.c);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = c;
    const step = 20.0;
    if (pattern == 'dots') {
      for (var x = step; x < size.width; x += step) {
        for (var y = step; y < size.height; y += step) {
          canvas.drawCircle(Offset(x, y), 1.3, p);
        }
      }
    } else if (pattern == 'lines') {
      p.strokeWidth = 1;
      for (var y = 60.0; y < size.height; y += 28) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      }
    } else if (pattern == 'grid') {
      p.strokeWidth = 0.8;
      for (var x = step; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      }
      for (var y = step; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      }
    }
  }

  @override
  bool shouldRepaint(_PaperPainter o) => o.pattern != pattern || o.c != c;
}

/// Dessin d'un élément de décoration à sa taille.
Widget renderDeco(Deco d, Store store) {
  final s = d.style;
  int col(String k, int def) => (s[k] as num?)?.toInt() ?? def;
  switch (d.type) {
    case 'washi':
      return CustomPaint(size: Size(d.w, d.h), painter: WashiPainter(Color(col('color', 0xFFE8896B)), (s['pattern'] as String?) ?? 'stripes', (s['opacity'] as num?)?.toDouble() ?? 0.75));
    case 'emoji':
      return FittedBox(child: Text((s['emoji'] as String?) ?? '⭐', style: const TextStyle(fontSize: 120)));
    case 'doodle':
      return CustomPaint(size: Size(d.w, d.h), painter: DoodlePainter((s['kind'] as String?) ?? 'etincelle', Pal.byId(store.settings.theme), (s['color'] as num?)?.toInt()));
    case 'text':
      final bg = s['bg'] as num?;
      return Container(
        decoration: bg == null ? null : BoxDecoration(color: Color(bg.toInt()), borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(horizontal: bg == null ? 0 : 10),
        alignment: Alignment.center,
        child: FittedBox(
          child: Text((s['text'] as String?) ?? 'Titre',
              style: (s['font'] == 'title' ? titleFont(60, Color(col('color', 0xFF3B3346))) : hand(70, Color(col('color', 0xFF3B3346))))),
        ),
      );
    case 'frame':
      return CustomPaint(
        size: Size(d.w, d.h),
        painter: FramePainter((s['pattern'] as String?) ?? 'solid', Color(col('color', 0xFFE8896B)), s['fill'] == null ? null : Color(col('fill', 0))),
      );
    case 'sticker':
    case 'image':
      final shape = (s['shape'] as String?) ?? 'round';
      Widget img;
      if (d.type == 'sticker') {
        img = Image.asset('assets/micky/${s['asset'] ?? 'm01'}.jpg', fit: BoxFit.cover, width: d.w, height: d.h);
      } else {
        final b = store.images[s['img']];
        img = b == null ? Container(color: const Color(0x22000000)) : Image.memory(base64Decode(b), fit: BoxFit.cover, width: d.w, height: d.h, gaplessPlayback: true);
      }
      final border = Color(col('border', 0xFFFFFFFF));
      const shadow = [BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 3))];
      if (shape == 'round') {
        return Container(
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: border, width: 6), boxShadow: shadow),
          child: ClipOval(child: img),
        );
      }
      if (shape == 'polaroid') {
        return Container(
          padding: EdgeInsets.fromLTRB(d.w * 0.06, d.w * 0.06, d.w * 0.06, s['text'] == null ? d.w * 0.2 : 0),
          decoration: BoxDecoration(color: border, boxShadow: shadow),
          child: Column(children: [
            Expanded(child: SizedBox(width: double.infinity, child: img)),
            if (s['text'] != null)
              SizedBox(
                height: d.w * 0.2,
                child: Center(child: FittedBox(child: Text(s['text'] as String, style: hand(40, const Color(0xFF555555))))),
              ),
          ]),
        );
      }
      if (shape == 'plain') return img;
      return Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: border, width: 5), boxShadow: shadow),
        child: ClipRRect(borderRadius: BorderRadius.circular(9), child: img),
      );
  }
  return const SizedBox();
}

class WashiPainter extends CustomPainter {
  final Color c;
  final String pattern;
  final double opacity;
  WashiPainter(this.c, this.pattern, this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // bords déchirés
    final path = Path()..moveTo(0, 0);
    const teeth = 4.0;
    path.lineTo(w, 0);
    for (var y = 0.0; y < h; y += teeth * 2) {
      path.lineTo(w - teeth, min(h, y + teeth));
      path.lineTo(w, min(h, y + teeth * 2));
    }
    path.lineTo(0, h);
    for (var y = h; y > 0; y -= teeth * 2) {
      path.lineTo(teeth, max(0, y - teeth));
      path.lineTo(0, max(0, y - teeth * 2));
    }
    path.close();
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(Offset.zero & size, Paint()..color = c.withValues(alpha: opacity * 0.55));
    final p = Paint()..color = c.withValues(alpha: opacity);
    switch (pattern) {
      case 'stripes':
        p.strokeWidth = 6;
        for (var x = -h; x < w + h; x += 14) {
          canvas.drawLine(Offset(x, h), Offset(x + h, 0), p);
        }
        break;
      case 'dots':
        for (var x = 8.0; x < w; x += 14) {
          for (var y = 7.0; y < h; y += 12) {
            canvas.drawCircle(Offset(x + ((y ~/ 12) % 2) * 7, y), 2.6, p);
          }
        }
        break;
      case 'grid':
        p.strokeWidth = 1.6;
        for (var x = 0.0; x < w; x += 10) {
          canvas.drawLine(Offset(x, 0), Offset(x, h), p);
        }
        for (var y = 0.0; y < h; y += 10) {
          canvas.drawLine(Offset(0, y), Offset(w, y), p);
        }
        break;
      case 'zigzag':
        p
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        final z = Path()..moveTo(0, h * .7);
        var up = true;
        for (var x = 0.0; x <= w; x += 10) {
          z.lineTo(x, up ? h * .3 : h * .7);
          up = !up;
        }
        canvas.drawPath(z, p);
        break;
      case 'check':
        for (var x = 0.0; x < w; x += 12) {
          for (var y = 0.0; y < h; y += 12) {
            if (((x ~/ 12) + (y ~/ 12)) % 2 == 0) canvas.drawRect(Rect.fromLTWH(x, y, 12, 12), p);
          }
        }
        break;
      default:
        canvas.drawRect(Offset.zero & size, p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(WashiPainter o) => o.c != c || o.pattern != pattern || o.opacity != opacity;
}

class FramePainter extends CustomPainter {
  final String pattern;
  final Color c;
  final Color? fill;
  FramePainter(this.pattern, this.c, this.fill);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final p = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final f = fill == null ? null : (Paint()..color = fill!);
    switch (pattern) {
      case 'dashed':
        if (f != null) canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), f);
        final path = Path()..addRRect(RRect.fromRectAndRadius(r.deflate(2), const Radius.circular(6)));
        for (final m in path.computeMetrics()) {
          for (var d = 0.0; d < m.length; d += 16) {
            canvas.drawPath(m.extractPath(d, min(d + 9, m.length)), p);
          }
        }
        break;
      case 'double':
        if (f != null) canvas.drawRect(r, f);
        canvas.drawRect(r.deflate(2), p);
        canvas.drawRect(r.deflate(9), p..strokeWidth = 1.5);
        break;
      case 'rounded':
        if (f != null) canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(26)), f);
        canvas.drawRRect(RRect.fromRectAndRadius(r.deflate(2), const Radius.circular(26)), p);
        break;
      case 'tag':
        final path = Path()
          ..moveTo(size.height * .35, 2)
          ..lineTo(size.width - 2, 2)
          ..lineTo(size.width - 2, size.height - 2)
          ..lineTo(size.height * .35, size.height - 2)
          ..lineTo(2, size.height / 2)
          ..close();
        canvas.drawPath(path, f ?? (Paint()..color = c.withValues(alpha: 0.15)));
        canvas.drawPath(path, p);
        canvas.drawCircle(Offset(size.height * .32, size.height / 2), 5, p);
        break;
      case 'bubble':
        final body = RRect.fromRectAndRadius(Rect.fromLTWH(2, 2, size.width - 4, size.height * .8), const Radius.circular(22));
        final path = Path()
          ..addRRect(body)
          ..moveTo(size.width * .22, size.height * .8)
          ..lineTo(size.width * .16, size.height - 2)
          ..lineTo(size.width * .34, size.height * .8);
        canvas.drawPath(path, f ?? (Paint()..color = Colors.white.withValues(alpha: 0.8)));
        canvas.drawPath(path, p);
        break;
      case 'polaroid':
        final b = size.width * .06;
        final outer = Path()..addRect(r);
        final inner = Path()..addRect(Rect.fromLTRB(b, b, size.width - b, size.height - size.width * .2));
        canvas.drawShadow(outer, Colors.black, 4, false);
        canvas.drawPath(Path.combine(PathOperation.difference, outer, inner), Paint()..color = fill ?? Colors.white);
        canvas.drawRect(r, p..strokeWidth = 1..color = c.withValues(alpha: 0.4));
        break;
      case 'corners':
        final k = min(size.width, size.height) * .16;
        final cp = Paint()..color = c;
        for (final (o, a, b) in [
          (r.topLeft, const Offset(1, 0), const Offset(0, 1)),
          (r.topRight, const Offset(-1, 0), const Offset(0, 1)),
          (r.bottomLeft, const Offset(1, 0), const Offset(0, -1)),
          (r.bottomRight, const Offset(-1, 0), const Offset(0, -1)),
        ]) {
          canvas.drawPath(Path()..moveTo(o.dx, o.dy)..lineTo(o.dx + a.dx * k, o.dy + a.dy * k)..lineTo(o.dx + b.dx * k, o.dy + b.dy * k)..close(), cp);
        }
        break;
      default:
        if (f != null) canvas.drawRect(r, f);
        canvas.drawRect(r.deflate(1.5), p);
    }
  }

  @override
  bool shouldRepaint(FramePainter o) => o.pattern != pattern || o.c != c || o.fill != fill;
}

/// Un élément posé : déplacer, tourner, agrandir (aux doigts ou avec les poignées).
class _DecoView extends StatefulWidget {
  final Deco deco;
  final bool selected, locked;
  const _DecoView({super.key, required this.deco, required this.selected, this.locked = false});
  @override
  State<_DecoView> createState() => _DecoViewState();
}

class _DecoViewState extends State<_DecoView> {
  Offset? _last;
  double _w0 = 0, _h0 = 0, _r0 = 0;
  bool _snap = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final desk = DeskScope.of(context);
    final d = widget.deco;
    // un élément sorti de la page revient au bord, pour qu'on puisse toujours le toucher
    d.x = d.x.clamp(8.0, pageW - 8);
    d.y = d.y.clamp(8.0, pageH - 8);
    final scale = _Scale.of(context);
    final pal = Pal.byId(store.settings.theme);

    void begin() {
      if (!_snap) {
        store.snapshot(d.page);
        _snap = true;
      }
    }

    const m = 64.0; // marge pour les poignées (dans la zone touchable)
    return Positioned(
      left: d.x - d.w / 2 - m,
      top: d.y - d.h / 2 - m,
      width: d.w + 2 * m,
      height: d.h + 2 * m,
      child: IgnorePointer(
        ignoring: widget.locked,
        child: Transform.rotate(
        angle: d.rot,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: m,
            top: m,
            width: d.w,
            height: d.h,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (desk.washi != null) desk.arm(null);
                desk.focus(d.page);
                desk.select(d.id);
              },
              onLongPress: () async {
                desk.select(d.id);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Enlever cet élément ?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Garder')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enlever')),
                    ],
                  ),
                );
                if (ok == true) {
                  desk.select('');
                  await store.removeDeco(d);
                }
              },
              onScaleStart: (e) {
                if (desk.washi != null) desk.arm(null);
                desk.focus(d.page);
                if (desk.selected != d.id) desk.select(d.id);
                _last = e.focalPoint;
                _w0 = d.w;
                _h0 = d.h;
                _r0 = d.rot;
                _snap = false;
              },
              onScaleUpdate: (e) {
                begin();
                final last = _last ?? e.focalPoint;
                final delta = (e.focalPoint - last) / scale;
                _last = e.focalPoint;
                d.x = (d.x + delta.dx).clamp(8.0, pageW - 8);
                d.y = (d.y + delta.dy).clamp(8.0, pageH - 8);
                if (e.pointerCount >= 2) {
                  d.w = max(20, _w0 * e.scale);
                  d.h = d.type == 'washi' ? _h0 : max(20, _h0 * e.scale);
                  d.rot = _r0 + e.rotation;
                }
                store.touchDeco(d, save: false);
              },
              onScaleEnd: (_) {
                _snap = false;
                store.touchDeco(d);
              },
              child: renderDeco(d, store),
            ),
          ),
          if (widget.selected) ...[
            Positioned(
              left: m - 6,
              top: m - 6,
              width: d.w + 12,
              height: d.h + 12,
              child: IgnorePointer(child: CustomPaint(painter: FramePainter('dashed', pal.acc, null))),
            ),
            // agrandir
            Positioned(
              left: m + d.w - 20,
              top: m + d.h - 20,
              child: GestureDetector(
                onPanStart: (_) => _snap = false,
                onPanUpdate: (e) {
                  begin();
                  d.w = max(20, d.w + e.delta.dx * 2);
                  d.h = max(12, d.h + e.delta.dy * 2);
                  final round = d.type == 'emoji' || (d.type == 'sticker' && (d.style['shape'] ?? 'round') == 'round');
                  if (round) d.h = d.w;
                  store.touchDeco(d, save: false);
                },
                onPanEnd: (_) => store.touchDeco(d),
                child: _handle(Icons.open_in_full_rounded, pal),
              ),
            ),
            // tourner
            Positioned(
              left: m + d.w / 2 - 20,
              top: m - 56,
              child: GestureDetector(
                onPanStart: (_) => _snap = false,
                onPanUpdate: (e) {
                  begin();
                  d.rot += e.delta.dx / (d.h / 2 + 56);
                  store.touchDeco(d, save: false);
                },
                onPanEnd: (_) => store.touchDeco(d),
                child: _handle(Icons.rotate_right_rounded, pal),
              ),
            ),
          ],
        ]),
      )),
    );
  }

  Widget _handle(IconData i, Pal pal) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: pal.acc, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
        child: Icon(i, color: Colors.white, size: 20),
      );
}

/// Les actions sur l'élément sélectionné.
class _DecoBar extends StatelessWidget {
  final Deco deco;
  const _DecoBar({required this.deco});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final desk = DeskScope.of(context);
    final d = deco;
    Widget b(String tip, IconData i, VoidCallback f) => IconButton(tooltip: tip, onPressed: f, icon: Icon(i, size: 24, color: const Color(0xFF3B3346)));
    final colorable = d.type == 'washi' || d.type == 'frame' || d.type == 'text' || d.type == 'sticker' || d.type == 'image' || d.type == 'doodle';
    return Material(
      color: Colors.white,
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (colorable)
            b('Couleur', Icons.palette_rounded, () async {
              final c = await pickColor(context, store, title: d.type == 'sticker' || d.type == 'image' ? 'Couleur du bord' : 'Couleur');
              if (c == null) return;
              store.snapshot(d.page);
              d.style[d.type == 'sticker' || d.type == 'image' ? 'border' : 'color'] = c;
              store.touchDeco(d);
            }),
          if (d.type == 'frame' || d.type == 'text')
            b('Fond', Icons.format_color_fill_rounded, () async {
              final c = await pickColor(context, store, title: 'Fond', allowNone: true);
              if (c == null) return;
              store.snapshot(d.page);
              final key = d.type == 'frame' ? 'fill' : 'bg';
              if (c == 0) {
                d.style.remove(key);
              } else {
                d.style[key] = (c & 0x00FFFFFF) | 0x66000000;
              }
              store.touchDeco(d);
            }),
          if (d.type == 'washi')
            b('Motif', Icons.texture_rounded, () {
              store.snapshot(d.page);
              final i = washiPatterns.indexOf((d.style['pattern'] as String?) ?? 'stripes');
              d.style['pattern'] = washiPatterns[(i + 1) % washiPatterns.length];
              store.touchDeco(d);
            }),
          if (d.type == 'frame')
            b('Style', Icons.crop_square_rounded, () {
              store.snapshot(d.page);
              final i = framePatterns.indexOf((d.style['pattern'] as String?) ?? 'solid');
              d.style['pattern'] = framePatterns[(i + 1) % framePatterns.length];
              store.touchDeco(d);
            }),
          if (d.type == 'sticker' || d.type == 'image')
            b('Forme', Icons.interests_rounded, () {
              store.snapshot(d.page);
              const shapes = ['round', 'polaroid', 'square', 'plain'];
              final i = shapes.indexOf((d.style['shape'] as String?) ?? 'round');
              d.style['shape'] = shapes[(i + 1) % shapes.length];
              if (d.style['shape'] == 'polaroid') d.h = d.w * 1.2;
              if (d.style['shape'] == 'round') d.h = d.w;
              store.touchDeco(d);
            }),
          if (d.type == 'text' || ((d.type == 'sticker' || d.type == 'image') && d.style['shape'] == 'polaroid'))
            b('Texte', Icons.edit_rounded, () async {
              final t = await askText(context, d.type == 'text' ? 'Texte' : 'Légende', initial: (d.style['text'] as String?) ?? '');
              if (t == null) return;
              store.snapshot(d.page);
              if (t.isEmpty && d.type != 'text') {
                d.style.remove('text');
              } else {
                d.style['text'] = t;
              }
              store.touchDeco(d);
            }),
          if (d.type == 'text')
            b('Police', Icons.font_download_rounded, () {
              store.snapshot(d.page);
              d.style['font'] = d.style['font'] == 'title' ? 'hand' : 'title';
              store.touchDeco(d);
            }),
          b('Devant', Icons.flip_to_front_rounded, () => store.toFront(d, true)),
          b('Derrière', Icons.flip_to_back_rounded, () => store.toFront(d, false)),
          b('Dupliquer', Icons.copy_rounded, () async {
            final c = d.copyTo(d.page, dx: 24, dy: 24);
            await store.addDeco(c);
            desk.select(c.id);
          }),
          b('Favori', Icons.favorite_border_rounded, () async {
            await store.saveFavorite(d);
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajouté aux favoris de l’atelier')));
          }),
          b('Supprimer', Icons.delete_outline_rounded, () {
            store.removeDeco(d);
            desk.select('');
          }),
        ]),
      ),
    );
  }
}

/// Choisir une couleur : ta palette, puis toutes les couleurs. 0 = aucune (si permis).
Future<int?> pickColor(BuildContext context, Store store, {String title = 'Couleur', bool allowNone = false}) {
  Widget dot(int c, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: Border.all(color: const Color(0x33000000), width: 2)),
        ),
      );
  return showModalBottomSheet<int>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: titleFont(20, const Color(0xFF3B3346))),
          const SizedBox(height: 8),
          Text('MA PALETTE', style: body(11, const Color(0xFF8B8197), w: FontWeight.w800)),
          Wrap(children: [
            for (final c in store.settings.palette) dot(c, () => Navigator.pop(ctx, c)),
            if (allowNone)
              GestureDetector(
                onTap: () => Navigator.pop(ctx, 0),
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0x55000000), width: 2)),
                  child: const Icon(Icons.block_rounded, size: 20, color: Color(0x88000000)),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          Text('TOUTES LES COULEURS', style: body(11, const Color(0xFF8B8197), w: FontWeight.w800)),
          Wrap(children: [for (final c in colorChoices) dot(c, () => Navigator.pop(ctx, c))]),
        ]),
      ),
    ),
  );
}

Future<String?> askText(BuildContext context, String title, {String initial = '', String hint = '', bool multi = false}) async {
  final c = TextEditingController(text: initial);
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        maxLines: multi ? 5 : 1,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: multi ? null : (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('OK')),
      ],
    ),
  );
  return r;
}

/// Image d'un sticker perso (déjà réduite par le sélecteur) encodée en base64.
String encodeImage(Uint8List bytes) => base64Encode(bytes);
