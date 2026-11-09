import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'canvas.dart';
import 'guides.dart';
import 'model.dart';
import 'store.dart';
import 'theme.dart';

/// Une pointe de stylo et son comportement.
class Nib {
  final String id, name;
  final double width; // épaisseur par défaut
  final double thinning; // effet de la pression sur l'épaisseur (0 = constante)
  final double streamline; // lissage des tremblements
  final double taperStart, taperEnd; // affinage aux extrémités (en px)
  final double alpha;
  final bool multiply; // repasser dessus fonce la couleur
  const Nib(this.id, this.name,
      {required this.width, this.thinning = 0.5, this.streamline = 0.5, this.taperStart = 0, this.taperEnd = 0, this.alpha = 1, this.multiply = false});
}

const nibs = [
  Nib('stylo', 'Stylo', width: 2.6, thinning: 0.45, streamline: 0.5, taperStart: 2, taperEnd: 8),
  Nib('plume', 'Plume', width: 5, thinning: 0.3, streamline: 0.55),
  Nib('feutre', 'Feutre', width: 4, thinning: 0, streamline: 0.15, multiply: true),
  Nib('pinceau', 'Pinceau', width: 10, thinning: 0.8, streamline: 0.5, taperStart: 18, taperEnd: 40, alpha: 0.9, multiply: true),
  Nib('aquarelle', 'Aquarelle', width: 16, thinning: 0.5, streamline: 0.45, taperStart: 10, taperEnd: 24, alpha: 0.42, multiply: true),
  Nib('crayon', 'Crayon', width: 2.2, thinning: 0.3, streamline: 0.4, alpha: 0.72),
  Nib('surligneur', 'Surligneur', width: 18, thinning: 0, streamline: 0.4, alpha: 0.38, multiply: true),
];

Nib nibOf(String id) => nibs.firstWhere((n) => n.id == id, orElse: () => nibs.first);

// ---------------------------------------------------------------- tracé
final _cache = Expando<Path>();

void invalidateStroke(Stroke s) => _cache[s] = null;

/// Contour d'un trait (forme pleine), à la manière de « perfect-freehand ».
Path strokeOutline(Stroke s) {
  final cached = _cache[s];
  if (cached != null) return cached;
  final p = _outline(s);
  _cache[s] = p;
  return p;
}

Path _outline(Stroke s) {
  final nib = nibOf(s.tool);
  final size = s.width;
  final raw = <Offset>[];
  final pr = <double>[];
  for (var i = 0; i + 2 < s.pts.length; i += 3) {
    raw.add(Offset(s.pts[i], s.pts[i + 1]));
    pr.add(s.pts[i + 2]);
  }
  final path = Path();
  if (raw.isEmpty) return path;
  final hasPressure = pr.any((v) => (v - 0.5).abs() > 0.001);

  // 1. lissage (streamline) et points trop proches
  final pts = <Offset>[raw.first];
  final ps = <double>[pr.first];
  // lissage léger : le trait reste collé à la pointe
  final t = 0.4 + (1 - nib.streamline) * 0.6;
  for (var i = 1; i < raw.length; i++) {
    final q = Offset.lerp(pts.last, raw[i], t)!;
    if ((q - pts.last).distance < 0.6 && i != raw.length - 1) continue;
    pts.add(q);
    ps.add(pr[i]);
  }
  if (raw.length > 1) {
    pts.add(raw.last);
    ps.add(pr.last);
  }

  // 2. rayons (pression réelle ou simulée par la vitesse)
  final radii = <double>[];
  var prev = hasPressure ? ps.first : 0.5;
  var total = 0.0;
  final lens = <double>[0];
  for (var i = 1; i < pts.length; i++) {
    total += (pts[i] - pts[i - 1]).distance;
    lens.add(total);
  }
  for (var i = 0; i < pts.length; i++) {
    double pressure;
    if (hasPressure) {
      pressure = ps[i].clamp(0.05, 1.0);
    } else {
      final d = i == 0 ? 0.0 : (pts[i] - pts[i - 1]).distance;
      final sp = min(1.0, d / max(size, 1.0));
      final rp = min(1.0, 1 - sp);
      pressure = (prev + (rp - prev) * (sp * 0.275)).clamp(0.05, 1.0);
    }
    prev = pressure;
    var r = size * (0.5 - nib.thinning * (0.5 - pressure));
    if (nib.taperStart > 0) {
      final k = min(1.0, lens[i] / nib.taperStart);
      r *= 1 - (1 - k) * (1 - k);
    }
    if (nib.taperEnd > 0) {
      final k = min(1.0, (total - lens[i]) / nib.taperEnd);
      r *= 1 - (1 - k) * (1 - k);
    }
    radii.add(max(r, size * 0.08));
  }

  if (pts.length < 2 || total < 0.5) {
    return path..addOval(Rect.fromCircle(center: pts.first, radius: max(size / 2, 0.8)));
  }

  // 3. bords gauche et droit
  final left = <Offset>[], right = <Offset>[];
  for (var i = 0; i < pts.length; i++) {
    final a = pts[max(0, i - 1)], b = pts[min(pts.length - 1, i + 1)];
    var dir = b - a;
    if (dir.distance == 0) dir = const Offset(1, 0);
    final u = dir / dir.distance;
    var n = Offset(-u.dy, u.dx);
    var r = radii[i];
    if (s.tool == 'plume') {
      // bec biseauté à 45° : large en descendant, fin en travers
      const nibAngle = -pi / 4;
      final theta = atan2(u.dy, u.dx);
      r *= 0.18 + 0.82 * sin(theta - nibAngle).abs();
    }
    left.add(pts[i] + n * r);
    right.add(pts[i] - n * r);
  }

  void smooth(List<Offset> l) {
    for (var i = 1; i < l.length - 1; i++) {
      final m = (l[i] + l[i + 1]) / 2;
      path.quadraticBezierTo(l[i].dx, l[i].dy, m.dx, m.dy);
    }
    path.lineTo(l.last.dx, l.last.dy);
  }

  path.moveTo(left.first.dx, left.first.dy);
  smooth(left);
  final flat = s.tool == 'surligneur';
  if (flat) {
    path.lineTo(right.last.dx, right.last.dy);
  } else {
    path.arcToPoint(right.last, radius: Radius.circular(max(radii.last, 0.5)), clockwise: true);
  }
  final r = right.reversed.toList();
  smooth(r);
  if (!flat) path.arcToPoint(left.first, radius: Radius.circular(max(radii.first, 0.5)), clockwise: true);
  path.close();
  return path;
}

