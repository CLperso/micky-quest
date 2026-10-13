import 'package:flutter/material.dart';

import '../agenda.dart';
import '../main.dart';
import '../models.dart';
import '../notifications.dart';
import '../store.dart';
import '../theme.dart';
import 'checkin.dart';
import 'habits.dart';
import 'notebook.dart';
import 'reflect.dart';

/// Onglet « Soir » : accès au feu de camp et aux replays.
class EveningTab extends StatelessWidget {
  const EveningTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final now = DateTime.now();
    final days = [for (var i = 0; i < 7; i++) now.subtract(Duration(days: i))];
    const names = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(K.micky['happy']!, width: 76, height: 76, fit: BoxFit.cover),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Feu de camp', style: K.display(26)),
                  Text(store.today.eveningDone ? 'Journée close. Repose-toi !' : 'On fait le point avant de dormir',
                      style: K.body(14, color: K.muted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: store.today.eveningDone ? 'Revoir mon feu de camp' : 'Allumer le feu de camp',
          color: K.coral,
          onPressed: () => openScreen(context, const EveningScreen()),
        ),
        const SizedBox(height: 10),
        SecondaryButton(
          label: 'Replay d\'aujourd\'hui',
          onPressed: () => openScreen(context, ReplayScreen(day: store.todayKey)),
        ),
        const SizedBox(height: 22),
        Text('Les jours précédents', style: K.display(18)),
        const SizedBox(height: 8),
        for (final d in days.skip(1))
          Builder(builder: (context) {
            final k = dayKey(d);
            final mins = store.focusMinutes(k).round();
            final xp = store.xpOn(k);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: K.card,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text('${names[d.weekday - 1]} ${d.day}/${d.month}', style: K.body(15)),
                  subtitle: Text('$mins min de focus · +$xp XP', style: K.body(12, color: K.muted)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: K.muted),
                  onTap: () => openScreen(context, ReplayScreen(day: k)),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class EveningScreen extends StatefulWidget {
  const EveningScreen({super.key});

  @override
  State<EveningScreen> createState() => _EveningScreenState();
}

class _EveningScreenState extends State<EveningScreen> {
  final _win = TextEditingController();
  final _brake = TextEditingController();
  final _tomorrow = TextEditingController();
  bool _init = false;
  final Map<String, String> _done = {}; // tâche → choix

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final p = AppScope.read(context).today;
    _win.text = p.win;
    _brake.text = p.brake;
    _tomorrow.text = p.tomorrow;
  }

  @override
  void dispose() {
    _win.dispose();
    _brake.dispose();
    _tomorrow.dispose();
    super.dispose();
  }

  Future<void> _saveJournal() async {
    final store = AppScope.read(context);
    final p = store.today;
    p.win = _win.text.trim();
    p.brake = _brake.text.trim();
    p.tomorrow = _tomorrow.text.trim();
    await store.commit();
  }

  Future<void> _triage(Task t, String choice) async {
    final store = AppScope.read(context);
    switch (choice) {
      case 'tomorrow':
        await store.deferTask(t);
        setState(() => _done[t.id] = 'Reportée à demain');
        break;
      case 'delete':
        await store.removeTask(t);
        setState(() => _done[t.id] = 'Effacée');
        break;
      case 'agenda':
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 1)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          helpText: 'Quel jour dans ton agenda ?',
        );
        if (date == null || !mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: const TimeOfDay(hour: 9, minute: 0),
          helpText: 'À quelle heure ? (Annuler = toute la journée)',
        );
        if (!mounted) return;
        final at = time == null ? null : DateTime(date.year, date.month, date.day, time.hour, time.minute);
        final err = await addToPhoneAgenda(t.title, date, at: at, minutes: t.estimateMin > 0 ? t.estimateMin : 60);
        if (!mounted) return;
        if (err == null) {
          await store.removeTask(t);
          setState(() => _done[t.id] = 'Dans l\'agenda le ${date.day}/${date.month}');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final day = store.todayKey;
    final sess = store.sessionsOn(day).where((s) => !s.running).toList();
    final bets = sess.where((s) => s.finished && s.predictedMin > 0).toList();
    final won = bets.where((s) => s.onTarget).length;
    final pending = store.tasks.where((t) => t.day == day && !t.done && !t.removed && !_done.containsKey(t.id)).toList();
    final handled = _done.entries.toList();

    return PopScope(
      onPopInvokedWithResult: (_, __) => _saveJournal(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Feu de camp')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            const MickySays('Bravo pour ta journée. On range ce qui reste et on ouvre le coffre ?', ring: K.coral),
            const SizedBox(height: 14),
            if (isTablet(context)) ...[
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: K.ink,
                    side: const BorderSide(color: K.cyan, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => openScreen(context, HandwritingPage(note: store.noteFor(store.todayKey, 'soir'))),
                  icon: const Icon(Icons.draw_rounded, color: K.cyan),
                  label: Text('Écrire mon journal à la main', style: K.body(15, w: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(child: _tile('+${store.xpOn(day)}', 'XP du jour', K.lime)),
                const SizedBox(width: 8),
                Expanded(child: _tile('${sess.length}', 'sessions', K.cyan)),
                const SizedBox(width: 8),
                Expanded(child: _tile(bets.isEmpty ? '—' : '${(100 * won / bets.length).round()} %', 'paris réussis', K.gold)),
              ],
            ),
            const SizedBox(height: 12),
            if (store.activeHabits.isNotEmpty) ...[
              const HabitsCard(),
              const SizedBox(height: 12),
            ],
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Tâches pas faites', style: K.display(16)),
                    const Spacer(),
                    Text(pending.isEmpty ? 'tout est rangé' : '${pending.length} à ranger', style: K.body(12, color: K.muted)),
                  ]),
                  const SizedBox(height: 8),
                  for (final t in pending) ...[
                    Row(children: [
                      Expanded(child: Text(t.title, style: K.body(14, w: FontWeight.w800))),
                      if (!store.reflections.any((r) => r.taskId == t.id && r.kind == 'pasfaite' && dayKey(DateTime.fromMillisecondsSinceEpoch(r.ts)) == day))
                        TextButton(
                          onPressed: () => openScreen(context, ReflectionScreen(kind: 'pasfaite', taskId: t.id, title: t.title)),
                          child: const Text('Pourquoi ?'),
                        )
                      else
                        const Icon(Icons.check_circle_rounded, color: K.coral, size: 20),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: _triageBtn('Demain', K.lime, () => _triage(t, 'tomorrow'))),
                      const SizedBox(width: 6),
                      Expanded(child: _triageBtn('Agenda', K.cyan, () => _triage(t, 'agenda'))),
                      const SizedBox(width: 6),
                      Expanded(child: _triageBtn('Effacer', K.dim, () => _triage(t, 'delete'))),
                    ]),
                    const SizedBox(height: 12),
                  ],
                  for (final e in handled)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${store.taskById(e.key)?.title ?? ''} · ${e.value}', style: K.body(13, color: K.muted)),
                    ),
                  if (pending.isEmpty && handled.isEmpty) Text('Rien en suspens. Bravo !', style: K.body(13, color: K.muted)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Journal de bord', style: K.display(16)),
                  const SizedBox(height: 8),
                  _field(_win, 'Une victoire, même petite', K.lime),
                  _field(_brake, 'Ce qui m\'a freinée', K.coral),
                  _field(_tomorrow, 'Demain, je commence par', K.cyan),
                ],
              ),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: store.today.eveningDone ? 'Voir le replay de ma journée' : 'Clore la journée · ouvrir le coffre',
              color: K.coral,
              onPressed: () async {
                await _saveJournal();
                final chest = await store.finishEvening();
                await rescheduleAll(store);
                if (!context.mounted) return;
                if (chest.isNotEmpty) await showChest(context, chest);
                if (!context.mounted) return;
                Navigator.pop(context);
                openScreen(context, ReplayScreen(day: day));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(String v, String l, Color c) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Text(v, style: K.display(20, color: c, w: FontWeight.w700)),
          Text(l, style: K.body(11, color: K.muted)),
        ]),
      );

  Widget _triageBtn(String label, Color c, VoidCallback onTap) => SizedBox(
        height: 44,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: K.ink,
            side: BorderSide(color: c, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: EdgeInsets.zero,
          ),
          onPressed: onTap,
          child: Text(label, style: K.body(13, w: FontWeight.w800)),
        ),
      );

