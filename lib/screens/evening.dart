import 'package:flutter/material.dart';

import '../agenda.dart';
import '../main.dart';
import '../models.dart';
import '../notifications.dart';
import '../store.dart';
import '../theme.dart';
import 'checkin.dart';
import 'habits.dart';
import 'house.dart';
import 'notebook.dart';
import 'problems.dart';
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
                  Text(store.evening.eveningDone ? 'Journée close. Repose-toi !' : 'On fait le point avant de dormir',
                      style: K.body(14, color: K.muted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: store.evening.eveningDone ? 'Revoir mon feu de camp' : 'Allumer le feu de camp',
          color: K.coral,
          onPressed: () => openScreen(context, const EveningScreen()),
        ),
        if (store.evening.eveningDone)
          Center(
            child: TextButton(
              onPressed: () => store.reopenEvening(store.eveningKey),
              child: Text('Clos par erreur ? Rouvrir le feu de camp', style: K.body(12, color: K.muted)),
            ),
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
            final mins = store.proMinutesOn(k).round();
            final xp = store.xpOn(k);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: K.card,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text('${names[d.weekday - 1]} ${d.day}/${d.month}', style: K.body(15)),
                  subtitle: Text('$mins min de pro · +$xp XP', style: K.body(12, color: K.muted)),
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
  final _spawn = TextEditingController();
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
    _spawn.text = AppScope.read(context).plan(AppScope.read(context).tomorrowKey).spawn;
  }

  @override
  void dispose() {
    _win.dispose();
    _brake.dispose();
    _tomorrow.dispose();
    _spawn.dispose();
    super.dispose();
  }

  Future<void> _saveJournal() async {
    final store = AppScope.read(context);
    final p = store.evening;
    p.win = _win.text.trim();
    p.brake = _brake.text.trim();
    p.tomorrow = _tomorrow.text.trim();
    store.plan(store.tomorrowKey).spawn = _spawn.text.trim();
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
    final day = store.eveningKey;
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
                  onPressed: () => openScreen(context, HandwritingPage(note: store.noteFor(store.eveningKey, 'soir'))),
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
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final start = store.workStart(day);
              final prep = store.prepMinutes(day).round();
              final pro = store.proMinutesOn(day).round();
              return Row(children: [
                Expanded(child: _tile(start == null ? '—' : hm(start), 'début du travail', start == null ? K.muted : (start.hour >= 11 ? K.coral : K.lime))),
                const SizedBox(width: 8),
                Expanded(child: _tile(pro >= 60 ? '${pro ~/ 60} h ${(pro % 60).toString().padLeft(2, '0')}' : '$pro min', 'de pro en tout', K.lime)),
                const SizedBox(width: 8),
                Expanded(child: _tile(prep >= 60 ? '${prep ~/ 60} h ${(prep % 60).toString().padLeft(2, '0')}' : '$prep min', 'à me préparer', prep > 60 ? K.coral : K.cyan)),
              ]);
            }),
            const SizedBox(height: 12),
            _GainsRecap(day: day),
            const SizedBox(height: 12),
            SelfCompareCard(day: day),
            const SizedBox(height: 12),
            ProblemsFireCard(day: day),
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
                  const SizedBox(height: 6),
                  Text('Point de spawn de demain : un geste ce soir pour que demain démarre sans friction.',
                      style: K.body(12, color: K.muted)),
                  _field(_spawn, 'ouvrir le fichier, préparer le sac, téléphone loin du lit…', K.gold),
                ],
              ),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: store.evening.eveningDone ? 'Voir le replay de ma journée' : 'Clore la journée · ouvrir le coffre',
              color: K.coral,
              onPressed: () async {
                await _saveJournal();
                final chest = await store.finishEvening();
                await rescheduleAll(store);
                if (!context.mounted) return;
                if (chest.isNotEmpty) await showLoot(context, store, chest);
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
    'pill': K.coral,
    'calm': K.pink,
    'idle': K.dim,
    'slot': K.cyan,
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
    final mins = store.proMinutesOn(day).round();
    final plan = store.plan(day);
    final d = parseDay(day);

    return Scaffold(
      appBar: AppBar(title: Text(day == store.todayKey ? 'Ta journée en replay' : 'Replay du ${d.day}/${d.month}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        children: [
          Text('Tout ce que tu as fait, sans jugement', style: K.body(13, color: K.muted)),
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final start = store.workStart(day);
            final prep = store.prepMinutes(day).round();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(child: _tile(start == null ? '—' : hm(start), 'début du travail', start == null ? K.muted : (start.hour >= 11 ? K.coral : K.lime))),
                const SizedBox(width: 8),
                Expanded(child: _tile(prep >= 60 ? '${prep ~/ 60} h ${(prep % 60).toString().padLeft(2, '0')}' : '$prep min', 'à me préparer', prep > 60 ? K.coral : K.cyan)),
              ]),
            );
          }),
          Row(children: [
            Expanded(child: _tile(mins >= 60 ? '${mins ~/ 60} h ${(mins % 60).toString().padLeft(2, '0')}' : '$mins min', 'de pro', K.lime)),
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

/// Gains et trophées du jour : médaille, XP par source, butin, ruban.
/// « Par rapport à toi » : chaque mesure séparée, comparée à ta médiane des 21 derniers jours.
class SelfCompareCard extends StatelessWidget {
  final String day;
  const SelfCompareCard({super.key, required this.day});

  static String fmt(String k, double v) {
    switch (k) {
      case 'pro':
        final m = v.round();
        return m >= 60 ? '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')}' : '$m min';
      case 'focus':
        return '${v.toStringAsFixed(1).replaceAll('.', ',')} / 5';
      case 'prog':
        return '${v.round()} pts';
      case 'tasks':
        return '${v.round()}';
      case 'est':
        return '±${(v * 100).round()} %';
    }
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final m = store.dayMetrics(day);
    final known = store.selfDataDays(day);
    final rows = <Widget>[];
    for (final k in AppStore.selfLabels.keys) {
      final v = m[k];
      if (v == null) continue;
      final med = store.selfMedian(k, day);
      final st = store.selfStatus(k, v, med?.$1);
      rows.add(_row(k, v, med?.$1, st));
    }
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PAR RAPPORT À TOI', style: K.body(11, color: K.cyan, w: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(known < 5 ? 'Je découvre ta médiane : $known/5 jours notés. Les comparaisons arrivent bientôt.' : 'Médiane des 21 derniers jours. Bande claire = ta zone.',
            style: K.body(12, color: K.muted)),
        const SizedBox(height: 10),
        if (rows.isEmpty) Text('Rien à mesurer aujourd\'hui.', style: K.body(13, color: K.muted)) else ...rows,
        const SizedBox(height: 4),
        Text('En dessous de ta zone : journée légère, jamais de pénalité. Chaque mesure est séparée : on peut mal estimer et très bien travailler.',
            style: K.body(11, color: K.dim)),
      ]),
    );
  }

  Widget _row(String k, double v, double? med, int? st) {
    const colors = {1: Color(0xFF3E8E57), 0: Color(0xFF7FD6C2), -1: K.dim};
    final better = k == 'est' ? 'plus juste que d\'habitude ↑' : 'au-dessus ↑';
    final label = st == null ? '' : (st == 1 ? better : st == 0 ? 'dans ta zone' : 'journée légère');
    final col = colors[st] ?? K.muted;
    // position sur la barre : médiane au milieu, zone 80–120 % = 30 % à 70 %
    double pos = 0.5;
    if (med != null && med > 0) {
      final r = v / med;
      pos = (0.5 + (r - 1) * 1.0).clamp(0.03, 0.97);
      if (k == 'est') pos = 1 - pos;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Text(AppStore.selfLabels[k]!, style: K.body(13, w: FontWeight.w800))),
          Text(fmt(k, v), style: K.body(13, w: FontWeight.w900)),
          if (med != null) ...[
            const SizedBox(width: 6),
            Text('méd. ${fmt(k, med)}', style: K.body(11, color: K.dim)),
          ],
        ]),
        if (med != null) ...[
          const SizedBox(height: 5),
          LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            return SizedBox(
              height: 14,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(left: 0, right: 0, top: 3, height: 8, child: Container(decoration: BoxDecoration(color: K.raised, borderRadius: BorderRadius.circular(4)))),
                Positioned(left: w * 0.3, width: w * 0.4, top: 3, height: 8, child: Container(decoration: BoxDecoration(color: K.ink.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)))),
                Positioned(left: w * 0.5 - 1, top: 0, width: 2, height: 14, child: Container(color: K.dim)),
                Positioned(left: w * pos - 7, top: 0, width: 14, height: 14, child: Container(decoration: BoxDecoration(color: col, shape: BoxShape.circle))),
              ]),
            );
          }),
          const SizedBox(height: 3),
          Text(label, style: K.body(11, color: col, w: FontWeight.w800)),
        ],
      ]),
    );
  }
}

