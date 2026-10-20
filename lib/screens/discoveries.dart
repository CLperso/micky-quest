import 'dart:math';
import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'block.dart' show kTruths;
import 'budget.dart';
import 'house.dart';

class DiscoveriesScreen extends StatefulWidget {
  const DiscoveriesScreen({super.key});

  @override
  State<DiscoveriesScreen> createState() => _DiscoveriesScreenState();
}

class _DiscoveriesScreenState extends State<DiscoveriesScreen> {
  int _tab = 0;
  static const _tabs = ['Moi', 'Temps', 'Patterns', 'Argent'];

  static const _icons = {
    'gold': Icons.star_rounded,
    'mult': Icons.timer_rounded,
    'why': Icons.psychology_alt_rounded,
    'hard': Icons.fitness_center_rounded,
    'feel': Icons.favorite_rounded,
    'stim': Icons.graphic_eq_rounded,
    LogKind.energy: Icons.bolt_rounded,
    LogKind.coffee: Icons.coffee_rounded,
    LogKind.pill: Icons.medication_rounded,
    'cycle': Icons.water_drop_rounded,
    'day': Icons.calendar_month_rounded,
    'sleep': Icons.bedtime_rounded,
    'start': Icons.wb_sunny_rounded,
    'idle': Icons.hourglass_empty_rounded,
    'cabin': Icons.cabin_rounded,
    'skin': Icons.face_retouching_natural_rounded,
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
        Text('Découvertes', style: K.display(26)),
        Text('Ce que tes données révèlent sur toi', style: K.body(13, color: K.muted)),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < _tabs.length - 1 ? 6 : 0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _tab = i),
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: _tab == i ? K.gold : K.card, borderRadius: BorderRadius.circular(12)),
                      child: Text(_tabs[i], style: K.body(13, color: _tab == i ? K.bg : K.ink, w: FontWeight.w800)),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (_tab == 0) ...[
          const HouseCard(),
          const SizedBox(height: 12),
          _statsPanel(store),
          const SizedBox(height: 12),
          const MedalCalendar(),
          const SizedBox(height: 12),
          const GainsStats(),
          const SizedBox(height: 12),
          SecondaryButton(label: 'Voir l\'album', onPressed: () => openScreen(context, const AlbumScreen())),
          const SizedBox(height: 16),
          Text('Petites vérités utiles', style: K.display(16)),
          const SizedBox(height: 8),
          for (final d in kTruths)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.$1, style: K.display(15, color: K.gold)),
                  const SizedBox(height: 4),
                  Text(d.$2, style: K.body(13, color: K.muted)),
                ]),
              ),
            ),
        ],
        if (_tab == 1) ...[
          const TimeStats(),
          const SizedBox(height: 12),
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
        ],
        if (_tab == 2) ...[
          Text('$unlocked / ${list.length} débloquées', style: K.body(12, color: K.gold, w: FontWeight.w800)),
          const SizedBox(height: 8),
          for (var i = 0; i < list.length; i++) ...[
            _card(list[i], _colors[i % _colors.length]),
            const SizedBox(height: 10),
          ],
        ],
        if (_tab == 3) ...[const BudgetCard(), const SizedBox(height: 14), const BudgetStats()],
      ],
    );
  }

  Widget _statsPanel(AppStore store) {
    Widget stat(String label, int v, Color c, String hint) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(label, style: K.body(13, w: FontWeight.w800))),
              Text('$v / 20', style: K.display(13, color: c)),
            ]),
            const SizedBox(height: 4),
            Bar(v / 20, color: c),
            const SizedBox(height: 2),
            Text(hint, style: K.body(11, color: K.muted)),
            const SizedBox(height: 10),
          ],
        );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('Niveau ${store.level} · ${store.title}', style: K.display(16))),
            Text('${store.xpInLevel} / $xpPerLevel XP', style: K.body(12, color: K.muted)),
          ]),
          const SizedBox(height: 6),
          Bar(store.xpInLevel / xpPerLevel, color: K.lime),
          const SizedBox(height: 14),
          stat('Focus', store.statFocus, K.lime, 'Minutes de sessions pro sans interruption (débrief), sur 7 jours, face à ton objectif.'),
          stat('Sens du temps', store.statTime, K.cyan, 'Justesse de tes paris de durée, 14 jours.'),
          stat('Constance', store.statConstancy, K.gold, 'Sur 10 jours : une tâche pro faite + les habitudes.'),
          stat('Sérénité', store.statSerenity, K.pink, 'Se gagne avec les gestes de régulation (réflexions, respiration, débrief, ruban). Ne baisse jamais parce que tu vas mal.'),
        ],
      ),
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


