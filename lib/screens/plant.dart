import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';

/// Plante qui grandit avec la force de l'habitude (0 à 1).
class PlantView extends StatelessWidget {
  final double strength;
  final Color color;
  final double size;
  const PlantView({super.key, required this.strength, required this.color, this.size = 220});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: strength),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => CustomPaint(
        size: Size(size, size),
        painter: _PlantPainter(v, color),
      ),
    );
  }
}

class _PlantPainter extends CustomPainter {
  final double s;
  final Color flower;
  _PlantPainter(this.s, this.flower);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final ground = h * 0.86;

    // pot
    final pot = Paint()..color = const Color(0xFFC46A3B);
    final potPath = Path()
      ..moveTo(cx - w * 0.22, ground - h * 0.02)
      ..lineTo(cx + w * 0.22, ground - h * 0.02)
      ..lineTo(cx + w * 0.17, h * 0.98)
      ..lineTo(cx - w * 0.17, h * 0.98)
      ..close();
    canvas.drawPath(potPath, pot);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, ground - h * 0.03), width: w * 0.5, height: h * 0.06), const Radius.circular(6)),
      Paint()..color = const Color(0xFFE08A55),
    );
    // terre
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, ground - h * 0.05), width: w * 0.42, height: h * 0.05), Paint()..color = const Color(0xFF4A3426));

    final stem = Paint()
      ..color = const Color(0xFF4CAF50)
      ..strokeWidth = max(2, w * 0.03)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final leaf = Paint()..color = const Color(0xFF66D36E);
    final darkLeaf = Paint()..color = const Color(0xFF3E9A47);

    if (s < 0.05) {
      // graine
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, ground - h * 0.07), width: w * 0.08, height: h * 0.05), Paint()..color = const Color(0xFF8D6E63));
      return;
    }

    // tige : hauteur selon la force
    final stemH = h * (0.12 + 0.55 * min(1.0, s / 0.85));
    final top = ground - h * 0.06 - stemH;
    final path = Path()..moveTo(cx, ground - h * 0.06);
    path.quadraticBezierTo(cx + w * 0.04, ground - stemH / 2, cx, top);
    canvas.drawPath(path, stem);

    void drawLeaf(Offset base, double angle, double len, Paint p) {
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate(angle);
      final lp = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(len * 0.5, -len * 0.45, len, 0)
        ..quadraticBezierTo(len * 0.5, len * 0.45, 0, 0);
      canvas.drawPath(lp, p);
      canvas.restore();
    }

    // feuilles : une paire tous les ~0.15 de force
    final pairs = min(5, (s / 0.15).floor());
    for (var i = 0; i < pairs; i++) {
      final y = ground - h * 0.08 - stemH * (0.18 + 0.16 * i);
      final len = w * (0.14 + 0.02 * i) * (0.6 + 0.4 * min(1.0, (s - 0.15 * i) / 0.15));
      drawLeaf(Offset(cx, y), -pi + 0.5, len, i.isEven ? leaf : darkLeaf);
      drawLeaf(Offset(cx, y - h * 0.03), -0.5, len * 0.9, i.isEven ? darkLeaf : leaf);
    }

    // bourgeon puis fleur
    if (s >= 0.6) {
      final bloom = min(1.0, (s - 0.6) / 0.3);
      final r = w * (0.04 + 0.08 * bloom);
      final petal = Paint()..color = flower;
      for (var k = 0; k < 6; k++) {
        final a = k * pi / 3;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx + cos(a) * r * 0.9, top + sin(a) * r * 0.9), width: r * 1.1, height: r * 0.8),
          petal,
        );
      }
      canvas.drawCircle(Offset(cx, top), r * 0.55, Paint()..color = K.gold);
    } else if (s >= 0.45) {
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, top), width: w * 0.07, height: h * 0.09), Paint()..color = flower.withValues(alpha: 0.8));
    }

    // étincelles quand l'habitude est automatique
    if (s >= 0.9) {
      final sp = Paint()..color = K.gold;
      for (final o in [Offset(cx - w * 0.3, top - h * 0.02), Offset(cx + w * 0.32, top + h * 0.05), Offset(cx + w * 0.2, top - h * 0.12)]) {
        canvas.drawCircle(o, w * 0.015, sp);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PlantPainter old) => old.s != s || old.flower != flower;
}

/// Fiche d'une habitude : la plante, la jauge et les 14 derniers jours.
class HabitPlantSheet extends StatelessWidget {
  final Habit habit;
  const HabitPlantSheet({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final h = habit;
    final c = Color(h.color);
    final s = store.habitStrength(h);
    final lv = store.habitLevel(h, store.todayKey);
    final now = DateTime.now();
    final total = store.habitLogs.where((l) => l.habitId == h.id && l.level > 0).length;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        children: [
          Row(
            children: [
              Expanded(child: Text(h.name, style: K.display(22))),
              Pill(AppStore.strengthLabel(s), color: c),
            ],
          ),
          if (h.cue.isNotEmpty) Text(h.cue, style: K.body(13, color: K.muted)),
          const SizedBox(height: 8),
          Center(child: PlantView(strength: s, color: c, size: 220)),
          const SizedBox(height: 6),
          Bar(s, color: c, height: 8),
          const SizedBox(height: 6),
          Text(
            '$total jour${total > 1 ? 's' : ''} fait${total > 1 ? 's' : ''} · ${store.habitDaysDone(h)}/7 cette semaine · '
            '${s < 0.6 ? 'la fleur arrive vers « Racines »' : s < 0.9 ? 'encore un peu pour les étincelles' : 'elle est automatique !'}',
            style: K.body(12, color: K.muted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 13; i >= 0; i--)
                Builder(builder: (_) {
                  final d = dayKey(now.subtract(Duration(days: i)));
                  final l = store.habitLevel(h, d);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => store.cycleHabit(h, day: d),
                      child: Container(
                        height: 24,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: l == 2 ? c : (l == 1 ? c.withValues(alpha: 0.4) : K.raised),
                          borderRadius: BorderRadius.circular(5),
                          border: i == 0 ? Border.all(color: K.ink, width: 1.5) : null,
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
          const SizedBox(height: 4),
          Text('14 derniers jours · touche un jour pour corriger', style: K.body(11, color: K.dim)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: lv == 1 ? 'Mini ✓' : 'Version mini',
                  onPressed: () async {
                    await store.cycleHabit(h, to: lv == 1 ? 0 : 1);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: lv == 2 ? 'Faite ✓' : 'Faite !',
                  color: c,
                  onPressed: () async {
                    await store.cycleHabit(h, to: lv == 2 ? 0 : 2);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
