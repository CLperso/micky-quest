import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'atelier.dart';
import 'canvas.dart';
import 'model.dart';
import 'pages/day.dart';
import 'pages/future.dart';
import 'pages/goals.dart';
import 'pages/month.dart';
import 'pages/week.dart';
import 'store.dart';
import 'sync.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store();
  await store.load();
  runApp(StoreScope(store: store, child: const CarnetApp()));
}

class CarnetApp extends StatelessWidget {
  const CarnetApp({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = Pal.byId(store.settings.theme);
    return MaterialApp(
      title: 'Carnet Micky',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: pal.acc, brightness: pal.dark ? Brightness.dark : Brightness.light),
        scaffoldBackgroundColor: pal.desk,
        textTheme: GoogleFonts.nunitoTextTheme(pal.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme),
      ),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  final desk = Desk();
  int tab = 0;
  DateTime day = dateOnly(DateTime.now());
  DateTime monday = mondayOf(DateTime.now());
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String goalSel = '';
  String collSel = '';
  int narrowPage = 0;
  Timer? _tick, _syncTick;
  String? _syncMsg;

  static const tabs = ['Aujourd’hui', 'Semaine', 'Mois', 'Futur', 'Objectifs', 'Collections'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    desk.addListener(() {
      if (mounted) setState(() {});
    });
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _syncTick = Timer.periodic(const Duration(minutes: 3), (_) => _sync());
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _syncTick?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || state == AppLifecycleState.paused) _sync();
  }

  Future<void> _sync({bool manual = false}) async {
    final store = StoreScope.read(context);
    if (!Sync.configured(store)) {
      if (manual) setState(() => _syncMsg = 'Synchro pas réglée');
      return;
    }
    final err = await Sync.run(store);
    if (mounted) setState(() => _syncMsg = err);
  }

  void openDay(String k) => setState(() {
        tab = 0;
        day = parseDay(k);
        narrowPage = 0;
      });

  (String, Widget, String, Widget, String, String) _spread(Store store) {
    switch (tab) {
      case 1:
        final k = dayKey(monday);
        return ('week:$k:L', WeekGrid(monday: monday, onOpenDay: openDay), 'week:$k:R', WeekList(monday: monday, onOpenDay: openDay), 'Trackers', 'Jours');
      case 2:
        final m = monthKey(month);
        return ('month:$m:L', MonthCalendar(month: m, onOpenDay: openDay), 'month:$m:R', MonthList(month: m), 'Calendrier', 'Liste');
      case 3:
        return ('future:L', const FuturePage(fromOffset: 1, count: 3), 'future:R', const FuturePage(fromOffset: 4, count: 3, withSomeday: true), '3 mois', 'Plus loin');
      case 4:
        final sel = goalSel.isNotEmpty ? goalSel : (store.activeGoals.isEmpty ? '' : store.activeGoals.first.id);
        return (
          'goals:L',
          GoalsIndex(selected: sel, onSelect: (id) => setState(() {
                goalSel = id;
                narrowPage = 1;
              })),
          'goal:$sel',
          GoalDetail(goalId: sel),
          'Objectifs',
          'Détail'
        );
      case 5:
        final sel = collSel.isNotEmpty ? collSel : (store.activeColls.isEmpty ? '' : store.activeColls.first.id);
        return (
          'colls:L',
          CollIndex(selected: sel, onSelect: (id) => setState(() {
                collSel = id;
                narrowPage = 1;
              })),
          'coll:$sel',
          CollPage(collId: sel),
          'Index',
          'Collection'
        );
      default:
        final k = dayKey(day);
        return ('day:$k:L', DayMorning(day: k), 'day:$k:R', DayEvening(day: k), 'Matin', 'Soir');
    }
  }