/// Temps pro / perso et heures productives.
class TimeStats extends StatefulWidget {
  const TimeStats({super.key});

  @override
  State<TimeStats> createState() => _TimeStatsState();
}

class _TimeStatsState extends State<TimeStats> {
  int _days = 7;

  static String _fmt(double m) {
    final v = m.round();
    return v >= 60 ? '${v ~/ 60} h ${(v % 60).toString().padLeft(2, '0')}' : '$v min';
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final cat = _days == 1 ? store.minutesByCategory(store.todayKey) : store.minutesByCategoryLast(_days);
    final pro = cat[Act.pro] ?? 0;
    final perso = cat[Act.perso] ?? 0;
    final rest = (cat[Act.pause] ?? 0) + (cat[Act.phone] ?? 0) + (cat[Act.nothing] ?? 0);
    final total = pro + perso + rest;
    final hours = store.proByHour(_days == 1 ? 1 : _days);
    final maxH = hours.fold(0.0, (a, b) => a > b ? a : b);
    final ranked = [for (var h = 0; h < 24; h++) h]..sort((a, b) => hours[b].compareTo(hours[a]));
    final top = ranked.take(3).where((h) => hours[h] > 0).toList()..sort();

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Ton temps', style: K.display(16))),
              for (final d in [1, 7, 30])
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text(d == 1 ? 'Auj.' : '$d j'),
                    selected: _days == d,
                    onSelected: (_) => setState(() => _days = d),
                    selectedColor: K.cyan,
                    labelStyle: K.body(12, color: _days == d ? K.bg : K.ink),
                    backgroundColor: K.raised,
                    side: BorderSide.none,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (total == 0)
            Text('Réponds aux check-ins ou lance des sessions pour remplir ces stats.', style: K.body(13, color: K.muted))
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 14,
                child: Row(children: [
                  if (pro > 0) Expanded(flex: (pro * 10).round(), child: Container(color: K.lime)),
                  if (perso > 0) Expanded(flex: (perso * 10).round(), child: Container(color: K.pink)),
                  if (rest > 0) Expanded(flex: (rest * 10).round(), child: Container(color: K.dim)),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _tile('Pro', pro, total, K.lime)),
              const SizedBox(width: 8),
              Expanded(child: _tile('Perso', perso, total, K.pink)),
              const SizedBox(width: 8),
              Expanded(child: _tile('Autre', rest, total, K.dim)),
            ]),
          ],
          const SizedBox(height: 16),
          Text('Tes heures productives (pro)', style: K.display(15)),
          Text(
            top.isEmpty
                ? 'Pas encore de données.'
                : 'Tu travailles surtout ${top.map((h) => '${h}h').join(', ')}.',
            style: K.body(12, color: K.muted),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var h = 6; h < 24; h++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: maxH == 0 ? 2 : 2 + 54 * hours[h] / maxH,
                            decoration: BoxDecoration(
                              color: top.contains(h) ? K.lime : K.raised,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(h % 3 == 0 ? '$h' : '', style: K.body(9, color: K.muted)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(String label, double v, double total, Color c) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(color: K.bg, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_fmt(v), style: K.display(16, color: c, w: FontWeight.w700)),
          Text('$label · ${total == 0 ? 0 : (100 * v / total).round()} %', style: K.body(11, color: K.muted)),
        ]),
      );
}