void paintStroke(Canvas canvas, Stroke s, {bool dark = false}) {
  final nib = nibOf(s.tool);
  final c = Color(s.color);
  final paint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.fill
    ..color = c.withValues(alpha: c.a * nib.alpha);
  if (nib.multiply) paint.blendMode = dark ? BlendMode.screen : BlendMode.multiply;
  if (s.tool == 'crayon') paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.45);
  if (s.tool == 'aquarelle') paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
  canvas.drawPath(strokeOutline(s), paint);
}

final _fillCache = Expando<Path>();
Path fillPath(Fill f) {
  final c = _fillCache[f];
  if (c != null) return c;
  final p = Path();
  for (var i = 0; i + 2 < f.runs.length; i += 3) {
    p.addRect(Rect.fromLTRB(f.runs[i + 1].toDouble(), f.runs[i].toDouble(), f.runs[i + 2] + 1.0, f.runs[i] + 1.0));
  }
  _fillCache[f] = p;
  return p;
}

/// Pot de peinture : remplit la zone fermée autour de [at], en s'arrêtant sur les traits.
Future<Fill?> computeFill(List<Stroke> strokes, Size size, Offset at, int color) async {
  final w = size.width.ceil(), h = size.height.ceil();
  if (w <= 0 || h <= 0) return null;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  final p = Paint()..color = const Color(0xFF000000);
  for (final s in strokes) {
    if (!s.hl) c.drawPath(strokeOutline(s), p);
  }
  final img = await rec.endRecording().toImage(w, h);
  final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  img.dispose();
  if (bd == null) return null;
  final px = bd.buffer.asUint8List();
  final x0 = at.dx.floor(), y0 = at.dy.floor();
  if (x0 < 0 || y0 < 0 || x0 >= w || y0 >= h) return null;
  bool wall(int i) => px[i * 4 + 3] > 90;
  if (wall(y0 * w + x0)) return null;
  final mark = Uint8List(w * h);
  final q = Int32List(w * h);
  var head = 0, tail = 0;
  q[tail++] = y0 * w + x0;
  mark[y0 * w + x0] = 1;
  while (head < tail) {
    final i = q[head++];
    final x = i % w, y = i ~/ w;
    for (final n in [if (x > 0) i - 1, if (x < w - 1) i + 1, if (y > 0) i - w, if (y < h - 1) i + w]) {
      if (mark[n] == 0 && !wall(n)) {
        mark[n] = 1;
        q[tail++] = n;
      }
    }
  }
  // on déborde un peu sous les traits pour ne laisser aucun liseré blanc
  for (var pass = 0; pass < 2; pass++) {
    final add = <int>[];
    for (var i = 0; i < w * h; i++) {
      if (mark[i] != 0) continue;
      final x = i % w, y = i ~/ w;
      if ((x > 0 && mark[i - 1] == 1) || (x < w - 1 && mark[i + 1] == 1) || (y > 0 && mark[i - w] == 1) || (y < h - 1 && mark[i + w] == 1)) add.add(i);
    }
    for (final i in add) {
      mark[i] = 1;
    }
  }
  final runs = <int>[];
  for (var y = 0; y < h; y++) {
    var x = 0;
    while (x < w) {
      if (mark[y * w + x] == 1) {
        final s = x;
        while (x < w && mark[y * w + x] == 1) {
          x++;
        }
        runs.addAll([y, s, x - 1]);
      } else {
        x++;
      }
    }
  }
  return runs.isEmpty ? null : Fill(color: color, runs: runs);
}

