import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../crash.dart';
import '../models.dart';
import '../notifications.dart';
import '../store.dart';
import '../theme.dart';
import 'briefing.dart';
import 'budget.dart';
import 'checkin.dart';
import 'checkins_log.dart';
import 'habits.dart';
import 'settings.dart';
import 'block.dart';
import 'cabin.dart';
import 'problems.dart';
import 'direction.dart';
import 'dump.dart';
import 'help.dart';
import 'modes.dart' show ModePill;
import 'recap.dart' show RecapBanner;
import 'cards.dart' show CardsEntry;
import 'boss.dart';
import 'house.dart';
import 'task_panel.dart';

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
        CrashBanner(onClear: () async {
          await clearCrash();
          store.refresh();
        }),
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

        if (!plan.briefingDone) ...[
          Panel(
            border: K.gold,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MickySays('Bonjour ! On prépare la journée ? 2 minutes, promis.'),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Briefing du jour · +10 XP',
                  color: K.gold,
                  onPressed: () => openScreen(context, const BriefingScreen()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        const Padding(padding: EdgeInsets.only(bottom: 10), child: Align(alignment: Alignment.centerLeft, child: ModePill())),
        const RecapBanner(),
        const DirectionCard(),
        const SizedBox(height: 14),

        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Tes stats de personnage', style: K.display(16))),
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
        const SizedBox(height: 14),
        if (plan.proGoalMin > 0 || plan.persoGoal.isNotEmpty) ...[
          const DayGoalsCard(),
          const SizedBox(height: 14),
        ],
        const HabitsCard(),
        const SizedBox(height: 14),
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
        const SizedBox(height: 14),
        const HouseCard(),
        const SizedBox(height: 10),
        const CardsEntry(),
        const SizedBox(height: 14),
        const BudgetMiniCard(),
        const SizedBox(height: 18),

        Text('Noter vite', style: K.display(18)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _quick(context, Icons.edit_note_rounded, 'Je fais…', K.lime, () => openScreen(context, const CheckinScreen()))),
            const SizedBox(width: 8),
            Expanded(
                child: _quick(context, Icons.photo_camera_rounded, 'Repas', K.gold,
                    () => openScreen(context, const CheckinScreen(focusLog: LogKind.meal)))),
            const SizedBox(width: 8),
            Expanded(
                child: _quick(context, Icons.mood_rounded, 'Émotion', K.pink,
                    () => openScreen(context, const CheckinScreen(moodOnly: true)))),
            const SizedBox(width: 8),
            Expanded(
                child: _quick(context, Icons.bolt_rounded, 'Prise', K.cyan,
                    () => openScreen(context, const CheckinScreen(focusLog: LogKind.energy)))),
            const SizedBox(width: 8),
            Expanded(
                child: _quick(context, Icons.psychology_alt_rounded, 'Organiser mes idées', K.cyan,
                    () => openScreen(context, const DumpScreen()))),
          ],
        ),
        const SizedBox(height: 10),
        const HelpCard(),
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


  Widget _taskRow(BuildContext context, Task t) => Row(
        children: [
          CheckCircle(task: t, color: K.lime),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => showTaskPanel(context, t),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(t.title, style: K.body(14, color: t.done ? K.muted : K.ink).copyWith(decoration: t.done ? TextDecoration.lineThrough : null)),
              ),
            ),
          ),
          if (t.plannedAt > 0) Text(hm(DateTime.fromMillisecondsSinceEpoch(t.plannedAt)), style: K.body(12, color: K.gold, w: FontWeight.w900)),
        ],
      );

  Widget _bossCard(BuildContext context, Task? boss) {
    final store = AppScope.of(context);
    final has = boss != null;
    final minutes = has ? store.bossMinutes(boss) : 0;
    return Panel(
      color: const Color(0xFF2A1630),
      border: K.coral,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openScreen(context, const BossScreen()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: const Color(0xFF3A1F3E), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.pest_control_rounded, color: K.coral, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BOSS DE LA SEMAINE · +300 XP', style: K.body(11, color: const Color(0xFFFFB89A), w: FontWeight.w900)),
                      Text(has ? boss.title : 'Choisis ta plus grosse tâche pro', style: K.body(15, w: FontWeight.w800)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: K.muted),
              ],
            ),
            if (has) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 12,
                      color: const Color(0xFF3A1F3E),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: boss.bossProgress / 100,
                        child: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [K.coral, K.gold]))),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${boss.bossProgress} %', style: K.display(14, color: K.gold)),
              ]),
              const SizedBox(height: 4),
              Text('${store.bossHits(boss).length} coup${store.bossHits(boss).length > 1 ? 's' : ''} · $minutes min · touche pour attaquer', style: K.body(11, color: K.muted)),
            ],
          ],
        ),
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
          height: 76,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: c),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: K.body(label.length > 10 ? 10 : 12, w: FontWeight.w800).copyWith(height: 1.1)),
              ),
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

