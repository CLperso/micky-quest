import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'model.dart';
import 'store.dart';
import 'theme.dart';

const guideTypes = [
  ('calligraphie', 'Calligraphie', Icons.format_italic_rounded),
  ('lettrage', 'Lettrage', Icons.title_rounded),
  ('lignes', 'Lignes', Icons.format_align_justify_rounded),
  ('grille', 'Grille', Icons.grid_on_rounded),
  ('points', 'Points', Icons.more_horiz_rounded),
  ('iso', 'Isométrique', Icons.change_history_rounded),
  ('mandala', 'Mandala', Icons.brightness_7_outlined),
  ('dessin', 'Motifs à dessiner', Icons.local_florist_outlined),
  ('image', 'Image', Icons.image_outlined),
];

final _imgCache = <String, Uint8List>{};
Uint8List? _bytes(Store store, String id) {
  final b = store.images[id];
  if (b == null) return null;
  return _imgCache.putIfAbsent(id, () => base64Decode(b));
}

TextStyle guideFont(String f, double size, Color? c, {Paint? fg}) {
  final col = fg == null ? c : null;
  return switch (f) {
    'elegant' => TextStyle(fontFamily: 'Cormorant', fontStyle: FontStyle.italic, fontWeight: FontWeight.w500, fontSize: size, color: col, foreground: fg, height: 1),
    'hand' => TextStyle(fontFamily: 'PatrickHand', fontSize: size, color: col, foreground: fg, height: 1),
    'caps' => TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w900, fontSize: size, color: col, foreground: fg, height: 1, letterSpacing: size * 0.06),
    _ => TextStyle(fontFamily: 'DancingScript', fontWeight: FontWeight.w700, fontSize: size, color: col, foreground: fg, height: 1),
  };
}

