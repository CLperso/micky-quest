import 'package:flutter/material.dart';

import '../canvas.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// La couverture du carnet : un tissu, une étiquette, et ce que tu veux poser dessus.
class CoverPage extends StatelessWidget {
  const CoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = Pal.byId(store.settings.theme);
    final st = store.settings;
    final base = coverStyles[st.coverStyle] ?? pal.cover;
    final dark = base.computeLuminance() < 0.25;
    return Stack(children: [
      Positioned.fill(child: CustomPaint(painter: CoverPainter(st.coverStyle, base))),
      Positioned(
        right: 46,
        top: 0,
        bottom: 0,
        child: Container(width: 22, color: Color.alphaBlend(Colors.black.withValues(alpha: 0.16), base)),
      ),
      if (!store.isHidden('cover.card'))
        Align(
          alignment: const Alignment(-0.08, -0.25),
          child: GestureDetector(
            onTap: DeskScope.of(context).mode != Mode.use
                ? null
                : () => editTexts(
                      context,
                      [
                        ('cover.kicker', 'Petit titre', 'CARNET'),
                        ('cover.title', 'Titre', st.coverTitle),
                        ('cover.sub', 'Sous-titre', st.coverSub),
                        ('cover.note', 'Petite note', 'si trouvé, merci de le rendre à Micky (elle n’a pas de poches)'),
                      ],
                      part: 'cover.card',
                    ),
            child: Container(
              width: 400,
              padding: const EdgeInsets.fromLTRB(30, 40, 30, 36),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF36313F) : pal.paper,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 14, offset: Offset(0, 4))],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final (id, def, style) in [
                  ('cover.kicker', 'CARNET', body(11, pal.acc, w: FontWeight.w800).copyWith(letterSpacing: 3)),
                  ('cover.title', st.coverTitle, titleFont(50, dark ? const Color(0xFFF1E9E4) : pal.ink)),
                  ('cover.sub', st.coverSub, script(30, pal.acc)),
                  ('cover.note', 'si trouvé, merci de le rendre à Micky (elle n’a pas de poches)', hand(19, pal.soft)),
                ])
                  if (store.text(id, def).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(store.text(id, def), textAlign: TextAlign.center, style: style),
                    ),
              ]),
            ),
          ),
        ),
    ]);
  }
}

class CoverPainter extends CustomPainter {
  final String style;
  final Color base;
  CoverPainter(this.style, this.base);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    final light = Paint()..color = Colors.white.withValues(alpha: 0.16);
    switch (style) {
      case 'vichy':
        final band = Paint()..color = const Color(0xFFD7A6A8).withValues(alpha: 0.45);
        for (var x = 0.0; x < size.width; x += 24) {
          canvas.drawRect(Rect.fromLTWH(x, 0, 12, size.height), band);
        }
        for (var y = 0.0; y < size.height; y += 24) {
          canvas.drawRect(Rect.fromLTWH(0, y, size.width, 12), band);
        }
        break;
      case 'nuit':
        final star = Paint()..color = const Color(0xFFE9D8B4).withValues(alpha: 0.8);
        for (var x = 12.0; x < size.width; x += 28) {
          for (var y = 12.0; y < size.height; y += 28) {
            canvas.drawCircle(Offset(x + ((y ~/ 28).isOdd ? 14 : 0), y), 1.2, star);
          }
        }
        break;
      case 'cuir':
        canvas.drawRect(Offset.zero & size, Paint()..shader = LinearGradient(colors: [Colors.white.withValues(alpha: .10), Colors.transparent]).createShader(Offset.zero & size));
        break;
      default:
        // grain de tissu
        for (var x = 0.0; x < size.width; x += 6) {
          for (var y = (x ~/ 6).isOdd ? 3.0 : 0.0; y < size.height; y += 6) {
            canvas.drawCircle(Offset(x, y), 0.7, light);
          }
        }
    }
  }

  @override
  bool shouldRepaint(CoverPainter o) => o.style != style || o.base != base;
}