/// Dépenses de la période de paie : dépensé, par jour, restant, et où va l'argent par enveloppe.
class BudgetStats extends StatelessWidget {
  const BudgetStats({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final now = DateTime.now();
    final start = DateTime.fromMillisecondsSinceEpoch(store.periodStartMs);
    final daysGone = max(1, DateTime(now.year, now.month, now.day).difference(DateTime(start.year, start.month, start.day)).inDays + 1);
    final spent = store.spentInPeriod();
    final left = store.periodLeft();
    final days = store.daysLeftInPeriod();
    final perDay = spent / daysGone;
    final spentMap = store.spentByEnvelope();

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('Tes dépenses', style: K.display(16))),
            TextButton(onPressed: () => openScreen(context, const BudgetScreen()), child: const Text('Détail')),
          ]),
          Row(children: [
            Expanded(child: _tile(euros(spent), 'dépensés', K.gold)),
            const SizedBox(width: 8),
            Expanded(child: _tile(euros(perDay.roundToDouble()), 'par jour', K.cyan)),
            const SizedBox(width: 8),
            Expanded(child: _tile(euros(left.roundToDouble()), left < 0 ? 'dépassé' : 'restants', left < 0 ? K.coral : K.lime)),
          ]),
          const SizedBox(height: 8),
          Text(
            left <= 0
                ? 'Budget dépassé : encore $days jour${days > 1 ? 's' : ''} avant la paie.'
                : 'Pour tenir jusqu\'à la paie : ${euros((left / days).roundToDouble())} par jour max, pendant $days jour${days > 1 ? 's' : ''}.',
            style: K.body(12, color: K.muted),
          ),
          const SizedBox(height: 14),
          Text('Enveloppes', style: K.display(15)),
          const SizedBox(height: 6),
          for (final c in Expense.categories)
            Builder(builder: (context) {
              final alloc = store.envelopeAlloc(c);
              final rest = store.envelopeLeft(c);
              final frac = alloc <= 0 ? 0.0 : rest / alloc;
              final color = rest < 0 ? K.coral : leftColor(frac);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Icon(Icons.mail_rounded, color: color, size: 18),
                  const SizedBox(width: 6),
                  SizedBox(width: 104, child: Text(Expense.labels[c]!, style: K.body(12))),
                  Expanded(child: Bar(frac.clamp(0.0, 1.0), color: color, height: 8)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 74,
                    child: Text('${euros((spentMap[c] ?? 0).roundToDouble())} / ${euros(alloc.roundToDouble())}',
                        textAlign: TextAlign.right, style: K.body(11, color: color, w: FontWeight.w800)),
                  ),
                ]),
              );
            }),
        ],
      ),
    );
  }

  Widget _tile(String v, String l, Color c) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(color: K.bg, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(child: Text(v, style: K.display(16, color: c, w: FontWeight.w700))),
          Text(l, style: K.body(11, color: K.muted)),
        ]),
      );
}


/// Ce que tu as gagné chaque jour : XP, détail et trésors.
class GainsStats extends StatefulWidget {
  const GainsStats({super.key});

  @override
  State<GainsStats> createState() => _GainsStatsState();
}

class _GainsStatsState extends State<GainsStats> {
  int _sel = 13; // index du jour choisi (13 = aujourd'hui)

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final now = DateTime.now();
    final days = [for (var i = 13; i >= 0; i--) DateTime(now.year, now.month, now.day).subtract(Duration(days: i))];
    final gains = [for (final d in days) store.gainsOn(dayKey(d))];
    final maxXp = gains.fold(0, (a, g) => g.xp > a ? g.xp : a);
    final g = gains[_sel];
    final d = days[_sel];
    final week = gains.skip(7).fold(0, (a, g) => a + g.xp);
    final entries = g.byReason.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    const names = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('Tes gains', style: K.display(16))),
            Text('$week XP sur 7 jours', style: K.body(12, color: K.muted)),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 86,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 14; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _sel = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (gains[i].loot.isNotEmpty) const Icon(Icons.star_rounded, color: K.gold, size: 10),
                            Container(
                              height: maxXp == 0 ? 3 : 3 + 58 * gains[i].xp.clamp(0, maxXp) / maxXp,
                              decoration: BoxDecoration(
                                color: i == _sel ? K.lime : K.cyan.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text('${days[i].day}', style: K.body(9, color: i == _sel ? K.ink : K.muted)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Text(_sel == 13 ? 'Aujourd\'hui' : '${names[d.weekday - 1]} ${d.day}/${d.month}', style: K.display(15)),
            ),
            Text('+${g.xp} XP', style: K.display(16, color: K.lime, w: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          if (entries.isEmpty && g.loot.isEmpty) Text('Rien gagné ce jour-là.', style: K.body(12, color: K.muted)),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Expanded(child: Text(e.key, style: K.body(13))),
                Text('${e.value > 0 ? '+' : ''}${e.value}', style: K.body(13, color: e.value > 0 ? K.lime : K.coral, w: FontWeight.w800)),
              ]),
            ),
          if (g.loot.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final it in g.loot) Pill(it, color: K.gold)]),
          ],
        ],
      ),
    );
  }
}