/// Le calque d'aide d'une page, en transparence, sous l'encre.
class GuideLayer extends StatelessWidget {
  final String page;
  const GuideLayer({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final g = store.guide(page);
    if (g == null || !g.visible) return const SizedBox.shrink();
    final pal = Pal.byId(store.settings.theme);
    Widget child;
    switch (g.type) {
      case 'image':
        final b = _bytes(store, g.img);
        child = b == null
            ? const SizedBox.shrink()
            : Align(
                alignment: Alignment(g.x * 2 - 1, g.y * 2 - 1),
                child: FractionallySizedBox(widthFactor: (g.size / 240).clamp(0.2, 1.0), child: Image.memory(b, fit: BoxFit.contain, gaplessPlayback: true)),
              );
        break;
      case 'lettrage':
        child = Align(
          alignment: Alignment(g.x * 2 - 1, g.y * 2 - 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Stack(children: [
              Text(g.text, textAlign: TextAlign.center, style: guideFont(g.font, g.size, pal.acc.withValues(alpha: 0.25))),
              Text(g.text,
                  textAlign: TextAlign.center,
                  style: guideFont(g.font, g.size, null,
                      fg: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 1.2
                        ..color = pal.ink)),
            ]),
          ),
        );
        break;
      default:
        child = CustomPaint(painter: GuidePainter(g, pal), size: Size.infinite);
    }
    return IgnorePointer(child: Opacity(opacity: g.opacity.clamp(0.05, 1.0), child: child));
  }
}

double _start(double off, double step) => step <= 0 ? 0 : (off % step) - step;

class GuidePainter extends CustomPainter {
  final Guide g;
  final Pal pal;
  GuidePainter(this.g, this.pal);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final strong = Paint()
      ..style = PaintingStyle.stroke
      ..color = pal.acc
      ..strokeWidth = 1.3;
    final mid = Paint()
      ..style = PaintingStyle.stroke
      ..color = pal.ink.withValues(alpha: 0.6)
      ..strokeWidth = 0.9;
    final light = Paint()
      ..style = PaintingStyle.stroke
      ..color = pal.soft.withValues(alpha: 0.6)
      ..strokeWidth = 0.7;
    final k = g.spacing.clamp(0.4, 3.0);
    // décalage choisi en glissant le calque
    final ox = (g.x - 0.5) * w, oy = (g.y - 0.3) * h;
    switch (g.type) {
      case 'calligraphie':
        final u = 24 * k; // hauteur d'x
        final row = 3.6 * u;
        for (var y = _start(30 + oy, row); y < h; y += row) {
          canvas.drawLine(Offset(0, y), Offset(w, y), light); // ascendante
          canvas.drawLine(Offset(0, y + u), Offset(w, y + u), mid); // hauteur d'x
          canvas.drawLine(Offset(0, y + 2 * u), Offset(w, y + 2 * u), strong); // ligne de base
          canvas.drawLine(Offset(0, y + 3 * u), Offset(w, y + 3 * u), light); // descendante
        }
        // obliques de pente
        final a = g.angle.clamp(30, 89) * pi / 180;
        final dx = h / tan(a);
        for (var x = _start(ox, 1.4 * u) - dx; x < w; x += 1.4 * u) {
          canvas.drawLine(Offset(x, h), Offset(x + dx, 0), light);
        }
        break;
      case 'lignes':
        final st = 34 * k;
        for (var y = _start(40 + oy, st); y < h; y += st) {
          canvas.drawLine(Offset(0, y), Offset(w, y), mid);
        }
        break;
      case 'grille':
        final s = 14 * k;
        for (var i = 0, x = _start(ox, s * 5); x < w; x += s, i++) {
          canvas.drawLine(Offset(x, 0), Offset(x, h), i % 5 == 0 ? mid : light);
        }
        for (var i = 0, y = _start(oy, s * 5); y < h; y += s, i++) {
          canvas.drawLine(Offset(0, y), Offset(w, y), i % 5 == 0 ? mid : light);
        }
        break;
      case 'points':
        final s = 12 * k;
        final p = Paint()..color = pal.ink.withValues(alpha: 0.6);
        for (var x = _start(ox, s); x < w; x += s) {
          for (var y = _start(oy, s); y < h; y += s) {
            canvas.drawCircle(Offset(x, y), 1, p);
          }
        }
        break;
      case 'iso':
        final s = 22 * k;
        final t = tan(pi / 6);
        final sx = s * cos(pi / 6);
        for (var x = _start(ox, sx); x < w; x += sx) {
          canvas.drawLine(Offset(x, 0), Offset(x, h), light);
        }
        for (var c = _start(oy, s) - w * t; c < h + w * t; c += s) {
          canvas.drawLine(Offset(0, c), Offset(w, c + w * t), light);
          canvas.drawLine(Offset(0, c + w * t), Offset(w, c), light);
        }
        break;
      case 'dessin':
        final k2 = g.size / 100;
        canvas.save();
        canvas.translate(w * g.x, h * g.y);
        canvas.scale(k2, k2);
        final ink = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / k2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = pal.ink;
        final help = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8 / k2
          ..color = pal.acc.withValues(alpha: 0.7);
        drawMotif(canvas, g.motif, ink, help);
        canvas.restore();
        break;
      case 'mandala':
        final c = Offset(w * g.x, h * g.y);
        for (var r = 20 * k; r < max(w, h); r += 30 * k) {
          canvas.drawCircle(c, r, (r ~/ (30 * k)) % 3 == 0 ? mid : light);
        }
        for (var i = 0; i < 24; i++) {
          final a = i * pi / 12;
          canvas.drawLine(c, c + Offset(cos(a), sin(a)) * max(w, h), i % 2 == 0 ? mid : light);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(GuidePainter o) => true;
}

/// Choisir et régler le calque de la page.
Future<void> showGuideSheet(BuildContext context, String page) async {
  final store = StoreScope.read(context);
  final pal = Pal.byId(store.settings.theme);
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: pal.paper,
    barrierColor: Colors.black12,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final g = store.guide(page);
      void live() {
        g!.mod = nowMs();
        store.refresh();
        setState(() {});
      }

      Future<void> commit() async {
        await store.touchGuide(g!);
        setState(() {});
      }

      Widget slider(String name, double v, double a, double b, void Function(double) f) => Row(children: [
            SizedBox(width: 92, child: Text(name, style: body(12, pal.ink, w: FontWeight.w800))),
            Expanded(
              child: Slider(
                value: v.clamp(a, b),
                min: a,
                max: b,
                activeColor: pal.acc,
                onChanged: (x) {
                  f(x);
                  live();
                },
                onChangeEnd: (_) => commit(),
              ),
            ),
          ]);

      Widget chip(String label, bool on, VoidCallback f) => Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 6),
            child: ChoiceChip(label: Text(label), selected: on, onSelected: (_) => f()),
          );

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), children: [
            Row(children: [
              Expanded(child: Text('Calque d’aide', style: titleFont(28, pal.ink))),
              if (g != null)
                Switch(
                  value: g.visible,
                  onChanged: (v) {
                    g.visible = v;
                    commit();
                  },
                ),
            ]),
            Text('Un guide en transparence pour dessiner ou calligraphier par-dessus. Il ne s’imprime pas dans ton dessin : tu peux le cacher ou le retirer quand tu veux.',
                style: body(12, pal.soft, w: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(children: [
              for (final (k, n, icon) in guideTypes)
                Padding(
                  padding: const EdgeInsets.only(right: 6, bottom: 6),
                  child: ChoiceChip(
                    avatar: Icon(icon, size: 18),
                    label: Text(n),
                    selected: g?.type == k,
                    onSelected: (_) async {
                      final x = g ?? Guide(page: page);
                      x
                        ..type = k
                        ..visible = true
                        ..del = false;
                      if (k == 'dessin' && g?.type != 'dessin') {
                        x.size = 260;
                        x.y = 0.5;
                        x.x = 0.5;
                        x.opacity = 0.4;
                      }
                      if (k == 'image' && x.img.isEmpty) {
                        final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1400, maxHeight: 1400, imageQuality: 80);
                        if (f == null) return;
                        x.img = await store.addImage(base64Encode(await f.readAsBytes()));
                        x.size = 240;
                        x.y = 0.5;
                      }
                      await store.touchGuide(x);
                      setState(() {});
                    },
                  ),
                ),
            ]),
            if (g != null) ...[
              slider('Transparence', g.opacity, 0.08, 0.9, (v) => g.opacity = v),
              if (g.type == 'calligraphie') ...[
                slider('Pente', g.angle, 40, 85, (v) => g.angle = v),
                slider('Taille', g.spacing, 0.5, 2.5, (v) => g.spacing = v),
              ],
              if (const ['lignes', 'grille', 'points', 'iso', 'mandala'].contains(g.type)) slider('Écart', g.spacing, 0.5, 2.5, (v) => g.spacing = v),
              if (g.type == 'mandala') slider('Position', g.y, 0.1, 0.9, (v) => g.y = v),
              if (g.type == 'lettrage') ...[
                TextFormField(
                  initialValue: g.text,
                  decoration: const InputDecoration(labelText: 'Le mot ou la phrase à tracer'),
                  onChanged: (v) {
                    g.text = v;
                    live();
                  },
                  onFieldSubmitted: (_) => commit(),
                ),
                const SizedBox(height: 8),
                Wrap(children: [
                  for (final (k, n) in [('script', 'Lettering'), ('elegant', 'Élégant'), ('hand', 'Manuscrit'), ('caps', 'Capitales')])
                    chip(n, g.font == k, () {
                      g.font = k;
                      commit();
                    }),
                ]),
                slider('Taille', g.size, 40, 240, (v) => g.size = v),
                slider('Position', g.y, 0, 1, (v) => g.y = v),
              ],
              if (g.type == 'dessin') ...[
                Wrap(children: [
                  for (final (k, n) in motifs)
                    chip(n, g.motif == k, () {
                      g.motif = k;
                      commit();
                    }),
                ]),
                slider('Taille', g.size, 60, 500, (v) => g.size = v),
                slider('Gauche-droite', g.x, 0, 1, (v) => g.x = v),
                slider('Haut-bas', g.y, 0, 1, (v) => g.y = v),
              ],
              if (g.type == 'image') ...[
                slider('Taille', g.size, 50, 240, (v) => g.size = v),
                slider('Position', g.y, 0, 1, (v) => g.y = v),
                TextButton.icon(
                  onPressed: () async {
                    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1400, maxHeight: 1400, imageQuality: 80);
                    if (f == null) return;
                    g.img = await store.addImage(base64Encode(await f.readAsBytes()));
                    await commit();
                  },
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Changer d’image'),
                ),
              ],
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () async {
                  g.del = true;
                  await store.touchGuide(g);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                icon: const Icon(Icons.layers_clear_outlined),
                label: const Text('Retirer le calque'),
              ),
            ],
          ]),
        ),
      );
    }),
  );
}