/// Objectifs du jour : temps pro (médaille) et objectif perso (ruban pour Micky).
class DayGoalsCard extends StatelessWidget {
  const DayGoalsCard({super.key});

  static String fmt(int m) => m >= 60 ? '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60}'}' : '$m min';

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = store.today;
    final pro = store.proMinutesOn(store.todayKey).round();
    final medal = store.medalOn(store.todayKey);
    const medalColors = [K.line, Color(0xFFC98A5B), Color(0xFFC9C4E8), K.gold, K.gold];
    return Panel(
      border: medal >= 2 ? K.gold : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Objectifs du jour', style: K.display(16))),
              if (medal > 0)
                Pill(medal == 4 ? 'COURONNE' : 'MÉDAILLE ${AppStore.medalNames[medal].toUpperCase()}',
                    color: medalColors[medal]),
            ],
          ),
          if (p.proGoalMin > 0) ...[
            const SizedBox(height: 10),
            Row(children: [
              Text('Temps pro', style: K.body(14)),
              const Spacer(),
              Text('${fmt(pro)} / ${fmt(p.proGoalMin)}', style: K.display(14, color: pro >= p.proGoalMin ? K.gold : K.lime)),
            ]),
            const SizedBox(height: 6),
            Bar((pro / p.proGoalMin).clamp(0.0, 1.0), color: pro >= p.proGoalMin ? K.gold : K.lime),
          ],
          if (p.persoGoal.isNotEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => store.setPersoGoalDone(!p.persoGoalDone),
              child: Row(
                children: [
                  Icon(p.persoGoalDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: p.persoGoalDone ? K.pink : K.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(p.persoGoal,
                        style: K.body(14, color: p.persoGoalDone ? K.muted : K.ink)
                            .copyWith(decoration: p.persoGoalDone ? TextDecoration.lineThrough : null)),
                  ),
                  Pill(p.persoGoalDone ? 'RUBAN GAGNÉ' : 'PERSO', color: K.pink),
                ],
              ),
            ),
          ],
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


/// Check-ins du jour : répondus et sans réponse, avec accès au journal pour corriger.
class MissedCheckins extends StatelessWidget {
  const MissedCheckins({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final missed = store.missedCheckins();
    final answered = store.checkinsOn(store.todayKey).length;
    if (missed.isEmpty && answered == 0) return const SizedBox.shrink();
    final shown = missed.length > 4 ? missed.sublist(missed.length - 4) : missed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Panel(
        border: missed.isEmpty ? null : K.cyan.withValues(alpha: 0.6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.schedule_rounded, color: K.cyan, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$answered check-in${answered > 1 ? 's' : ''} aujourd\'hui'
                  '${missed.isEmpty ? '' : ' · ${missed.length} sans réponse'}',
                  style: K.body(14, w: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: () => openScreen(context, const CheckinsLogScreen()),
                child: const Text('Journal'),
              ),
            ]),
            if (missed.isNotEmpty) ...[
              Text('Touche une heure pour dire ce que tu faisais à ce moment-là.', style: K.body(12, color: K.muted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in shown)
                    ActionChip(
                      label: Text(hm(t), style: K.body(13, w: FontWeight.w800)),
                      backgroundColor: K.raised,
                      side: BorderSide.none,
                      onPressed: () => openScreen(context, CheckinScreen(at: t)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