  /// Une ligne écrite à la main devient une vraie ligne du carnet.
  Future<void> _inkTo(String page, List<String> lines) async {
    final store = StoreScope.read(context);
    final parts = page.split(':');
    for (final l in lines) {
      switch (parts.first) {
        case 'day':
          if (parts.last == 'R') {
            final log = store.log(parts[1]);
            log.journal = log.journal.isEmpty ? l : '${log.journal}\n$l';
            await store.touchLog(log);
          } else {
            await store.addEntry(l, when: parts[1]);
          }
          break;
        case 'month':
          await store.addEntry(l, when: parts[1]);
          break;
        case 'coll':
          await store.addEntry(l, coll: parts[1]);
          break;
        case 'goal':
          await store.addEntry(l, when: 'someday', goal: parts[1]);
          break;
        default:
          await store.addEntry(l, when: 'someday');
      }
    }
  }

  void _nav(int dir) => setState(() {
        if (tab == 0) day = day.add(Duration(days: dir));
        if (tab == 1) monday = monday.add(Duration(days: 7 * dir));
        if (tab == 2) month = DateTime(month.year, month.month + dir, 1);
      });

  void _home() => setState(() {
        day = dateOnly(DateTime.now());
        monday = mondayOf(DateTime.now());
        month = DateTime(DateTime.now().year, DateTime.now().month, 1);
      });