class InkPainter extends CustomPainter {
  final List<Stroke> strokes;
  final List<Fill> fills;
  final Stroke? cur;
  final int version;
  final Rect? selBox;
  final List<Offset>? lasso;
  final Color accent;
  final bool dark;
  InkPainter(this.strokes, this.cur, this.version, {this.fills = const [], this.selBox, this.lasso, this.accent = const Color(0xFFB0707A), this.dark = false});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final f in fills) {
      canvas.drawPath(fillPath(f), Paint()..color = Color(f.color));
    }
    for (final s in strokes) {
      if (s.hl) paintStroke(canvas, s, dark: dark);
    }
    if (cur != null && cur!.hl) paintStroke(canvas, cur!, dark: dark);
    for (final s in strokes) {
      if (!s.hl) paintStroke(canvas, s, dark: dark);
    }
    if (cur != null && !cur!.hl) paintStroke(canvas, cur!, dark: dark);
    canvas.restore();
    final dash = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    if (lasso != null && lasso!.length > 1) {
      final p = Path()..moveTo(lasso!.first.dx, lasso!.first.dy);
      for (final o in lasso!.skip(1)) {
        p.lineTo(o.dx, o.dy);
      }
      _dashed(canvas, p, dash);
    }
    if (selBox != null) {
      _dashed(canvas, Path()..addRRect(RRect.fromRectAndRadius(selBox!.inflate(8), const Radius.circular(10))), dash);
      final h = selBox!.inflate(8).bottomRight;
      canvas.drawCircle(h, 11, Paint()..color = Colors.white);
      canvas.drawCircle(h, 11, dash..strokeWidth = 2.4);
    }
  }

  void _dashed(Canvas canvas, Path p, Paint paint) {
    for (final m in p.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, min(d + 7, m.length)), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(InkPainter o) => true;
}

// ---------------------------------------------------------------- géométrie
bool _inPoly(Offset p, List<Offset> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    if ((a.dy > p.dy) != (b.dy > p.dy) && p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) inside = !inside;
  }
  return inside;
}

Rect strokesBounds(List<Stroke> l) {
  var r = Rect.zero;
  var first = true;
  for (final s in l) {
    for (var i = 0; i + 1 < s.pts.length; i += 3) {
      final o = Offset(s.pts[i], s.pts[i + 1]);
      final sq = Rect.fromCircle(center: o, radius: s.width / 2);
      r = first ? sq : r.expandToInclude(sq);
      first = false;
    }
  }
  return r;
}

/// Des points le long d'une forme (ligne, rectangle, ovale, flèche).
List<List<Offset>> shapePoints(String shape, Offset a, Offset b) {
  List<Offset> seg(Offset p, Offset q) {
    final n = max(2, ((q - p).distance / 4).ceil());
    return [for (var i = 0; i <= n; i++) Offset.lerp(p, q, i / n)!];
  }

  switch (shape) {
    case 'rect':
      final r = Rect.fromPoints(a, b);
      return [
        [...seg(r.topLeft, r.topRight), ...seg(r.topRight, r.bottomRight).skip(1), ...seg(r.bottomRight, r.bottomLeft).skip(1), ...seg(r.bottomLeft, r.topLeft).skip(1)]
      ];
    case 'ovale':
      final r = Rect.fromPoints(a, b);
      const n = 72;
      return [
        [for (var i = 0; i <= n; i++) Offset(r.center.dx + r.width / 2 * cos(2 * pi * i / n), r.center.dy + r.height / 2 * sin(2 * pi * i / n))]
      ];
    case 'fleche':
      final d = b - a;
      if (d.distance < 2) return [seg(a, b)];
      final u = d / d.distance;
      final n = Offset(-u.dy, u.dx);
      final h = min(18.0, d.distance / 3);
      return [seg(a, b), seg(b - u * h + n * h * 0.6, b) + seg(b, b - u * h - n * h * 0.6).skip(1).toList()];
    default:
      return [seg(a, b)];
  }
}

// ---------------------------------------------------------------- la couche d'encre d'une page
class InkLayer extends StatefulWidget {
  final String pageKey;
  const InkLayer({super.key, required this.pageKey});
  @override
  State<InkLayer> createState() => _InkLayerState();
}

class _InkLayerState extends State<InkLayer> {
  Stroke? _cur;
  int? _pointer;
  final Set<int> _touches = {};
  bool _erasing = false;
  List<Offset>? _lasso;
  Offset? _shapeA, _shapeB;
  String _drag = ''; // move, scale
  Offset _dragLast = Offset.zero;
  Rect _dragBox0 = Rect.zero;
  List<List<double>> _dragPts0 = [];
  int _version = 0;
  final List<Stroke> _fresh = [];
  Timer? _convert;
  bool _converting = false;

  @override
  void dispose() {
    _convert?.cancel();
    super.dispose();
  }

