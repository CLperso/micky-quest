import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'session.dart';

String _fmt(int m) => m >= 60 ? '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${(m % 60).toString().padLeft(2, '0')}'}' : '$m min';

/// Le boss de la semaine : jauge de dégâts (ton avancement), barres de coups (tes sessions), attaque.
class BossScreen extends StatefulWidget {
  const BossScreen({super.key});

  @override
  State<BossScreen> createState() => _BossScreenState();
}

class _BossScreenState extends State<BossScreen> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final boss = store.boss;
    if (boss == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Boss de la semaine')),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
            children: [
              const MickySays('Pas de boss cette semaine. Choisis ta plus grosse tâche pro et fais-en le boss : chaque session dessus est un coup.', ring: K.coral),
              const SizedBox(height: 14),
              for (final t in store.openTasks.where((t) => t.category != 'perso').take(10))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SecondaryButton(label: t.title, onPressed: () => store.setBoss(t)),
                ),
            ],
          ),
        ),
      );
    }
    final hits = store.bossHits(boss);
    final minutes = store.bossMinutes(boss);
    final total = store.bossTotal(boss);
    final maxHit = hits.fold(30, (a, s) => max(a, s.actualMin.round()));
    final slots = max(6, hits.length + 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Boss de la semaine'),
        actions: [
          TextButton(
            onPressed: () async {
              final t = await showModalBottomSheet<Task>(
                context: context,
                builder: (ctx) => SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final t in store.openTasks.where((t) => t.category != 'perso' && !t.isBoss))
                        ListTile(title: Text(t.title, style: K.body(15)), onTap: () => Navigator.pop(ctx, t)),
                    ],
                  ),
                ),
              );
              if (t != null) await store.setBoss(t);
            },
            child: const Text('Changer'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            Panel(
              color: const Color(0xFF2A1630),
              border: K.coral,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(color: const Color(0xFF3A1F3E), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.pest_control_rounded, color: K.coral, size: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BOSS DE LA SEMAINE · +300 XP', style: K.body(11, color: const Color(0xFFFFB89A), w: FontWeight.w900)),
                          Text(boss.title, style: K.display(18)),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Text('Dégâts infligés · ton avancement', style: K.body(12, color: K.muted)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 16,
                          color: const Color(0xFF3A1F3E),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: boss.bossProgress / 100,
                            child: Container(
                              decoration: const BoxDecoration(gradient: LinearGradient(colors: [K.coral, K.gold])),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${boss.bossProgress} %', style: K.display(16, color: K.gold)),
                  ]),
                  const SizedBox(height: 4),
                  Text('${_fmt(minutes)} de coups · estimé ${_fmt(total)}${minutes > total ? ' (dépassé)' : ''}', style: K.body(11, color: K.muted)),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: '⚔️  Attaquer · lancer une session',
                    color: K.coral,
                    onPressed: () async {
                      if (store.runningSession != null) {
                        openScreen(context, const SessionScreen());
                        return;
                      }
                      final ok = await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => AppScope(store: store, child: StartSessionSheet(preselect: boss.id, minutes: 60)),
                      );
                      if (ok == true && context.mounted) openScreen(context, const SessionScreen());
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tes coups', style: K.display(16)),
                  Text(hits.isEmpty ? 'Aucune session sur lui pour l\'instant.' : '${hits.length} session${hits.length > 1 ? 's' : ''} · une barre par coup, hauteur = minutes', style: K.body(12, color: K.muted)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 90,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < slots; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (i < hits.length)
                                    Text('${hits[i].actualMin.round()}', style: K.body(9, color: K.muted)),
                                  Container(
                                    height: i < hits.length ? 8 + 60 * hits[i].actualMin / maxHit : 12,
                                    decoration: BoxDecoration(
                                      color: i < hits.length ? (hits[i].finished ? K.coral : K.coral.withValues(alpha: 0.5)) : K.raised,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                      border: i < hits.length ? null : Border.all(color: K.line, width: 2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Où tu en es', style: K.display(16)),
                  Text('À la fin de chaque session sur le boss, on te le demande. Tu peux aussi l\'ajuster ici.', style: K.body(12, color: K.muted)),
                  Slider(
                    value: _drag ?? boss.bossProgress.toDouble(),
                    max: 100,
                    divisions: 20,
                    activeColor: K.coral,
                    label: '${(_drag ?? boss.bossProgress.toDouble()).round()} %',
                    onChanged: (v) => setState(() => _drag = v),
                    onChangeEnd: (v) async {
                      setState(() => _drag = null);
                      await store.setBossProgress(boss, v.round());
                    },
                  ),
                  if (boss.bossProgress >= 90 && !boss.done)
                    PrimaryButton(label: 'Boss vaincu !', color: K.gold, onPressed: () => store.setBossProgress(boss, 100)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