  String _navLabel() {
    if (tab == 0) {
      final t = dateOnly(DateTime.now());
      final diff = day.difference(t).inDays;
      if (diff == 0) return 'Aujourd’hui';
      if (diff == -1) return 'Hier';
      if (diff == 1) return 'Demain';
      return '${dayNames[day.weekday - 1]} ${day.day} ${monthNames[day.month - 1]}';
    }
    if (tab == 1) return 'Sem. ${isoWeek(monday)}';
    return niceMonth(monthKey(month));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = Pal.byId(store.settings.theme);
    final (lk, lw, rk, rw, ln, rn) = _spread(store);
    if (desk.focusPage != lk && desk.focusPage != rk) desk.focusPage = lk;
    final tabColors = [pal.acc, pal.acc2, pal.acc3, const Color(0xFFB9A7FF), const Color(0xFFE8896B), const Color(0xFF7FA99B)];

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
      child: Row(children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < tabs.length; i++)
                GestureDetector(
                  onTap: () => setState(() {
                    tab = i;
                    narrowPage = 0;
                    desk.select('');
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 6),
                    padding: EdgeInsets.fromLTRB(14, tab == i ? 14 : 8, 14, 9),
                    decoration: BoxDecoration(
                      color: tabColors[i].withValues(alpha: tab == i ? 1 : 0.55),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    ),
                    child: Text(tabs[i], style: body(13, pal.dark ? const Color(0xFF15112B) : Colors.white, w: FontWeight.w900)),
                  ),
                ),
            ]),
          ),
        ),
        if (tab <= 2) ...[
          IconButton(onPressed: () => _nav(-1), icon: Icon(Icons.chevron_left_rounded, color: pal.ink)),
          GestureDetector(onTap: _home, child: Text(_navLabel(), style: body(14, pal.ink, w: FontWeight.w800))),
          IconButton(onPressed: () => _nav(1), icon: Icon(Icons.chevron_right_rounded, color: pal.ink)),
        ],
        if (store.timerStart != 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ActionChip(
              avatar: const Text('⏱'),
              label: Text('${store.timerMinutes} min'),
              onPressed: () async {
                final m = await store.stopTimer();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$m min ajoutées au temps pro')));
              },
            ),
          ),
        IconButton(
          tooltip: _syncMsg ?? (store.settings.lastSync == 0 ? 'Synchroniser' : 'Synchronisé'),
          onPressed: () => _sync(manual: true),
          icon: Icon(_syncMsg == null ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, color: _syncMsg == null ? pal.soft : pal.acc),
        ),
        IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())), icon: Icon(Icons.tune_rounded, color: pal.soft)),
      ]),
    );

    return DeskScope(
      desk: desk,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => quickCapture(context),
          const SingleActivator(LogicalKeyboardKey.space, control: true): () => quickCapture(context),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: pal.desk,
            floatingActionButton: desk.mode == Mode.use
                ? FloatingActionButton(
                    tooltip: 'Noter vite (Ctrl + K)',
                    backgroundColor: pal.acc,
                    foregroundColor: Colors.white,
                    onPressed: () => quickCapture(context),
                    child: const Icon(Icons.edit_note_rounded),
                  )
                : null,
            body: SafeArea(
              child: Column(children: [
                header,
                Expanded(
                  child: LayoutBuilder(builder: (context, box) {
                    final wide = box.maxWidth >= 900;
                    final page = (String k, Widget w, double tilt) => PageSheet(
                          pageKey: k,
                          tilt: tilt,
                          onInkLines: (l) => _inkTo(k, l),
                          child: w,
                        );
                    Widget spread;
                    if (wide) {
                      spread = Row(children: [
                        Expanded(child: Center(child: page(lk, lw, -0.3))),
                        const SizedBox(width: 14),
                        Expanded(child: Center(child: page(rk, rw, 0.3))),
                      ]);
                    } else {
                      spread = Column(children: [
                        SegmentedButton<int>(
                          segments: [ButtonSegment(value: 0, label: Text(ln)), ButtonSegment(value: 1, label: Text(rn))],
                          selected: {narrowPage},
                          onSelectionChanged: (v) => setState(() {
                            narrowPage = v.first;
                            desk.focus(narrowPage == 0 ? lk : rk);
                          }),
                        ),
                        const SizedBox(height: 8),
                        Expanded(child: Center(child: narrowPage == 0 ? page(lk, lw, 0) : page(rk, rw, 0))),
                      ]);
                    }
                    spread = Padding(padding: const EdgeInsets.fromLTRB(14, 10, 6, 14), child: spread);
                    final bar = ModeBar(vertical: wide, onInk: (k, l) => _inkTo(k, l));
                    if (wide) {
                      return Row(children: [
                        Expanded(child: spread),
                        Padding(padding: const EdgeInsets.only(right: 8), child: Center(child: bar)),
                        if (desk.mode == Mode.deco) const SizedBox(width: 330, child: Atelier()),
                      ]);
                    }
                    return Column(children: [
                      Expanded(child: spread),
                      bar,
                      if (desk.mode == Mode.deco) const SizedBox(height: 300, child: Atelier()),
                    ]);
                  }),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// La barre des modes : utiliser, écrire à la main, décorer, annuler.
class ModeBar extends StatelessWidget {
  final bool vertical;
  final Future<void> Function(String page, List<String> lines) onInk;
  const ModeBar({super.key, required this.vertical, required this.onInk});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final desk = DeskScope.of(context);
    final pal = Pal.byId(store.settings.theme);
    Widget btn(String tip, IconData icon, bool on, VoidCallback? f, {Color? color}) => Padding(
          padding: const EdgeInsets.all(4),
          child: Tooltip(
            message: tip,
            child: Material(
              color: on ? pal.acc : pal.card,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: f,
                child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 22, color: on ? Colors.white : (color ?? pal.ink))),
              ),
            ),
          ),
        );
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final items = <Widget>[
      btn('Utiliser', Icons.touch_app_rounded, desk.mode == Mode.use, () => desk.setMode(Mode.use)),
      btn('Écrire à la main', Icons.edit_rounded, desk.mode == Mode.pen, () => desk.setMode(Mode.pen)),
      btn('Décorer', Icons.palette_rounded, desk.mode == Mode.deco, () => desk.setMode(Mode.deco)),
      btn('Annuler', Icons.undo_rounded, false, store.canUndo ? () => store.undo() : null, color: store.canUndo ? pal.ink : pal.line),
      if (desk.mode == Mode.pen) ...[
        const SizedBox(width: 8, height: 8),
        for (final c in store.settings.palette.take(6))
          GestureDetector(
            onTap: () {
              desk.penColor = c;
              desk.eraser = false;
              desk.set();
            },
            child: Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(color: desk.penColor == c && !desk.eraser ? pal.acc : pal.line, width: 3),
              ),
            ),
          ),
        btn('Fin / épais', desk.penWidth > 3 ? Icons.line_weight_rounded : Icons.horizontal_rule_rounded, false, () {
          desk.penWidth = desk.penWidth > 3 ? 1.8 : (desk.penWidth > 2 ? 4.2 : 2.6);
          desk.set();
        }),
        btn('Surligneur', Icons.highlight_rounded, desk.highlighter, () {
          desk.highlighter = !desk.highlighter;
          desk.eraser = false;
          desk.set();
        }),
        btn('Gomme', Icons.auto_fix_normal_rounded, desk.eraser, () {
          desk.eraser = !desk.eraser;
          desk.set();
        }),
        if (android)
          btn('Mon écriture → lignes', Icons.text_fields_rounded, false, () async {
            final page = desk.focusPage;
            final lines = await recognizeInk(store, desk, page);
            if (!context.mounted) return;
            if (lines == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reconnaissance indisponible pour l’instant (modèle à télécharger, connexion ?)')));
              return;
            }
            if (lines.isEmpty) return;
            await onInk(page, lines);
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lines.length} ligne${lines.length > 1 ? 's' : ''} ajoutée${lines.length > 1 ? 's' : ''}')));
          }),
      ],
    ];
    if (vertical) return SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: items));
    return SizedBox(height: 56, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: items));
  }
}

