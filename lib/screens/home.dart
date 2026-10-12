import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../notifications.dart';
import '../store.dart';
import '../theme.dart';
import 'briefing.dart';
import 'checkin.dart';
import 'settings.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int) onGoTo;
  const HomeScreen({super.key, required this.onGoTo});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final plan = store.today;
    final now = DateTime.now();
    final phase = store.phaseOn(now);
    final cday = store.cycleDay(now);
    final boss = store.boss;
    final doNow = store.tasksIn(Quad.doNow);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: K.cyan, width: 3),
                      image: const DecorationImage(
                        image: AssetImage('assets/images/micky_face.webp'),
                        fit: BoxFit.cover,
                        alignment: Alignment(0, -0.3),
                      ),
                    ),
                  ),
                  Positioned(right: -6, bottom: -2, child: Pill('Niv. ${store.level}', color: K.bg, fill: K.gold)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_dayLabel(now), style: K.body(13, color: K.muted)),
                  Text(store.title, style: K.display(22)),
                  const SizedBox(height: 6),
                  Bar(store.xpInLevel / xpPerLevel, color: K.cyan),
                  const SizedBox(height: 3),
                  Text('${store.xpInLevel} / $xpPerLevel XP', style: K.body(12, color: K.muted)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: K.coral, size: 20),
                      Text('${store.streak}', style: K.display(16, w: FontWeight.w700)),
                      Text('jours', style: K.body(10, color: K.muted)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Réglages',
                  onPressed: () => openScreen(context, const SettingsScreen()),
                  icon: const Icon(Icons.tune_rounded, color: K.muted),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        const PauseSwitch(),
        const SizedBox(height: 14),

        if (!plan.briefingDone) ...[
          Panel(
            border: K.gold,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MickySays('Bonjour ! On prépare la journée ? 2 minutes, promis.'),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Briefing du matin · +30 XP',
                  color: K.gold,
                  onPressed: () => openScreen(context, const BriefingScreen()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Tes stats de personnage', style: K.display(16)),
                  const Spacer(),
                  if (phase != null) Pill('Cycle J$cday · $phase', color: K.pink),
                ],
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _stat('Focus', store.statFocus, K.lime)),
                const SizedBox(width: 16),
                Expanded(child: _stat('Sens du temps', store.statTime, K.cyan)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _stat('Constance', store.statConstancy, K.gold)),
                const SizedBox(width: 16),
                Expanded(child: _stat('Sérénité', store.statSerenity, K.pink)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 18),

        Row(
          children: [
            Text('Quêtes du jour', style: K.display(20)),
            const Spacer(),
            TextButton(onPressed: () => openScreen(context, const BriefingScreen()), child: const Text('Modifier')),
          ],
        ),
        const SizedBox(height: 6),
        _questCard(context, 'pro', 'PRO', plan.pro, K.lime),
        const SizedBox(height: 10),
        _questCard(context, 'perso', 'PERSO', plan.perso, K.pink),
        const SizedBox(height: 10),

        if (doNow.isNotEmpty)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Faire maintenant', style: K.display(15, color: K.lime)),
                  const Spacer(),
                  Text('${doNow.length}', style: K.body(14, color: K.muted)),
                ]),
                const SizedBox(height: 6),
                for (final t in doNow.take(4))
                  _taskRow(context, t),
              ],
            ),
          ),
        if (doNow.isNotEmpty) const SizedBox(height: 10),

        _bossCard(context, boss),
        const SizedBox(height: 18),

        Text('Noter vite', style: K.display(18)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _quick(context, Icons.edit_note_rounded, 'Check-in', K.lime, () => openScreen(context, const CheckinScreen()))),
            const SizedBox(width: 8),
            Expanded(
                child: _quick(context, Icons.photo_camera_rounded, 'Repas', K.gold,
                    () => openScreen(context, const CheckinScreen(focusLog: LogKind.meal)))),
            const SizedBox(width: 8),
            Expanded(
                child: _quick(context, Icons.bolt_rounded, 'Boisson', K.cyan,
                    () => openScreen(context, const CheckinScreen(focusLog: LogKind.energy)))),
            const SizedBox(width: 8),
            Expanded(
                child: _quick(context, Icons.add_rounded, 'Autre', K.pink,
                    () => openScreen(context, const CheckinScreen(focusLog: LogKind.free)))),
          ],
        ),
      ],
    );
  }

  static String _dayLabel(DateTime d) {
    const days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    const months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
  }

  Widget _stat(String label, int v, Color c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label, style: K.body(13))),
            Text('$v', style: K.body(13, color: c, w: FontWeight.w900)),
          ]),
          const SizedBox(height: 4),
          Bar(v / 20, color: c, height: 6),
        ],
      );

  Widget _questCard(BuildContext context, String cat, String tag, String goal, Color c) {
    final store = AppScope.of(context);
    final steps = store.questSteps(cat);
    final done = steps.where((s) => s.done).length;
    Task? next;
    for (final s in steps) {
      if (!s.done) {
        next = s;
        break;
      }
    }
    final complete = steps.isNotEmpty && done == steps.length;
    return Panel(
      border: complete ? c : (cat == 'pro' && goal.isNotEmpty ? c.withValues(alpha: 0.6) : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Pill(tag, color: K.bg, fill: c),
            const SizedBox(width: 8),
            Text(complete ? 'Quête accomplie !' : '${steps.length} étapes', style: K.body(12, color: K.muted)),
          ]),
          const SizedBox(height: 6),
          Text(goal.isEmpty ? 'Pas encore définie' : goal,
              style: K.body(17, w: FontWeight.w800, color: goal.isEmpty ? K.dim : K.ink)),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: steps[i].done ? c : K.raised,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  if (i < steps.length - 1) const SizedBox(width: 4),
                ],
              ],
            ),
          ],
          if (next != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Étape suivante : ${next.title}${next.estimateMin > 0 ? ' · ${next.estimateMin} min' : ''}',
                    style: K.body(13, color: K.muted),
                  ),
                ),
                IconButton(
                  tooltip: 'Lancer cette étape',
                  onPressed: () => startFocus(context),
                  icon: Icon(Icons.play_circle_fill_rounded, color: c, size: 32),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _taskRow(BuildContext context, Task t) {
    final store = AppScope.read(context);
    return InkWell(
      onTap: () => store.completeTask(t),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(t.done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                color: t.done ? K.lime : K.muted),
            const SizedBox(width: 10),
            Expanded(child: Text(t.title, style: K.body(14))),
          ],
        ),
      ),
    );
  }

  Widget _bossCard(BuildContext context, Task? boss) {
    return Panel(
      color: const Color(0xFF2A1630),
      border: K.coral,
      child: Row(
        children: [
          const Icon(Icons.pest_control_rounded, color: K.coral, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BOSS DE LA SEMAINE', style: K.body(12, color: const Color(0xFFFFB89A), w: FontWeight.w900)),
                Text(boss?.title ?? 'Choisis la tâche que tu repousses dans Quêtes (appui long)',
                    style: K.body(boss == null ? 13 : 15, w: FontWeight.w800, color: boss == null ? K.muted : K.ink)),
                if (boss != null) ...[
                  const SizedBox(height: 6),
                  Bar(boss.bossHp / 100, color: K.coral),
                ],
              ],
            ),
          ),
          if (boss != null) ...[
            const SizedBox(width: 10),
            Text('${boss.bossHp} PV', style: K.display(15, color: K.coral, w: FontWeight.w700)),
          ],
        ],
      ),
    );
  }

  Widget _quick(BuildContext context, IconData icon, String label, Color c, VoidCallback onTap) {
    return Material(
      color: K.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 70,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: c),
              const SizedBox(height: 4),
              Text(label, style: K.body(12, w: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}


/// Interrupteur des check-ins : on coupe pour un cours, une sortie… sans pénalité.
class PauseSwitch extends StatelessWidget {
  const PauseSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = store.activePause;
    final on = p == null;
    String sub;
    if (p == null) {
      sub = 'Toutes les ${store.settings.intervalMin} min, de ${store.settings.startHour} h à ${store.settings.endHour} h';
    } else if (p.end == 0) {
      sub = '${p.label} · jusqu\'à ce que tu réactives';
    } else {
      sub = '${p.label} · jusqu\'à ${hm(DateTime.fromMillisecondsSinceEpoch(p.end))}';
    }
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      color: on ? K.card : const Color(0xFF2A2240),
      border: on ? null : K.gold,
      child: Row(
        children: [
          Icon(on ? Icons.notifications_active_rounded : Icons.notifications_paused_rounded, color: on ? K.lime : K.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(on ? 'Check-ins actifs' : 'En pause, sans pénalité', style: K.body(15, w: FontWeight.w800)),
                Text(sub, style: K.body(12, color: K.muted)),
              ],
            ),
          ),
          Switch(
            value: on,
            onChanged: (v) async {
              if (v) {
                await store.stopPause();
              } else {
                final ok = await showModalBottomSheet<bool>(
                  context: context,
                  builder: (_) => AppScope(store: store, child: const _PauseSheet()),
                );
                if (ok != true) return;
              }
              await rescheduleAll(store);
            },
          ),
        ],
      ),
    );
  }
}