  /// Écriture → texte : les traits posés sur une liste ou une case deviennent des lignes.
  Future<void> _autoConvert(Store store, Desk desk) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (!mounted || _converting || _pointer != null) return;
    final layer = context.findRenderObject();
    if (layer is! RenderBox || !layer.attached) return;
    final page = widget.pageKey;
    final ink = store.ink(page);
    final fresh = _fresh.where((s) => ink.strokes.contains(s)).toList();
    _fresh.clear();
    if (fresh.isEmpty) return;
    // les zones de cette page, la plus petite d'abord (une case dans une liste…)
    final zones = <(InkTargetState, Rect)>[];
    for (final t in InkTargetState.live) {
      if (t.page != page || !t.mounted) continue;
      final r = t.rectIn(layer);
      if (r != null) zones.add((t, r));
    }
    if (zones.isEmpty) return;
    final grown = <(InkTargetState, Rect)>[];
    for (final (t, r) in zones) {
      var rr = r.inflate(10);
      if (t.widget.growDown) {
        var bottom = r.bottom + 150;
        for (final (o, q) in zones) {
          if (o != t && q.top > r.bottom - 4 && q.top < bottom && q.left < r.right && q.right > r.left) bottom = q.top - 4;
        }
        rr = Rect.fromLTRB(rr.left, rr.top, rr.right, max(rr.bottom, bottom));
      }
      grown.add((t, rr));
    }
    grown.sort((a, b) => (a.$2.width * a.$2.height).compareTo(b.$2.width * b.$2.height));
    final byZone = <InkTargetState, List<Stroke>>{};
    for (final s in fresh) {
      final c = strokeCenter(s);
      for (final (t, r) in grown) {
        if (r.contains(c)) {
          (byZone[t] ??= []).add(s);
          break;
        }
      }
    }
    if (byZone.isEmpty) return;
    _converting = true;
    try {
      for (final e in byZone.entries) {
        final groups = groupLines(e.value);
        final texts = await recognizeLines(groups);
        if (texts == null) {
          if (mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Reconnaissance d’écriture indisponible (la première fois, il faut internet pour la télécharger).')));
          }
          return;
        }
        final lines = texts.where((t) => t.isNotEmpty).toList();
        if (lines.isEmpty) continue;
        store.snapshot(page);
        ink.strokes.removeWhere((s) => e.value.contains(s));
        await store.touchInk(page);
        await e.key.deliver(lines);
      }
    } finally {
      _converting = false;
      if (mounted) setState(() => _version++);
    }
  }
  Offset? _guideStart;
  double _guideX0 = 0.5, _guideY0 = 0.3;

  bool _accept(PointerEvent e, Store store) {
    final stylus = e.kind == PointerDeviceKind.stylus || e.kind == PointerDeviceKind.invertedStylus;
    if (stylus || e.kind == PointerDeviceKind.mouse) return true;
    return !store.settings.stylusOnly;
  }

  List<Stroke> _strokes(Store store) => store.ink(widget.pageKey).strokes;

  void _down(PointerDownEvent e, Store store, Desk desk) {
    if (e.kind == PointerDeviceKind.touch) {
      _touches.add(e.pointer);
      if (_touches.length > 1) {
        // deux doigts : c'est un zoom, pas un trait
        setState(() {
          _cur = null;
          _pointer = null;
          _lasso = null;
          _shapeA = null;
        });
        return;
      }
    }
    if (!_accept(e, store) || _pointer != null) return;
    _pointer = e.pointer;
    desk.focus(widget.pageKey);
    final pos = e.localPosition;
    final erase = desk.tool == 'gomme' || e.kind == PointerDeviceKind.invertedStylus || (e.buttons & kSecondaryButton) != 0;
    if (erase) {
      store.snapshot(widget.pageKey);
      _erasing = true;
      _eraseAt(pos, store, desk);
      return;
    }
    if (desk.tool == 'lasso') {
      final box = desk.selBox(widget.pageKey);
      if (box != null) {
        final b = box.inflate(8);
        if ((pos - b.bottomRight).distance < 26) {
          _startDrag('scale', pos, desk, store);
          return;
        }
        if (b.contains(pos)) {
          _startDrag('move', pos, desk, store);
          return;
        }
        desk.clearSel();
      }
      setState(() => _lasso = [pos]);
      return;
    }
    if (desk.tool == 'placer') {
      final g = store.guide(widget.pageKey);
      if (g == null) return;
      _guideStart = pos;
      _guideX0 = g.x;
      _guideY0 = g.y;
      return;
    }
    if (desk.tool == 'pot') {
      _pointer = null;
      _paintBucket(pos, store, desk);
      return;
    }
    if (desk.tool == 'forme') {
      setState(() {
        _shapeA = pos;
        _shapeB = pos;
      });
      return;
    }
    final nib = nibOf(desk.tool);
    final c = desk.penColor;
    _cur = Stroke(color: c, width: desk.widthOf(nib.id), tool: nib.id);
    _add(e);
  }

  void _startDrag(String kind, Offset pos, Desk desk, Store store) {
    store.snapshot(widget.pageKey);
    _drag = kind;
    _dragLast = pos;
    _dragBox0 = desk.selBox(widget.pageKey)!;
    _dragPts0 = [for (final s in desk.sel) [...s.pts]];
  }

  void _add(PointerEvent e) {
    final stylus = e.kind == PointerDeviceKind.stylus || e.kind == PointerDeviceKind.invertedStylus;
    final p = stylus && e.pressure > 0 ? e.pressure.clamp(0.05, 1.0) : 0.5;
    setState(() {
      _cur!.pts.addAll([e.localPosition.dx, e.localPosition.dy, p.toDouble()]);
      invalidateStroke(_cur!);
    });
  }

  void _move(PointerMoveEvent e, Store store, Desk desk) {
    if (e.pointer != _pointer) return;
    final pos = e.localPosition;
    if (_guideStart != null) {
      final g = store.guide(widget.pageKey);
      final sz = context.size;
      if (g != null && sz != null) {
        g.x = (_guideX0 + (pos.dx - _guideStart!.dx) / sz.width).clamp(-0.5, 1.5);
        g.y = (_guideY0 + (pos.dy - _guideStart!.dy) / sz.height).clamp(-0.5, 1.5);
        store.refresh();
      }
      return;
    }
    if (_erasing) {
      _eraseAt(pos, store, desk);
      return;
    }
    if (_drag.isNotEmpty) {
      if (_drag == 'move') {
        final d = pos - _dragLast;
        for (final s in desk.sel) {
          for (var i = 0; i + 1 < s.pts.length; i += 3) {
            s.pts[i] += d.dx;
            s.pts[i + 1] += d.dy;
          }
          invalidateStroke(s);
        }
        _dragLast = pos;
      } else {
        final o = _dragBox0.topLeft;
        final k = max(0.15, min((pos.dx - o.dx) / max(_dragBox0.width + 8, 1), (pos.dy - o.dy) / max(_dragBox0.height + 8, 1)));
        for (var j = 0; j < desk.sel.length; j++) {
          final s = desk.sel[j];
          final p0 = _dragPts0[j];
          for (var i = 0; i + 1 < s.pts.length; i += 3) {
            s.pts[i] = o.dx + (p0[i] - o.dx) * k;
            s.pts[i + 1] = o.dy + (p0[i + 1] - o.dy) * k;
          }
          invalidateStroke(s);
        }
      }
      desk.refreshSel();
      setState(() => _version++);
      return;
    }
    if (_lasso != null) {
      setState(() => _lasso!.add(pos));
      return;
    }
    if (_shapeA != null) {
      setState(() => _shapeB = pos);
      return;
    }
    if (_cur != null) _add(e);
  }

  Future<void> _up(PointerEvent e, Store store, Desk desk) async {
    _touches.remove(e.pointer);
    if (e.pointer != _pointer) return;
    _pointer = null;
    final page = widget.pageKey;
    if (_guideStart != null) {
      _guideStart = null;
      final g = store.guide(page);
      if (g != null) await store.touchGuide(g);
      return;
    }
    if (_erasing) {
      _erasing = false;
      await store.touchInk(page);
      return;
    }
    if (_drag.isNotEmpty) {
      _drag = '';
      await store.touchInk(page);
      return;
    }
    if (_lasso != null) {
      final poly = _lasso!;
      setState(() => _lasso = null);
      if (poly.length < 3) return;
      final sel = _strokes(store).where((s) {
        var inside = 0, n = 0;
        for (var i = 0; i + 1 < s.pts.length; i += 3) {
          n++;
          if (_inPoly(Offset(s.pts[i], s.pts[i + 1]), poly)) inside++;
        }
        return n > 0 && inside / n > 0.6;
      }).toList();
      desk.setSel(page, sel);
      return;
    }
    if (_shapeA != null) {
      final a = _shapeA!, b = _shapeB ?? a;
      setState(() {
        _shapeA = null;
        _shapeB = null;
      });
      if ((b - a).distance < 4) return;
      store.snapshot(page);
      for (final part in shapePoints(desk.shape, a, b)) {
        _strokes(store).add(Stroke(color: desk.penColor, width: desk.widthOf('feutre'), tool: 'feutre', pts: [for (final o in part) ...[o.dx, o.dy, 0.5]]));
      }
      await store.touchInk(page);
      return;
    }
    final c = _cur;
    _cur = null;
    if (c != null && c.pts.isNotEmpty) {
      store.snapshot(page);
      _strokes(store).add(c);
      await store.touchInk(page);
      if (desk.autoText && !c.hl) {
        _fresh.add(c);
        _convert?.cancel();
        _convert = Timer(const Duration(milliseconds: 1400), () => _autoConvert(store, desk));
      }
    } else {
      setState(() {});
    }
  }

  Future<void> _paintBucket(Offset pos, Store store, Desk desk) async {
    final size = context.size;
    if (size == null) return;
    final page = widget.pageKey;
    final ink = store.ink(page);
    final f = await computeFill(ink.strokes, size, pos, desk.penColor);
    if (f == null) return;
    store.snapshot(page);
    // un nouveau remplissage au même endroit remplace l'ancien
    ink.fills.removeWhere((x) => x.contains(pos));
    ink.fills.add(f);
    await store.touchInk(page);
    if (mounted) setState(() => _version++);
  }

  void _eraseAt(Offset o, Store store, Desk desk) {
    final strokes = _strokes(store);
    final r = desk.eraserSize;
    var changed = false;
    final out = <Stroke>[];
    for (final s in strokes) {
      final hit = <bool>[];
      var any = false;
      for (var i = 0; i + 1 < s.pts.length; i += 3) {
        final h = (Offset(s.pts[i], s.pts[i + 1]) - o).distance < r + s.width / 2;
        hit.add(h);
        any = any || h;
      }
      if (!any) {
        out.add(s);
        continue;
      }
      changed = true;
      if (desk.eraseWhole) continue;
      // gomme précise : on garde les morceaux hors de la gomme
      var run = <double>[];
      for (var k = 0; k < hit.length; k++) {
        if (!hit[k]) {
          run.addAll(s.pts.sublist(k * 3, k * 3 + 3));
        } else if (run.isNotEmpty) {
          if (run.length >= 6) out.add(Stroke(color: s.color, width: s.width, tool: s.tool, pts: run));
          run = <double>[];
        }
      }
      if (run.length >= 6) out.add(Stroke(color: s.color, width: s.width, tool: s.tool, pts: run));
    }
    if (!changed) {
      // la gomme sur une zone remplie l'efface
      final fills = store.ink(widget.pageKey).fills;
      final n = fills.length;
      fills.removeWhere((f) => f.contains(o));
      if (fills.length != n) setState(() => _version++);
    }
    if (changed) {
      strokes
        ..clear()
        ..addAll(out);
      final from = desk.inkFrom[widget.pageKey];
      if (from != null && from > strokes.length) desk.inkFrom[widget.pageKey] = strokes.length;
      setState(() => _version++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final desk = DeskScope.of(context);
    final pal = Pal.byId(store.settings.theme);
    final strokes = store.inks[widget.pageKey]?.strokes ?? const <Stroke>[];
    Stroke? preview = _cur;
    if (_shapeA != null && _shapeB != null) {
      final parts = shapePoints(desk.shape, _shapeA!, _shapeB!);
      preview = Stroke(color: desk.penColor, width: desk.widthOf('feutre'), tool: 'feutre', pts: [for (final o in parts.first) ...[o.dx, o.dy, 0.5]]);
    }
    final active = desk.mode == Mode.pen;
    final box = active && desk.tool == 'lasso' ? desk.selBox(widget.pageKey) : null;
    return Stack(clipBehavior: Clip.none, children: [
      Positioned.fill(
        child: IgnorePointer(
          ignoring: !active,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _down(e, store, desk),
            onPointerMove: (e) => _move(e, store, desk),
            onPointerUp: (e) => _up(e, store, desk),
            onPointerCancel: (e) => _up(e, store, desk),
            child: RepaintBoundary(
              child: CustomPaint(
                painter: InkPainter(strokes, preview, _version + strokes.length,
                    fills: store.inks[widget.pageKey]?.fills ?? const [], selBox: box, lasso: _lasso, accent: pal.acc, dark: pal.dark),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ),
      if (box != null && _drag.isEmpty)
        Positioned(
          left: max(0.0, box.left - 8),
          top: max(0.0, box.top - 58),
          child: _SelBar(page: widget.pageKey),
        ),
    ]);
  }
}

/// Actions sur la sélection au lasso.
class _SelBar extends StatelessWidget {
  final String page;
  const _SelBar({required this.page});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final desk = DeskScope.of(context);
    final pal = Pal.byId(store.settings.theme);
    Widget b(IconData i, String tip, VoidCallback f) => IconButton(tooltip: tip, onPressed: f, icon: Icon(i, size: 20, color: Colors.white), visualDensity: VisualDensity.compact);
    return Material(
      color: pal.ink.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(999),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        b(Icons.palette_outlined, 'Couleur', () async {
          final c = await pickColor(context, store, title: 'Couleur de la sélection');
          if (c == null) return;
          store.snapshot(page);
          for (final s in desk.sel) {
            s.color = c;
            invalidateStroke(s);
          }
          await store.touchInk(page);
        }),
        b(Icons.copy_rounded, 'Dupliquer', () async {
          store.snapshot(page);
          final copies = [
            for (final s in desk.sel)
              Stroke(color: s.color, width: s.width, tool: s.tool, pts: [for (var i = 0; i < s.pts.length; i++) s.pts[i] + (i % 3 == 2 ? 0 : 24)])
          ];
          store.ink(page).strokes.addAll(copies);
          desk.setSel(page, copies);
          await store.touchInk(page);
        }),
        b(Icons.delete_outline_rounded, 'Supprimer', () async {
          store.snapshot(page);
          store.ink(page).strokes.removeWhere((s) => desk.sel.contains(s));
          desk.clearSel();
          await store.touchInk(page);
        }),
        b(Icons.close_rounded, 'Fermer', desk.clearSel),
      ]),
    );
  }
}

// ---------------------------------------------------------------- la trousse
class PenBar extends StatelessWidget {
  final VoidCallback? onRecognize;
  const PenBar({super.key, this.onRecognize});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final desk = DeskScope.of(context);
    final pal = Pal.byId(store.settings.theme);
    Widget pen(Nib n) {
      final on = desk.tool == n.id;
      return Tooltip(
        message: n.name,
        child: GestureDetector(
          onTap: () => desk.setTool(n.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            transform: Matrix4.translationValues(0, on ? -8 : 0, 0),
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CustomPaint(size: const Size(24, 46), painter: _NibIcon(n.id, Color(desk.penColor), pal.line)),
              Text(n.name, style: body(9.5, on ? pal.ink : pal.soft, w: FontWeight.w800)),
            ]),
          ),
        ),
      );
    }

    Widget tool(String id, IconData icon, String name, {VoidCallback? onTap}) {
      final on = desk.tool == id;
      return Tooltip(
        message: name,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap ?? () => desk.setTool(id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(color: on ? pal.tint : Colors.transparent, borderRadius: BorderRadius.circular(12)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 21, color: pal.ink),
              Text(name, style: body(9.5, pal.soft, w: FontWeight.w800)),
            ]),
          ),
        ),
      );
    }

    final colors = store.settings.palette;
    final isPen = nibs.any((n) => n.id == desk.tool) || desk.tool == 'forme';
    return Material(
      color: pal.card,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(22),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final n in nibs) pen(n),
          _sep(pal),
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              for (final c in colors.take(10))
                GestureDetector(
                  onTap: () => desk.setColor(c),
                  child: Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(color: desk.penColor == c ? pal.ink : pal.line, width: desk.penColor == c ? 2.5 : 1.2),
                    ),
                  ),
                ),
              GestureDetector(
                onTap: () async {
                  final c = await pickColor(context, store, title: 'Couleur du stylo');
                  if (c != null) desk.setColor(c);
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple, Colors.red])),
                ),
              ),
            ]),
            if (desk.tool == 'placer' && store.guide(desk.focusPage) != null)
              Builder(builder: (context) {
                final g = store.guide(desk.focusPage)!;
                final big = const ['dessin', 'lettrage', 'image'].contains(g.type);
                return SizedBox(
                  width: 290,
                  height: 30,
                  child: Row(children: [
                    Text('TAILLE DU CALQUE', style: body(9.5, pal.soft, w: FontWeight.w800)),
                    Expanded(
                      child: Slider(
                        value: big ? g.size.clamp(40, 500) : g.spacing.clamp(0.5, 2.5),
                        min: big ? 40 : 0.5,
                        max: big ? 500 : 2.5,
                        activeColor: pal.acc,
                        onChanged: (v) {
                          if (big) {
                            g.size = v;
                          } else {
                            g.spacing = v;
                          }
                          store.refresh();
                        },
                        onChangeEnd: (_) => store.touchGuide(g),
                      ),
                    ),
                  ]),
                );
              }),
            if (isPen || desk.tool == 'gomme')
              SizedBox(
                width: 290,
                height: 30,
                child: Row(children: [
                  Text(desk.tool == 'gomme' ? 'GOMME' : 'ÉPAISSEUR', style: body(9.5, pal.soft, w: FontWeight.w800)),
                  Expanded(
                    child: Slider(
                      value: desk.tool == 'gomme' ? desk.eraserSize : desk.widthOf(desk.tool == 'forme' ? 'feutre' : desk.tool),
                      min: desk.tool == 'gomme' ? 4 : 0.8,
                      max: desk.tool == 'gomme' ? 40 : 30,
                      activeColor: pal.acc,
                      onChanged: (v) => desk.tool == 'gomme' ? desk.setEraser(v) : desk.setWidth(desk.tool == 'forme' ? 'feutre' : desk.tool, v),
                    ),
                  ),
                  if (desk.tool == 'gomme')
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(desk.eraseWhole ? 'trait entier' : 'précise', style: body(10, pal.ink)),
                      selected: true,
                      onSelected: (_) => desk.toggleEraseWhole(),
                    ),
                ]),
              ),
          ]),
          _sep(pal),
          tool('pot', Icons.format_color_fill_rounded, 'Remplir'),
          tool('gomme', Icons.auto_fix_normal_outlined, 'Gomme'),
          tool('lasso', Icons.gesture_rounded, 'Lasso'),
          tool('forme', _shapeIcon(desk.shape), 'Formes', onTap: () {
            if (desk.tool == 'forme') {
              const order = ['ligne', 'rect', 'ovale', 'fleche'];
              desk.setShape(order[(order.indexOf(desk.shape) + 1) % order.length]);
            } else {
              desk.setTool('forme');
            }
          }),
          tool('calque', Icons.layers_outlined, 'Calque', onTap: () => showGuideSheet(context, desk.focusPage)),
          if (hasGuide(store, desk.focusPage)) tool('placer', Icons.open_with_rounded, 'Placer'),
          if (hasGuide(store, desk.focusPage))
            tool('oeil', store.guide(desk.focusPage)!.visible ? Icons.visibility_outlined : Icons.visibility_off_outlined, store.guide(desk.focusPage)!.visible ? 'Cacher' : 'Montrer',
                onTap: () => toggleGuide(store, desk.focusPage)),
          tool('undo', Icons.undo_rounded, 'Annuler', onTap: () {
            if (store.canUndo) store.undo();
          }),
          if (onRecognize != null)
            tool('auto', desk.autoText ? Icons.text_fields_rounded : Icons.gesture_rounded, desk.autoText ? 'Écriture → texte' : 'Écriture libre', onTap: desk.toggleAutoText),
        ]),
      ),
    );
  }

  IconData _shapeIcon(String s) => switch (s) {
        'rect' => Icons.crop_square_rounded,
        'ovale' => Icons.circle_outlined,
        'fleche' => Icons.north_east_rounded,
        _ => Icons.horizontal_rule_rounded,
      };

  Widget _sep(Pal pal) => Container(width: 1.5, height: 46, color: pal.line, margin: const EdgeInsets.symmetric(horizontal: 12));
}