/// Noter vite : une ligne, Entrée, rangée où il faut. Rien d'obligatoire.
Future<void> quickCapture(BuildContext context) async {
  final store = StoreScope.read(context);
  final pal = Pal.byId(store.settings.theme);
  final c = TextEditingController();
  final now = DateTime.now();
  var when = dayKey(now);
  var kind = 'task';
  var coll = '';
  var goal = '';
  final months = [for (var i = 0; i < 6; i++) monthKey(DateTime(now.year, now.month + i, 1))];
  Future<void> save(BuildContext ctx) async {
    final t = c.text.trim();
    if (t.isEmpty) return;
    await store.addEntry(t, when: when, kind: kind, coll: coll, goal: goal);
    if (ctx.mounted) Navigator.pop(ctx);
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: pal.paper,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      Widget chip(String label, bool on, VoidCallback f) => Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 6),
            child: ChoiceChip(label: Text(label), selected: on, onSelected: (_) => setState(f)),
          );
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('🐾 ', style: TextStyle(fontSize: 22)),
                Expanded(
                  child: TextField(
                    controller: c,
                    autofocus: true,
                    style: body(18, pal.ink),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(hintText: 'vaccins, inscription colloque, idée…', hintStyle: body(18, pal.soft, w: FontWeight.w600), border: InputBorder.none),
                    onSubmitted: (_) => save(ctx),
                  ),
                ),
                IconButton(onPressed: () => save(ctx), icon: Icon(Icons.send_rounded, color: pal.acc)),
              ]),
              Wrap(children: [
                chip('• tâche', kind == 'task', () => kind = 'task'),
                chip('○ rendez-vous', kind == 'event', () => kind = 'event'),
                chip('– note', kind == 'note', () => kind = 'note'),
              ]),
              Label('Quand', pal.soft),
              Wrap(children: [
                chip('Aujourd’hui', when == dayKey(now), () => when = dayKey(now)),
                chip('Demain', when == dayKey(now.add(const Duration(days: 1))), () => when = dayKey(now.add(const Duration(days: 1)))),
                for (final m in months) chip(niceMonth(m), when == m, () => when = m),
                chip('Un jour', when == 'someday', () => when = 'someday'),
                if (coll.isNotEmpty) chip('Juste dans la collection', when.isEmpty, () => when = ''),
              ]),
              if (store.activeColls.isNotEmpty) ...[
                Label('Collection', pal.soft),
                Wrap(children: [for (final x in store.activeColls) chip('${x.emoji} ${x.title}', coll == x.id, () => coll = coll == x.id ? '' : x.id)]),
              ],
              if (store.activeGoals.isNotEmpty) ...[
                Label('Vers un objectif', pal.soft),
                Wrap(children: [for (final g in store.activeGoals) chip('${g.emoji} ${g.title}', goal == g.id, () => goal = goal == g.id ? '' : g.id)]),
              ],
              Text('Entrée pour ranger · Ctrl + K pour ouvrir depuis n’importe où', style: body(11, pal.soft)),
            ]),
          ),
        ),
      );
    }),
  );
}