/// Petit raccourci pour cacher / montrer le calque d'une page.
Future<void> toggleGuide(Store store, String page) async {
  final g = store.guide(page);
  if (g == null) return;
  g.visible = !g.visible;
  await store.touchGuide(g);
}

bool hasGuide(Store store, String page) => store.guide(page) != null;


const motifs = [
  ('marguerite', 'Marguerite'),
  ('tulipe', 'Tulipe'),
  ('rose', 'Rose'),
  ('cinq', 'Fleur à 5 pétales'),
  ('branche', 'Branche'),
  ('feuilles', 'Feuilles'),
  ('couronne', 'Couronne'),
  ('bouquet', 'Petit bouquet'),
  ('chat', 'Chat'),
  ('coeur', 'Cœur'),
  ('nuage', 'Nuage'),
  ('banniere', 'Banderole'),
];

Path _leaf(Offset base, double len, double angle, {double width = 0.38}) {
  final d = Offset(cos(angle), sin(angle));
  final n = Offset(-d.dy, d.dx);
  final tip = base + d * len;
  final mid = base + d * (len * 0.5);
  return Path()
    ..moveTo(base.dx, base.dy)
    ..quadraticBezierTo((mid + n * len * width).dx, (mid + n * len * width).dy, tip.dx, tip.dy)
    ..quadraticBezierTo((mid - n * len * width).dx, (mid - n * len * width).dy, base.dx, base.dy)
    ..moveTo(base.dx, base.dy)
    ..lineTo((base + d * len * 0.8).dx, (base + d * len * 0.8).dy);
}