  Widget _field(TextEditingController c, String label, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: K.body(12, color: color, w: FontWeight.w900)),
            const SizedBox(height: 4),
            TextField(
              controller: c,
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              decoration: const InputDecoration(fillColor: K.bg),
            ),
          ],
        ),
      );
}

class ReplayScreen extends StatelessWidget {
  final String day;
  const ReplayScreen({super.key, required this.day});

  static const _kindColors = {
    'quest': K.lime,
    'mood': K.pink,
    'food': K.gold,
    'drink': K.cyan,
    'coffee': K.coral,
    'free': K.ink,
    'task': K.lime,
    'pause': K.gold,
    'habit': K.cyan,
    'expense': K.gold,
    'reflect': K.coral,
  };
  static const _actColors = {
    Act.pro: K.lime,
    Act.perso: K.pink,
    Act.quest: K.lime,
    Act.other: K.gold,
    Act.pause: K.pink,
    Act.phone: K.dim,
    Act.nothing: K.coral,
  };

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final ev = store.replay(day);
    final share = store.activityShare(day);
    final ratio = store.dayRatio(day);
    final mins = store.focusMinutes(day).round();
    final plan = store.plan(day);
    final d = parseDay(day);

    return Scaffold(
      appBar: AppBar(title: Text(day == store.todayKey ? 'Ta journée en replay' : 'Replay du ${d.day}/${d.month}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        children: [
          Text('Tout ce que tu as fait, sans jugement', style: K.body(13, color: K.muted)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _tile(mins >= 60 ? '${mins ~/ 60} h ${(mins % 60).toString().padLeft(2, '0')}' : '$mins min', 'de sessions', K.lime)),
            const SizedBox(width: 8),
            Expanded(
                child: _tile(ratio == null ? '—' : '×${ratio.toStringAsFixed(1).replaceAll('.', ',')}', 'réel ÷ prévu', K.cyan)),
          ]),
          if (share.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 14,
                child: Row(children: [
                  for (final e in share.entries)
                    Expanded(flex: e.value, child: Container(color: _actColors[e.key] ?? K.muted)),
                ]),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 12, runSpacing: 4, children: [
              for (final e in share.entries)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: _actColors[e.key] ?? K.muted, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text('${(Act.labels[e.key] ?? e.key).toLowerCase()} · ${e.value}', style: K.body(11, color: K.muted)),
                ]),
            ]),
          ],
          Builder(builder: (context) {
            final byTask = store.minutesByTask(day).entries.where((e) => e.value >= 1).toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            if (byTask.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Temps par tâche', style: K.display(15)),
                    const SizedBox(height: 6),
                    for (final e in byTask)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          Expanded(child: Text(store.keyTitle(e.key), style: K.body(13))),
                          Text('${e.value.round()} min', style: K.body(13, color: K.lime, w: FontWeight.w800)),
                        ]),
                      ),
                  ],
                ),
              ),
            );
          }),
          if (plan.pro.isNotEmpty || plan.perso.isNotEmpty) ...[
            const SizedBox(height: 12),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (plan.pro.isNotEmpty) Text('Quête pro : ${plan.pro}', style: K.body(13)),
                if (plan.perso.isNotEmpty) Text('Quête perso : ${plan.perso}', style: K.body(13)),
                if (plan.win.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Victoire : ${plan.win}', style: K.body(13, color: K.lime)),
                ],
              ]),
            ),
          ],
          const SizedBox(height: 14),
          if (ev.isEmpty) Text('Rien de noté ce jour-là.', style: K.body(14, color: K.muted)),
          for (var i = 0; i < ev.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 46,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(hm(DateTime.fromMillisecondsSinceEpoch(ev[i].ts)),
                          textAlign: TextAlign.right, style: K.body(12, color: K.muted, w: FontWeight.w800)),
                    ),
                  ),
                  SizedBox(
                    width: 24,
                    child: Column(children: [
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(color: _kindColors[ev[i].kind] ?? K.ink, shape: BoxShape.circle),
                      ),
                      if (i < ev.length - 1) Expanded(child: Container(width: 2, color: K.line)),
                    ]),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: ev[i].kind != 'mood'
                          ? null
                          : () {
                              final c = store.checkins.where((c) => c.ts == ev[i].ts).toList();
                              if (c.isNotEmpty) openScreen(context, CheckinScreen(existing: c.first));
                            },
                      child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ev[i].title, style: K.body(13, w: FontWeight.w800)),
                                if (ev[i].detail.isNotEmpty) Text(ev[i].detail, style: K.body(12, color: K.muted)),
                              ],
                            ),
                          ),
                          if (ev[i].photo.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            photo(ev[i].photo, size: 52),
                          ],
                        ],
                      ),
                    ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Text('Moyenne d\'humeur : ${_moodAvg(store)}', style: K.body(12, color: K.muted)),
        ],
      ),
    );
  }

  String _moodAvg(AppStore store) {
    final m = store.checkinsOn(day).where((c) => c.mood > 0).map((c) => c.mood).toList();
    if (m.isEmpty) return '—';
    final avg = m.reduce((a, b) => a + b) / m.length;
    return AppStore.moodLabels[(avg.round() - 1).clamp(0, 4)].toLowerCase();
  }

  Widget _tile(String v, String l, Color c) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: K.display(20, color: c, w: FontWeight.w700)),
          Text(l, style: K.body(12, color: K.muted)),
        ]),
      );
}
