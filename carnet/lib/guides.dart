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
                alignment: Alignment(0, g.y * 2 - 1),
                child: FractionallySizedBox(widthFactor: (g.size / 240).clamp(0.2, 1.0), child: Image.memory(b, fit: BoxFit.contain, gaplessPlayback: true)),
              );
        break;
      case 'lettrage':
        child = Align(
          alignment: Alignment(0, g.y * 2 - 1),
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
    switch (g.type) {
      case 'calligraphie':
        final u = 24 * k; // hauteur d'x
        var y = 30.0;
        while (y + 3 * u < h) {
          canvas.drawLine(Offset(0, y), Offset(w, y), light); // ascendante
          canvas.drawLine(Offset(0, y + u), Offset(w, y + u), mid); // hauteur d'x
          canvas.drawLine(Offset(0, y + 2 * u), Offset(w, y + 2 * u), strong); // ligne de base
          canvas.drawLine(Offset(0, y + 3 * u), Offset(w, y + 3 * u), light); // descendante
          y += 3.6 * u;
        }
        // obliques de pente
        final a = g.angle.clamp(30, 89) * pi / 180;
        final dx = h / tan(a);
        for (var x = -dx; x < w; x += 1.4 * u) {
          canvas.drawLine(Offset(x, h), Offset(x + dx, 0), light);
        }
        break;
      case 'lignes':
        for (var y = 40.0; y < h; y += 34 * k) {
          canvas.drawLine(Offset(0, y), Offset(w, y), mid);
        }
        break;
      case 'grille':
        final s = 14 * k;
        for (var x = s; x < w; x += s) {
          canvas.drawLine(Offset(x, 0), Offset(x, h), (x / s).round() % 5 == 0 ? mid : light);
        }
        for (var y = s; y < h; y += s) {
          canvas.drawLine(Offset(0, y), Offset(w, y), (y / s).round() % 5 == 0 ? mid : light);
        }
        break;
      case 'points':
        final s = 12 * k;
        final p = Paint()..color = pal.ink.withValues(alpha: 0.6);
        for (var x = s; x < w; x += s) {
          for (var y = s; y < h; y += s) {
            canvas.drawCircle(Offset(x, y), 1, p);
          }
        }
        break;
      case 'iso':
        final s = 22 * k;
        final t = tan(pi / 6);
        final sx = s * cos(pi / 6);
        for (var x = 0.0; x < w; x += sx) {
          canvas.drawLine(Offset(x, 0), Offset(x, h), light);
        }
        for (var c = -w * t; c < h + w * t; c += s) {
          canvas.drawLine(Offset(0, c), Offset(w, c + w * t), light);
          canvas.drawLine(Offset(0, c + w * t), Offset(w, c), light);
        }
        break;
      case 'mandala':
        final c = Offset(w / 2, h * g.y.clamp(0.1, 0.9));
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