Path _petal(Offset c, double r0, double len, double angle, double width) {
  final d = Offset(cos(angle), sin(angle));
  final n = Offset(-d.dy, d.dx);
  final a = c + d * r0, b = c + d * (r0 + len), m = c + d * (r0 + len * 0.55);
  return Path()
    ..moveTo(a.dx, a.dy)
    ..cubicTo((m + n * width).dx, (m + n * width).dy, (b + n * width * 0.4).dx, (b + n * width * 0.4).dy, b.dx, b.dy)
    ..cubicTo((b - n * width * 0.4).dx, (b - n * width * 0.4).dy, (m - n * width).dx, (m - n * width).dy, a.dx, a.dy);
}

/// Des modèles au trait, centrés sur (0, 0), à environ 100 de haut.
void drawMotif(Canvas c, String m, Paint ink, Paint help) {
  switch (m) {
    case 'marguerite':
      const ctr = Offset(0, -18);
      for (var i = 0; i < 12; i++) {
        c.drawPath(_petal(ctr, 9, 26, i * pi / 6, 6), ink);
      }
      c.drawCircle(ctr, 9, ink);
      c.drawPath(Path()
        ..moveTo(0, 18)
        ..quadraticBezierTo(4, 45, -2, 70), ink);
      c.drawPath(_leaf(const Offset(1, 42), 24, -0.5), ink);
      c.drawPath(_leaf(const Offset(0, 54), 22, pi + 0.6), ink);
      break;
    case 'tulipe':
      c.drawPath(Path()
        ..moveTo(-20, -30)
        ..cubicTo(-24, -6, -12, 6, 0, 6)
        ..cubicTo(12, 6, 24, -6, 20, -30)
        ..cubicTo(14, -20, 8, -22, 6, -34)
        ..cubicTo(4, -24, -4, -24, -6, -34)
        ..cubicTo(-8, -22, -14, -20, -20, -30), ink);
      c.drawPath(Path()
        ..moveTo(-6, -34)
        ..cubicTo(-14, -16, -6, 0, 0, 6)
        ..moveTo(6, -34)
        ..cubicTo(14, -16, 6, 0, 0, 6), help);
      c.drawPath(Path()
        ..moveTo(0, 6)
        ..quadraticBezierTo(-3, 40, 2, 70), ink);
      c.drawPath(Path()
        ..moveTo(1, 66)
        ..cubicTo(-20, 50, -26, 30, -18, 14)
        ..cubicTo(-14, 34, -6, 50, 1, 58), ink);
      break;
    case 'rose':
      c.drawPath(Path()..addArc(Rect.fromCircle(center: const Offset(0, -8), radius: 6), 0, pi * 1.6), ink);
      c.drawPath(Path()..addArc(Rect.fromCircle(center: const Offset(1, -7), radius: 12), pi * 0.8, pi * 1.5), ink);
      c.drawPath(Path()..addArc(Rect.fromCircle(center: const Offset(-1, -6), radius: 19), pi * 1.4, pi * 1.3), ink);
      for (var i = 0; i < 5; i++) {
        final a = i * 2 * pi / 5 - pi / 2;
        final p = Offset(cos(a), sin(a)) * 26 + const Offset(0, -6);
        c.drawPath(Path()..addArc(Rect.fromCircle(center: p, radius: 13), a - pi * 0.6, pi * 1.2), ink);
      }
      c.drawCircle(const Offset(0, -6), 32, help);
      c.drawPath(Path()
        ..moveTo(0, 26)
        ..quadraticBezierTo(5, 50, 0, 72), ink);
      c.drawPath(_leaf(const Offset(2, 48), 22, -0.4), ink);
      break;
    case 'cinq':
      const ctr = Offset(0, 0);
      c.drawCircle(ctr, 44, help);
      c.drawCircle(ctr, 10, help);
      for (var i = 0; i < 5; i++) {
        final a = i * 2 * pi / 5 - pi / 2;
        c.drawLine(ctr, ctr + Offset(cos(a), sin(a)) * 48, help);
        c.drawPath(_petal(ctr, 8, 36, a, 17), ink);
      }
      c.drawCircle(ctr, 8, ink);
      break;
    case 'branche':
      final stem = Path()
        ..moveTo(-60, 30)
        ..cubicTo(-30, 10, 10, 20, 60, -30);
      c.drawPath(stem, ink);
      for (final mt in stem.computeMetrics()) {
        for (var i = 1; i < 9; i++) {
          final t = mt.getTangentForOffset(mt.length * i / 9)!;
          final a = atan2(t.vector.dy, t.vector.dx) + (i.isOdd ? -0.9 : 0.9);
          c.drawPath(_leaf(t.position, 16 - i * 0.5, a), ink);
        }
      }
      break;
    case 'feuilles':
      c.drawPath(_leaf(const Offset(-40, 40), 50, -1.2, width: 0.32), ink);
      c.drawPath(_leaf(const Offset(0, 45), 60, -1.57, width: 0.28), ink);
      c.drawPath(_leaf(const Offset(40, 40), 50, -1.95, width: 0.36), ink);
      break;
    case 'couronne':
      c.drawCircle(Offset.zero, 46, help);
      for (var i = 0; i < 22; i++) {
        final a = i * 2 * pi / 22;
        final p = Offset(cos(a), sin(a)) * 46;
        c.drawPath(_leaf(p, 13, a + pi / 2 + (i.isOdd ? 0.7 : -0.7)), ink);
      }
      break;
    case 'bouquet':
      for (final (dx, dy) in [(-22.0, -30.0), (0.0, -42.0), (22.0, -30.0)]) {
        final o = Offset(dx, dy);
        for (var i = 0; i < 6; i++) {
          c.drawPath(_petal(o, 4, 11, i * pi / 3, 4), ink);
        }
        c.drawCircle(o, 4, ink);
        c.drawPath(Path()
          ..moveTo(o.dx, o.dy + 14)
          ..quadraticBezierTo(o.dx * 0.4, 20, 0, 40), ink);
      }
      c.drawPath(_leaf(const Offset(-6, 14), 20, -2.4), ink);
      c.drawPath(_leaf(const Offset(6, 14), 20, -0.7), ink);
      c.drawPath(Path()
        ..moveTo(-10, 38)
        ..lineTo(10, 38)
        ..lineTo(4, 62)
        ..lineTo(-4, 62)
        ..close(), ink);
      c.drawPath(Path()
        ..moveTo(-8, 44)
        ..quadraticBezierTo(-20, 40, -16, 50)
        ..quadraticBezierTo(-10, 52, -2, 46)
        ..moveTo(8, 44)
        ..quadraticBezierTo(20, 40, 16, 50)
        ..quadraticBezierTo(10, 52, 2, 46), ink);
      break;
    case 'chat':
      // tête
      c.drawPath(Path()
        ..moveTo(-26, -30)
        ..lineTo(-30, -58)
        ..lineTo(-12, -44)
        ..quadraticBezierTo(0, -48, 12, -44)
        ..lineTo(30, -58)
        ..lineTo(26, -30)
        ..quadraticBezierTo(30, -8, 0, -6)
        ..quadraticBezierTo(-30, -8, -26, -30), ink);
      c.drawCircle(const Offset(-10, -28), 2.5, ink);
      c.drawCircle(const Offset(10, -28), 2.5, ink);
      c.drawPath(Path()
        ..moveTo(-4, -20)
        ..quadraticBezierTo(0, -16, 4, -20), ink);
      // corps et queue
      c.drawPath(Path()
        ..moveTo(-16, -9)
        ..cubicTo(-36, 10, -34, 50, -10, 52)
        ..lineTo(10, 52)
        ..cubicTo(34, 50, 36, 10, 16, -9), ink);
      c.drawPath(Path()
        ..moveTo(26, 44)
        ..cubicTo(50, 40, 56, 10, 40, 0), ink);
      c.drawPath(Path()
        ..moveTo(-8, 52)
        ..quadraticBezierTo(-8, 40, -2, 40)
        ..moveTo(8, 52)
        ..quadraticBezierTo(8, 40, 2, 40), help);
      break;
    case 'coeur':
      c.drawPath(Path()
        ..moveTo(0, 40)
        ..cubicTo(-50, 8, -52, -26, -26, -34)
        ..cubicTo(-12, -38, -2, -26, 0, -16)
        ..cubicTo(2, -26, 12, -38, 26, -34)
        ..cubicTo(52, -26, 50, 8, 0, 40), ink);
      c.drawLine(const Offset(0, -44), const Offset(0, 48), help);
      break;
    case 'nuage':
      c.drawPath(Path()
        ..moveTo(-44, 20)
        ..arcToPoint(const Offset(-30, -4), radius: const Radius.circular(14))
        ..arcToPoint(const Offset(0, -22), radius: const Radius.circular(20))
        ..arcToPoint(const Offset(30, -6), radius: const Radius.circular(18))
        ..arcToPoint(const Offset(44, 20), radius: const Radius.circular(14))
        ..close(), ink);
      break;
    case 'banniere':
      c.drawPath(Path()
        ..moveTo(-50, -12)
        ..lineTo(50, -12)
        ..lineTo(50, 12)
        ..lineTo(-50, 12)
        ..close()
        ..moveTo(-50, -4)
        ..lineTo(-70, -4)
        ..lineTo(-62, 8)
        ..lineTo(-70, 20)
        ..lineTo(-42, 20)
        ..lineTo(-42, 12)
        ..moveTo(50, -4)
        ..lineTo(70, -4)
        ..lineTo(62, 8)
        ..lineTo(70, 20)
        ..lineTo(42, 20)
        ..lineTo(42, 12), ink);
      c.drawLine(const Offset(-44, 0), const Offset(44, 0), help);
      break;
  }
}