/// Réglages : ambiance, stylet, habitudes, synchro.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _repo = TextEditingController(text: StoreScope.read(context).settings.syncRepo);
  late final _tok = TextEditingController(text: StoreScope.read(context).settings.syncToken);
  String _msg = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = Pal.byId(store.settings.theme);
    return Scaffold(
      backgroundColor: pal.paper,
      appBar: AppBar(title: const Text('Réglages'), backgroundColor: pal.paper),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Label('Ambiance', pal.soft),
        Wrap(spacing: 8, children: [
          for (final t in Pal.all)
            ChoiceChip(
              label: Text(t.name),
              selected: store.settings.theme == t.id,
              onSelected: (_) async {
                store.settings.theme = t.id;
                await store.setPaper('default', color: t.paper.value);
                await store.touchSettings();
              },
            ),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Écrire seulement au stylet'),
          subtitle: const Text('Le doigt ne dessine pas (utile pour poser la main sur l’écran).'),
          value: store.settings.stylusOnly,
          onChanged: (v) {
            store.settings.stylusOnly = v;
            store.save();
            setState(() {});
          },
        ),
        Label('Habitudes suivies au feu de camp', pal.soft),
        for (final h in store.activeHabits)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(h.emoji, style: const TextStyle(fontSize: 22)),
            title: Text(h.name),
            subtitle: Text('${h.perWeek} jours par semaine'),
            onTap: () => _editHabit(h),
          ),
        TextButton.icon(onPressed: () => _editHabit(null), icon: const Icon(Icons.add_rounded), label: const Text('Une habitude')),
        Label('Synchronisation tablette ↔ PC', pal.soft),
        Text('Un dépôt GitHub privé et un jeton (le même que pour Micky Quest convient). Le carnet y est rangé dans carnet-micky.json.', style: body(12, pal.soft, w: FontWeight.w600)),
        TextField(controller: _repo, decoration: const InputDecoration(labelText: 'Dépôt (ex. CLperso/mes-donnees)')),
        TextField(controller: _tok, obscureText: true, decoration: const InputDecoration(labelText: 'Jeton GitHub')),
        const SizedBox(height: 10),
        Row(children: [
          FilledButton(
            onPressed: () async {
              store.settings.syncRepo = _repo.text.trim();
              store.settings.syncToken = _tok.text.trim();
              await store.save();
              setState(() => _msg = 'Synchro…');
              final e = await Sync.run(store);
              setState(() => _msg = e ?? 'Synchronisé ✓');
            },
            child: const Text('Enregistrer et synchroniser'),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(_msg, style: body(13, pal.ink))),
        ]),
        if (store.settings.lastSync > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Dernière synchro : ${DateTime.fromMillisecondsSinceEpoch(store.settings.lastSync).toString().substring(0, 16)}', style: body(12, pal.soft)),
          ),
      ]),
    );
  }

  Future<void> _editHabit(Habit? h) async {
    final store = StoreScope.read(context);
    final name = TextEditingController(text: h?.name ?? '');
    final emoji = TextEditingController(text: h?.emoji ?? '🌱');
    var per = h?.perWeek ?? 7;
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(h == null ? 'Une habitude' : 'Modifier'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nom')),
            TextField(controller: emoji, decoration: const InputDecoration(labelText: 'Emoji')),
            Row(children: [
              const Text('Jours par semaine'),
              const Spacer(),
              IconButton(onPressed: () => setState(() => per = (per - 1).clamp(1, 7)), icon: const Icon(Icons.remove)),
              Text('$per'),
              IconButton(onPressed: () => setState(() => per = (per + 1).clamp(1, 7)), icon: const Icon(Icons.add)),
            ]),
          ]),
          actions: [
            if (h != null) TextButton(onPressed: () => Navigator.pop(ctx, 'del'), child: const Text('Supprimer')),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'ok'), child: const Text('OK')),
          ],
        ),
      ),
    );
    if (r == null) return;
    if (r == 'del' && h != null) {
      h.del = true;
      h.mod = nowMs();
    } else if (name.text.trim().isNotEmpty) {
      final x = h ?? Habit(name: '');
      x
        ..name = name.text.trim()
        ..emoji = emoji.text.trim().isEmpty ? '🌱' : emoji.text.trim()
        ..perWeek = per
        ..mod = nowMs();
      store.habits[x.id] = x;
    }
    await store.commit();
    setState(() {});
  }
}
