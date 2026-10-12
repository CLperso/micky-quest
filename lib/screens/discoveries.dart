import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';

class DiscoveriesScreen extends StatelessWidget {
  const DiscoveriesScreen({super.key});

  static const _icons = {
    'gold': Icons.star_rounded,
    'mult': Icons.timer_rounded,
    'why': Icons.psychology_alt_rounded,
    LogKind.energy: Icons.bolt_rounded,
    LogKind.coffee: Icons.coffee_rounded,
    'cycle': Icons.water_drop_rounded,
    'day': Icons.calendar_month_rounded,
    'sleep': Icons.bedtime_rounded,
  };
  static const _colors = [K.gold, K.cyan, K.coral, K.lime, K.pink];

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final list = store.discoveries();
    final unlocked = list.where((d) => d.unlocked).length;
    final heat = store.heatmap();
    final hasHeat = heat.any((r) => r.any((v) => v != null));

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Découvertes', style: K.display(26)),
                  Text('Ce que tes données révèlent sur toi', style: K.body(13, color: K.muted)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text('$unlocked/${list.length}', style: K.display(18, color: K.gold, w: FontWeight.w700)),
                Text('débloquées', style: K.body(10, color: K.muted)),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ta carte du focus', style: K.display(16)),
              Text('Part du temps sur tes quêtes, 6 dernières semaines', style: K.body(12, color: K.muted)),
              const SizedBox(height: 10),
              Row(children: [
                const SizedBox(width: 24),
                for (final h in ['8h', '10h', '12h', '14h', '16h', '18h', '20h'])
                  Expanded(child: Center(child: Text(h, style: K.body(10, color: K.muted)))),
              ]),
              const SizedBox(height: 4),
              for (var r = 0; r < 7; r++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    SizedBox(width: 24, child: Text(const ['L', 'M', 'M', 'J', 'V', 'S', 'D'][r], style: K.body(11, color: K.muted))),
                    for (var c = 0; c < 7; c++)
                      Expanded(
                        child: Container(
                          height: 24,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: _heatColor(heat[r][c]),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                  ]),
                ),
              if (!hasHeat)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Elle se remplit au fil de tes check-ins.', style: K.body(12, color: K.muted)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < list.length; i++) ...[
          _card(list[i], _colors[i % _colors.length]),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        Text('Le coffre de Micky', style: K.display(20)),
        const SizedBox(height: 8),
        Panel(
          child: store.inventory.isEmpty
              ? Text('Gagne des paris de durée et fais ton feu de camp pour remplir le coffre.', style: K.body(13, color: K.muted))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final it in store.inventory) Pill(it, color: K.gold),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        Text('${store.inventory.length}/${Loot.items.length} trésors · ${store.jokers} joker${store.jokers > 1 ? 's' : ''} de série',
            style: K.body(12, color: K.muted)),
      ],
    );
  }

  Color _heatColor(double? v) {
    if (v == null) return const Color(0xFF2A2450);
    const steps = [Color(0xFF3D4A6A), Color(0xFF4A7A55), Color(0xFF86C42E), K.lime];
    return steps[(v * 3.999).floor().clamp(0, 3)];
  }

  Widget _card(Discovery d, Color c) {
    final icon = _icons[d.id] ?? Icons.auto_awesome_rounded;
    if (d.unlocked) {
      return Panel(
        border: c,
        child: Row(
          children: [
            Icon(icon, color: c, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.title.toUpperCase(), style: K.body(11, color: c, w: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(d.text, style: K.body(14, w: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1736),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: K.line, width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: K.dim, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.title, style: K.body(14, color: const Color(0xFFC9C4E8), w: FontWeight.w800)),
                const SizedBox(height: 6),
                Bar(d.progress, color: K.dim, height: 6),
                const SizedBox(height: 4),
                Text('Il faut : ${d.need}', style: K.body(12, color: K.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
