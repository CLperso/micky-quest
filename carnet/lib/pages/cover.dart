import 'package:flutter/material.dart';

import '../canvas.dart';
import '../store.dart';
import '../theme.dart';

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
      Align(
        alignment: const Alignment(-0.08, -0.25),
        child: GestureDetector(
          onTap: () async {
            final t = await askText(context, 'Titre de la couverture', initial: st.coverTitle);
            if (t == null) return;
            final sub = await askText(context, 'Sous-titre', initial: st.coverSub);
            st.coverTitle = t;
            if (sub != null) st.coverSub = sub;
            await store.touchSettings();
          },
          child: Container(
            width: 400,
            padding: const EdgeInsets.fromLTRB(30, 40, 30, 36),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF36313F) : pal.paper,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 14, offset: Offset(0, 4))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('CARNET', style: body(11, pal.acc, w: FontWeight.w800).copyWith(letterSpacing: 3)),
              const SizedBox(height: 14),
              Text(st.coverTitle, textAlign: TextAlign.center, style: titleFont(50, dark ? const Color(0xFFF1E9E4) : pal.ink)),
              const SizedBox(height: 8),
              Text(st.coverSub, textAlign: TextAlign.center, style: script(30, pal.acc)),
              const SizedBox(height: 18),
              Container(width: 60, height: 1, color: pal.acc.withValues(alpha: .6)),
              const SizedBox(height: 14),
              Text('si trouvé, merci de le rendre à Micky (elle n’a pas de poches)', textAlign: TextAlign.center, style: hand(19, pal.soft)),
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