class _NibIcon extends CustomPainter {
  final String id;
  final Color color, line;
  _NibIcon(this.id, this.color, this.line);
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final body = RRect.fromLTRBR(w * .2, 14, w * .8, size.height, const Radius.circular(5));
    canvas.drawRRect(body, Paint()..color = Colors.white);
    canvas.drawRRect(body, Paint()
      ..style = PaintingStyle.stroke
      ..color = line
      ..strokeWidth = 1.5);
    final tip = Path();
    switch (id) {
      case 'surligneur':
        tip.addRect(Rect.fromLTRB(w * .25, 2, w * .75, 15));
        break;
      case 'aquarelle':
        tip.addOval(Rect.fromLTRB(w * .22, 0, w * .78, 17));
        break;
      case 'pinceau':
        tip.moveTo(w * .2, 15);
        tip.quadraticBezierTo(w * .5, -6, w * .8, 15);
        break;
      case 'feutre':
        tip.addRRect(RRect.fromLTRBR(w * .3, 3, w * .7, 15, const Radius.circular(6)));
        break;
      case 'plume':
        tip.moveTo(w * .2, 15);
        tip.lineTo(w * .5, 0);
        tip.lineTo(w * .8, 15);
        break;
      default:
        tip.moveTo(w * .22, 15);
        tip.lineTo(w * .5, 1);
        tip.lineTo(w * .78, 15);
    }
    tip.close();
    final c = id == 'surligneur' ? color.withValues(alpha: 0.6) : (id == 'crayon' ? const Color(0xFF9A8F8A) : color);
    canvas.drawPath(tip, Paint()..color = c);
    canvas.drawRect(Rect.fromLTRB(w * .2, 22, w * .8, 27), Paint()..color = c.withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(_NibIcon o) => o.color != color || o.id != id;
}

// ---------------------------------------------------------------- zoom à deux doigts
class ZoomBox extends StatefulWidget {
  final Widget child;
  final bool enabled;
  const ZoomBox({super.key, required this.child, this.enabled = true});
  @override
  State<ZoomBox> createState() => _ZoomBoxState();
}

class _ZoomBoxState extends State<ZoomBox> {
  final Map<int, Offset> _t = {};
  double _s = 1, _s0 = 1, _d0 = 1;
  Offset _o = Offset.zero, _o0 = Offset.zero, _f0 = Offset.zero;
  Size _size = Size.zero;