class _PauseSheet extends StatefulWidget {
  const _PauseSheet();

  @override
  State<_PauseSheet> createState() => _PauseSheetState();
}

class _PauseSheetState extends State<_PauseSheet> {
  String _label = Pause.labels.first;
  int _choice = 1;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final now = DateTime.now();
    final evening = DateTime(now.year, now.month, now.day, store.settings.endHour);
    final options = <String, DateTime?>{
      '1 h': now.add(const Duration(hours: 1)),
      '2 h': now.add(const Duration(hours: 2)),
      '3 h': now.add(const Duration(hours: 3)),
      if (evening.isAfter(now)) 'Jusqu\'à ce soir': evening,
      'Jusqu\'à ce que je réactive': null,
    };
    final keys = options.keys.toList();
    if (_choice >= keys.length) _choice = 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mettre les check-ins en pause', style: K.display(20)),
            const SizedBox(height: 4),
            Text('Aucune pénalité : ta série continue et la pause apparaît dans ton replay.',
                style: K.body(13, color: K.muted)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in Pause.labels)
                  ChoiceChip(
                    label: Text(l),
                    selected: _label == l,
                    onSelected: (_) => setState(() => _label = l),
                    selectedColor: K.gold,
                    labelStyle: K.body(14, color: _label == l ? K.bg : K.ink),
                    backgroundColor: K.raised,
                    side: BorderSide.none,
                    showCheckmark: false,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Pendant', style: K.body(13, color: K.muted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < keys.length; i++)
                  ChoiceChip(
                    label: Text(keys[i]),
                    selected: _choice == i,
                    onSelected: (_) => setState(() => _choice = i),
                    selectedColor: K.cyan,
                    labelStyle: K.body(14, color: _choice == i ? K.bg : K.ink),
                    backgroundColor: K.raised,
                    side: BorderSide.none,
                    showCheckmark: false,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Mettre en pause',
              color: K.gold,
              onPressed: () async {
                await store.startPause(_label, options[keys[_choice]]);
                if (context.mounted) Navigator.pop(context, true);
              },
            ),
          ],
        ),
      ),
    );
  }
}