class _GainsRecap extends StatelessWidget {
  final String day;
  const _GainsRecap({required this.day});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final g = store.gainsOn(day);
    final medal = store.medalOn(day);
    final p = store.plan(day);
    const medalColors = [K.muted, Color(0xFFC98A5B), Color(0xFFC9C4E8), K.gold, K.gold];
    final pro = store.proMinutesOn(day).round();
    final entries = g.byReason.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Panel(
      border: medal >= 2 ? K.gold : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(medal == 4 ? Icons.workspace_premium_rounded : Icons.military_tech_rounded, color: medalColors[medal], size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  medal == 0
                      ? 'Pas de médaille aujourd\'hui'
                      : medal == 4
                          ? 'Couronne · journée parfaite !'
                          : 'Médaille ${AppStore.medalNames[medal].toLowerCase()}',
                  style: K.display(16, color: medalColors[medal]),
                ),
              ),
              if (p.persoGoalDone) const Pill('RUBAN', color: K.pink),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${pro >= 60 ? '${pro ~/ 60} h ${(pro % 60).toString().padLeft(2, '0')}' : '$pro min'} de pro${p.proGoalMin > 0 ? ' sur ${p.proGoalMin >= 60 ? '${p.proGoalMin ~/ 60} h' : '${p.proGoalMin} min'} visées' : ''}'
            '${p.persoGoal.isNotEmpty ? ' · perso : ${p.persoGoal}${p.persoGoalDone ? ' ✓' : ''}' : ''}',
            style: K.body(12, color: K.muted),
          ),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final e in entries.take(6))
              Row(children: [
                Expanded(child: Text(e.key, style: K.body(13))),
                Text('+${e.value}', style: K.display(13, color: K.lime)),
              ]),
          ],
          if (g.loot.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final l in g.loot) Pill(l, color: K.gold)],
            ),
          ],
        ],
      ),
    );
  }
}
