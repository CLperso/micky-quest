import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'atelier.dart';
import 'canvas.dart';
import 'ink.dart';
import 'model.dart';
import 'pages/cover.dart';
import 'pages/day.dart';
import 'pages/free.dart';
import 'pages/future.dart';
import 'pages/goals.dart';
import 'pages/month.dart';
import 'pages/week.dart';
import 'store.dart';
import 'style_panel.dart';
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
    gTitleStyle = store.settings.titleStyle;
    return MaterialApp(
      title: 'Carnet Micky',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: pal.acc, brightness: pal.dark ? Brightness.dark : Brightness.light),
        scaffoldBackgroundColor: pal.desk,
        fontFamily: 'Nunito',
      ),
      home: const Shell(),
    );
  }
}

// onglets de l'agenda
const tCover = 0, tDay = 1, tWeek = 2, tMonth = 3, tFuture = 4, tGoals = 5, tColls = 6, tPages = 7;
const tabNames = ['Couverture', 'Jour', 'Semaine', 'Mois', 'Futur', 'Objectifs', 'Collections', 'Pages'];

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  final desk = Desk();
  int tab = tDay;
  DateTime day = dateOnly(DateTime.now());
  DateTime monday = mondayOf(DateTime.now());
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String goalSel = '';
  String collSel = '';
  String freeSel = '';
  int narrowPage = 0;
  bool styleOpen = false;
  Timer? _tick, _syncTick;
  String? _syncMsg;

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
        tab = tDay;
        day = parseDay(k);
        narrowPage = 0;
      });

  void _setTab(int i) => setState(() {
        tab = i;
        narrowPage = 0;
        desk.select('');
        desk.clearSel(notify: false);
      });

  (String, Widget, String, Widget?, String, String) _spread(Store store) {
    switch (tab) {
      case tCover:
        return ('cover', const CoverPage(), '', null, 'Couverture', '');
      case tWeek:
        final k = dayKey(monday);
        return ('week:$k:L', WeekGrid(monday: monday, onOpenDay: openDay), 'week:$k:R', WeekList(monday: monday, onOpenDay: openDay), 'Trackers', 'Jours');
      case tMonth:
        final m = monthKey(month);
        return ('month:$m:L', MonthCalendar(month: m, onOpenDay: openDay), 'month:$m:R', MonthList(month: m), 'Calendrier', 'Liste');
      case tFuture:
        return ('future:L', const FuturePage(fromOffset: 1, count: 3), 'future:R', const FuturePage(fromOffset: 4, count: 3, withSomeday: true), '3 mois', 'Plus loin');
      case tGoals:
        final sel = goalSel.isNotEmpty ? goalSel : (store.activeGoals.isEmpty ? '' : store.activeGoals.first.id);
        return (
          'goals:L',
          GoalsIndex(
              selected: sel,
              onSelect: (id) => setState(() {
                    goalSel = id;
                    narrowPage = 1;
                  })),
          'goal:$sel',
          GoalDetail(goalId: sel),
          'Objectifs',
          'Détail'
        );
      case tColls:
        final sel = collSel.isNotEmpty ? collSel : (store.activeColls.isEmpty ? '' : store.activeColls.first.id);
        return (
          'colls:L',
          CollIndex(
              selected: sel,
              onSelect: (id) => setState(() {
                    collSel = id;
                    narrowPage = 1;
                  })),
          'coll:$sel',
          CollPage(collId: sel),
          'Index',
          'Collection'
        );
      case tPages:
        final free = store.activeFree;
        final sel = free.any((p) => p.id == freeSel) ? freeSel : (free.isEmpty ? '' : free.first.id);
        return (
          'pages:L',
          FreeIndex(
              selected: sel,
              onSelect: (id) => setState(() {
                    freeSel = id;
                    narrowPage = 1;
                  })),
          'free:$sel',
          FreePageView(id: sel),
          'Index',
          'Page'
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

  Future<void> _recognize() async {
    final store = StoreScope.read(context);
    final page = desk.focusPage;
    final lines = await recognizeInk(store, desk, page);
    if (!mounted) return;
    if (lines == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reconnaissance indisponible pour l’instant (modèle à télécharger, connexion ?)')));
      return;
    }
    if (lines.isEmpty) return;
    await _inkTo(page, lines);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lines.length} ligne${lines.length > 1 ? 's' : ''} ajoutée${lines.length > 1 ? 's' : ''}')));
    }
  }

  void _nav(int dir) => setState(() {
        if (tab == tDay) day = day.add(Duration(days: dir));
        if (tab == tWeek) monday = monday.add(Duration(days: 7 * dir));
        if (tab == tMonth) month = DateTime(month.year, month.month + dir, 1);
      });

  void _home() => setState(() {
        day = dateOnly(DateTime.now());
        monday = mondayOf(DateTime.now());
        month = DateTime(DateTime.now().year, DateTime.now().month, 1);
      });

  String _navLabel() {
    if (tab == tDay) {
      final t = dateOnly(DateTime.now());
      final diff = day.difference(t).inDays;
      if (diff == 0) return 'Aujourd’hui';
      if (diff == -1) return 'Hier';
      if (diff == 1) return 'Demain';
      return '${dayNames[day.weekday - 1]} ${day.day} ${monthNames[day.month - 1]}';
    }
    if (tab == tWeek) return 'Sem. ${isoWeek(monday)}';
    return niceMonth(monthKey(month));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = Pal.byId(store.settings.theme);
    final (lk, lw, rk, rw, ln, rn) = _spread(store);
    if (desk.focusPage != lk && desk.focusPage != rk) desk.focusPage = lk;
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    Widget modeBtn(String tip, IconData icon, bool on, VoidCallback? f) => Tooltip(
          message: tip,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: f,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 42,
              height: 38,
              decoration: BoxDecoration(color: on ? pal.acc : Colors.transparent, borderRadius: BorderRadius.circular(999)),
              child: Icon(icon, size: 20, color: on ? Colors.white : (f == null ? pal.line : pal.ink)),
            ),
          ),
        );

    final header = SizedBox(
      height: 50,
      child: Row(children: [
        const SizedBox(width: 14),
        if (tab == tDay || tab == tWeek || tab == tMonth) ...[
          IconButton(onPressed: () => _nav(-1), icon: Icon(Icons.chevron_left_rounded, color: pal.ink)),
          GestureDetector(onTap: _home, child: Text(_navLabel(), style: titleFont(22, pal.ink))),
          IconButton(onPressed: () => _nav(1), icon: Icon(Icons.chevron_right_rounded, color: pal.ink)),
        ] else
          Text(tabNames[tab], style: titleFont(22, pal.ink)),
        const Spacer(),
        if (store.timerStart != 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ActionChip(
              avatar: const Icon(Icons.timer_outlined, size: 18),
              label: Text('${store.timerMinutes} min'),
              onPressed: () async {
                final m = await store.stopTimer();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$m min ajoutées au temps pro')));
              },
            ),
          ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: pal.card, borderRadius: BorderRadius.circular(999), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))]),
          child: Row(children: [
            modeBtn('Utiliser', Icons.touch_app_outlined, desk.mode == Mode.use, () => desk.setMode(Mode.use)),
            modeBtn('Écrire et dessiner', Icons.edit_outlined, desk.mode == Mode.pen, () => desk.setMode(Mode.pen)),
            modeBtn('Décorer', Icons.auto_awesome_outlined, desk.mode == Mode.deco, () => desk.setMode(Mode.deco)),
            modeBtn('Annuler', Icons.undo_rounded, false, store.canUndo ? () => store.undo() : null),
          ]),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Mon style',
          onPressed: () => setState(() => styleOpen = !styleOpen),
          icon: Icon(Icons.palette_outlined, color: styleOpen ? pal.acc : pal.soft),
        ),
        IconButton(
          tooltip: _syncMsg ?? (store.settings.lastSync == 0 ? 'Synchroniser' : 'Synchronisé'),
          onPressed: () => _sync(manual: true),
          icon: Icon(_syncMsg == null ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, color: _syncMsg == null ? pal.soft : pal.acc),
        ),
        IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())), icon: Icon(Icons.tune_rounded, color: pal.soft)),
        const SizedBox(width: 6),
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
            floatingActionButton: desk.mode == Mode.use && !styleOpen
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
                    final side = desk.mode == Mode.deco ? const Atelier() : (styleOpen ? StylePanel(onClose: () => setState(() => styleOpen = false)) : null);
                    final planner = _Planner(
                      wide: wide,
                      tab: tab,
                      month: month.month,
                      onTab: _setTab,
                      onMonth: (m) => setState(() {
                        month = DateTime(month.year, m, 1);
                        tab = tMonth;
                      }),
                      left: PageSheet(pageKey: lk, flat: true, bare: tab == tCover, paperOverride: tab == tCover ? (coverStyles[store.settings.coverStyle] ?? pal.cover) : null, onInkLines: (l) => _inkTo(lk, l), child: lw),
                      right: rw == null ? null : PageSheet(pageKey: rk, flat: true, onInkLines: (l) => _inkTo(rk, l), child: rw),
                      leftName: ln,
                      rightName: rn,
                      narrowPage: narrowPage,
                      onNarrow: (i) => setState(() {
                        narrowPage = i;
                        desk.focus(i == 0 ? lk : rk);
                      }),
                      penBar: desk.mode == Mode.pen ? PenBar(onRecognize: android ? _recognize : null) : null,
                      zoom: desk.mode == Mode.pen,
                    );
                    if (wide) {
                      return Row(children: [
                        Expanded(child: planner),
                        if (side != null) Padding(padding: const EdgeInsets.fromLTRB(0, 6, 12, 12), child: SizedBox(width: 340, child: side)),
                      ]);
                    }
                    return Column(children: [
                      Expanded(child: planner),
                      if (side != null) SizedBox(height: 320, child: side),
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

/// L'agenda : la couverture autour, les onglets, la spirale entre les deux pages.
class _Planner extends StatelessWidget {
  final bool wide;
  final int tab, month;
  final ValueChanged<int> onTab, onMonth;
  final Widget left;
  final Widget? right;
  final String leftName, rightName;
  final int narrowPage;
  final ValueChanged<int> onNarrow;
  final Widget? penBar;
  final bool zoom;
  const _Planner(
      {required this.wide,
      required this.tab,
      required this.month,
      required this.onTab,
      required this.onMonth,
      required this.left,
      required this.right,
      required this.leftName,
      required this.rightName,
      required this.narrowPage,
      required this.onNarrow,
      required this.penBar,
      required this.zoom});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = Pal.byId(store.settings.theme);
    final cover = coverStyles[store.settings.coverStyle] ?? pal.cover;
    final tabs = pal.tabs;
    final sideW = wide ? 34.0 : 0.0;

    final topTabs = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < tabNames.length; i++)
          GestureDetector(
            onTap: () => onTab(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 4),
              padding: EdgeInsets.fromLTRB(14, tab == i ? 10 : 6, 14, 8),
              decoration: BoxDecoration(
                color: (i == tCover ? cover : tabs[(i - 1) % tabs.length]).withValues(alpha: tab == i ? 1 : 0.8),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Text(tabNames[i], style: body(12, pal.dark ? Colors.white : pal.ink, w: FontWeight.w800)),
            ),
          ),
      ]),
    );

    Widget pages;
    if (right == null) {
      pages = Center(child: left);
    } else if (wide) {
      pages = LayoutBuilder(builder: (context, b) {
        final ph = min(b.maxHeight, (b.maxWidth - 40) / 2 * pageH / pageW);
        final pw = ph * pageW / pageH;
        return Center(
          child: SizedBox(
            height: ph,
            width: pw * 2 + 40,
            child: Row(children: [SizedBox(width: pw, child: left), const _Spiral(), SizedBox(width: pw, child: right)]),
          ),
        );
      });
    } else {
      pages = Column(children: [
        SegmentedButton<int>(
          segments: [ButtonSegment(value: 0, label: Text(leftName)), ButtonSegment(value: 1, label: Text(rightName))],
          selected: {narrowPage},
          onSelectionChanged: (v) => onNarrow(v.first),
        ),
        const SizedBox(height: 8),
        Expanded(child: Center(child: narrowPage == 0 ? left : right!)),
      ]);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Stack(children: [
        // la couverture qui dépasse autour des pages
        Positioned.fill(
          top: 30,
          right: sideW,
          child: Container(
            decoration: BoxDecoration(
              color: cover,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 12))],
            ),
          ),
        ),
        Positioned(left: 22, right: sideW + 22, top: 0, height: 34, child: topTabs),
        if (wide)
          Positioned(
            right: 0,
            top: 76,
            bottom: 20,
            child: SingleChildScrollView(
              child: Column(children: [
                for (var m = 1; m <= 12; m++)
                  GestureDetector(
                    onTap: () => onMonth(m),
                    child: Container(
                      width: m == month && tab == tMonth ? 40 : 34,
                      height: 44,
                      margin: const EdgeInsets.only(bottom: 3),
                      decoration: BoxDecoration(
                        color: pal.dark ? monthTabColors[m - 1].withValues(alpha: .55) : monthTabColors[m - 1],
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                      ),
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: 1,
                          child: Text(monthNames[m - 1].substring(0, m == 6 || m == 7 ? 4 : 3).toUpperCase(), style: body(10, pal.dark ? Colors.white : pal.ink, w: FontWeight.w800).copyWith(letterSpacing: 1.2)),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        Positioned.fill(
          top: penBar != null ? 128 : 44,
          left: 14,
          right: sideW + 14,
          bottom: 14,
          child: ZoomBox(enabled: zoom, child: pages),
        ),
        if (penBar != null)
          Positioned(
            top: 42,
            left: 30,
            right: sideW + 30,
            child: Center(child: penBar!),
          ),
      ]),
    );
  }
}

/// Les anneaux de la spirale.
class _Spiral extends StatelessWidget {
  const _Spiral();
  @override
  Widget build(BuildContext context) {
    final pal = Pal.byId(StoreScope.of(context).settings.theme);
    return SizedBox(
      width: 40,
      child: LayoutBuilder(builder: (context, box) {
        final n = ((box.maxHeight - 30) / 27).floor().clamp(4, 40).toInt();
        return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < n; i++)
            Container(
              width: 38,
              height: 11,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: pal.dark ? const Color(0xFF7A7084) : const Color(0xFFBDB0A8), width: 2.5),
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: pal.dark ? const [Color(0xFF6A6274), Color(0xFF443D51)] : const [Color(0xFFF6F0EC), Color(0xFFD3C7C0)]),
              ),
            ),
        ]);
      }),
    );
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
