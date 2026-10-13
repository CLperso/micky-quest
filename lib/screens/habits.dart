import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models.dart';
import '../notifications.dart';
import '../store.dart';
import '../theme.dart';
import 'plant.dart';

const habitColors = [0xFF4FE3FF, 0xFFB8FF3C, 0xFFFFD24A, 0xFFFF6FD8, 0xFFFF8A5B];

/// Carte du QG : une ligne par habitude active, un toucher pour cocher.
class HabitsCard extends StatelessWidget {
  const HabitsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final list = store.activeHabits;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Habitudes', style: K.display(16))),
              TextButton(
                onPressed: () => openScreen(context, const HabitsScreen()),
                child: Text(list.isEmpty ? 'Ajouter' : 'Gérer'),
              ),
            ],
          ),
          if (list.isEmpty)
            Text('Ajoute une habitude à ancrer, avec un déclencheur.', style: K.body(13, color: K.muted)),
          for (final h in list) HabitRow(habit: h),
          if (list.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Un toucher : faite · deux : version mini · trois : annuler', style: K.body(11, color: K.dim)),
            ),
        ],
      ),
    );
  }
}

class HabitRow extends StatelessWidget {
  final Habit habit;
  const HabitRow({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final h = habit;
    final c = Color(h.color);
    final lv = store.habitLevel(h, store.todayKey);
    final strength = store.habitStrength(h);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: '${h.name} : ${lv == 2 ? 'faite' : lv == 1 ? 'version mini' : 'pas encore faite'}',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () async {
                HapticFeedback.lightImpact();
                final next = await store.cycleHabit(h);
                if (!context.mounted || next == 0) return;
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  duration: const Duration(seconds: 2),
                  content: Text(next == 2 ? '${h.name} : faite ! +5 XP' : '${h.name} : version mini, ça compte ! +3 XP'),
                ));
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lv == 2 ? c : (lv == 1 ? c.withValues(alpha: 0.35) : Colors.transparent),
                  border: Border.all(color: c, width: 3),
                ),
                child: lv == 0
                    ? null
                    : Icon(lv == 2 ? Icons.check_rounded : Icons.remove_rounded, color: lv == 2 ? K.bg : K.ink, size: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => AppScope(store: store, child: HabitPlantSheet(habit: h)),
              ),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(h.name, style: K.body(15, w: FontWeight.w800))),
                  SizedBox(width: 30, height: 30, child: PlantView(strength: strength, color: c, size: 30)),
                ]),
                Text(
                  lv == 1 && h.mini.isNotEmpty
                      ? 'Mini : ${h.mini}'
                      : (h.cue.isNotEmpty ? h.cue : 'Pas de déclencheur'),
                  style: K.body(12, color: K.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Bar(strength, color: c, height: 5),
              ],
            ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(AppStore.strengthLabel(strength), style: K.body(11, color: c, w: FontWeight.w900)),
                Text('${store.habitDaysDone(h)}/7 j', style: K.body(11, color: K.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final active = store.activeHabits;
    final paused = store.habits.where((h) => h.archived).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Habitudes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        children: [
          const MickySays(
            'Une habitude s\'accroche à un déclencheur, pas à la volonté. Et rater un jour ne remet rien à zéro.',
            pose: 'window',
            ring: K.cyan,
          ),
          const SizedBox(height: 14),
          Text('Actives · ${active.length}/${Habit.maxActive}', style: K.display(18)),
          const SizedBox(height: 8),
          for (final h in active) ...[
            _card(context, h),
            const SizedBox(height: 10),
          ],
          if (active.length < Habit.maxActive)
            SecondaryButton(
              label: '+ Nouvelle habitude',
              onPressed: () => _edit(context, null),
            ),
          if (paused.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text('En pause', style: K.display(18)),
            const SizedBox(height: 8),
            for (final h in paused) ...[
              _card(context, h),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 14),
          Text(
            'La jauge monte à chaque jour fait (la version mini compte presque autant) et ne baisse que doucement. '
            'En moyenne, il faut environ deux mois pour qu\'un geste devienne automatique : sois patiente avec toi-même.',
            style: K.body(12, color: K.muted),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Habit h) {
    final store = AppScope.of(context);
    final c = Color(h.color);
    final s = store.habitStrength(h);
    final now = DateTime.now();
    return Panel(
      border: h.archived ? null : c.withValues(alpha: 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => AppScope(store: store, child: HabitPlantSheet(habit: h)),
                ),
                child: PlantView(strength: s, color: c, size: 56),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(h.name, style: K.display(17, color: h.archived ? K.muted : K.ink))),
              Pill(AppStore.strengthLabel(s), color: c),
              PopupMenuButton<String>(
                tooltip: 'Options',
                icon: const Icon(Icons.more_vert_rounded, color: K.muted),
                onSelected: (v) async {
                  if (v == 'edit') {
                    _edit(context, h);
                  } else if (v == 'pause' || v == 'resume') {
                    final err = await store.setHabitArchived(h, v == 'pause');
                    if (err != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                    }
                    await rescheduleAll(store);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                  PopupMenuItem(value: h.archived ? 'resume' : 'pause', child: Text(h.archived ? 'Réactiver' : 'Mettre en pause')),
                ],
              ),
            ],
          ),
          if (h.cue.isNotEmpty) Text('Déclencheur : ${h.cue}', style: K.body(13, color: K.muted)),
          if (h.mini.isNotEmpty) Text('Version mini : ${h.mini}', style: K.body(13, color: K.muted)),
          if (h.reminderMin >= 0)
            Text('Rappel à ${h.reminderMin ~/ 60}h${(h.reminderMin % 60).toString().padLeft(2, '0')}',
                style: K.body(13, color: K.muted)),
          const SizedBox(height: 10),
          // 14 derniers jours
          Row(
            children: [
              for (var i = 13; i >= 0; i--)
                Builder(builder: (_) {
                  final d = dayKey(now.subtract(Duration(days: i)));
                  final lv = store.habitLevel(h, d);
                  return Expanded(
                    child: GestureDetector(
                      onTap: h.archived ? null : () => store.cycleHabit(h, day: d),
                      child: Container(
                        height: 22,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: lv == 2 ? c : (lv == 1 ? c.withValues(alpha: 0.4) : K.raised),
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
          Text('14 derniers jours · touche un jour pour corriger un oubli', style: K.body(11, color: K.dim)),
          const SizedBox(height: 8),
          Bar(s, color: c, height: 7),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, Habit? h) async {
    final store = AppScope.read(context);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AppScope(store: store, child: HabitEditor(habit: h)),
    );
    await rescheduleAll(store);
  }
}

class HabitEditor extends StatefulWidget {
  final Habit? habit;
  const HabitEditor({super.key, this.habit});

  @override
  State<HabitEditor> createState() => _HabitEditorState();
}

class _HabitEditorState extends State<HabitEditor> {
  final _name = TextEditingController();
  final _cue = TextEditingController();
  final _mini = TextEditingController();
  int _color = habitColors.first;
  int _remind = -1;

  static const _cueIdeas = [
    'Après mon petit-déjeuner',
    'Après mon café',
    'En rentrant à la maison',
    'Après le déjeuner',
    'Avant de me coucher',
  ];

  @override
  void initState() {
    super.initState();
    final h = widget.habit;
    if (h != null) {
      _name.text = h.name;
      _cue.text = h.cue;
      _mini.text = h.mini;
      _color = h.color;
      _remind = h.reminderMin;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _cue.dispose();
    _mini.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          children: [
            Text(widget.habit == null ? 'Nouvelle habitude' : 'Modifier', style: K.display(22)),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Habitude', hintText: 'Kannada, lecture, étirements…'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _cue,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Déclencheur : juste après…', hintText: 'Après mon café'),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in _cueIdeas)
                  ActionChip(
                    label: Text(c, style: K.body(12)),
                    onPressed: () => setState(() => _cue.text = c),
                    backgroundColor: K.raised,
                    side: BorderSide.none,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _mini,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Version mini (les jours difficiles)',
                hintText: '2 minutes, une seule page…',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final c in habitColors)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(color: _color == c ? K.ink : Colors.transparent, width: 3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Rappel quotidien', style: K.body(15)),
              subtitle: Text(
                _remind < 0 ? 'Aucun' : '${_remind ~/ 60}h${(_remind % 60).toString().padLeft(2, '0')}',
                style: K.body(12, color: K.muted),
              ),
              value: _remind >= 0,
              onChanged: (v) async {
                if (!v) {
                  setState(() => _remind = -1);
                  return;
                }
                final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
                if (t != null) setState(() => _remind = t.hour * 60 + t.minute);
              },
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Enregistrer',
              onPressed: () async {
                if (_name.text.trim().isEmpty) return;
                final h = widget.habit ?? Habit(name: '', created: store.todayKey);
                h.name = _name.text.trim();
                h.cue = _cue.text.trim();
                h.mini = _mini.text.trim();
                h.color = _color;
                h.reminderMin = _remind;
                final err = await store.saveHabit(h);
                if (!context.mounted) return;
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                  return;
                }
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