  void _clamp() {
    _s = _s.clamp(1.0, 4.0);
    _o = Offset(_o.dx.clamp(_size.width - _size.width * _s, 0.0), _o.dy.clamp(_size.height - _size.height * _s, 0.0));
  }

  void _begin() {
    final l = _t.values.toList();
    _s0 = _s;
    _o0 = _o;
    if (l.length >= 2) {
      _d0 = max((l[0] - l[1]).distance, 1.0);
      _f0 = (l[0] + l[1]) / 2;
    } else if (l.isNotEmpty) {
      _f0 = l[0];
    }
  }

  @override
  void didUpdateWidget(ZoomBox old) {
    super.didUpdateWidget(old);
    if (!widget.enabled && _s != 1) {
      _s = 1;
      _o = Offset.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      _size = box.biggest;
      return Stack(children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            if (!widget.enabled || e.kind != PointerDeviceKind.touch) return;
            _t[e.pointer] = e.localPosition;
            _begin();
          },
          onPointerMove: (e) {
            if (!_t.containsKey(e.pointer)) return;
            _t[e.pointer] = e.localPosition;
            final l = _t.values.toList();
            setState(() {
              if (l.length >= 2) {
                final d = max((l[0] - l[1]).distance, 1.0);
                final f = (l[0] + l[1]) / 2;
                final ns = (_s0 * d / _d0).clamp(1.0, 4.0);
                final c = (_f0 - _o0) / _s0;
                _s = ns;
                _o = f - c * ns;
              } else if (_s > 1.01) {
                _o = _o0 + (l[0] - _f0);
              }
              _clamp();
            });
          },
          onPointerUp: (e) {
            _t.remove(e.pointer);
            _begin();
          },
          onPointerCancel: (e) {
            _t.remove(e.pointer);
            _begin();
          },
          child: ClipRect(
            child: Transform(
              transform: Matrix4.identity()
                ..translate(_o.dx, _o.dy)
                ..scale(_s, _s),
              child: widget.child,
            ),
          ),
        ),
        if (_s > 1.01)
          Positioned(
            right: 12,
            bottom: 12,
            child: ActionChip(
              avatar: const Icon(Icons.zoom_out_map_rounded, size: 18),
              label: Text('${(_s * 100).round()} %'),
              onPressed: () => setState(() {
                _s = 1;
                _o = Offset.zero;
              }),
            ),
          ),
      ]);
    });
  }
}
