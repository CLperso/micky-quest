import 'dart:math';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'calendar.dart';
import 'crash.dart';
import 'notifications.dart';
import 'screens/next_sheet.dart';
import 'screens/briefing.dart';
import 'screens/cards.dart' show showPendingCard;
import 'screens/checkin.dart';
import 'screens/discoveries.dart';
import 'screens/evening.dart';
import 'screens/habits.dart';
import 'screens/home.dart';
import 'screens/house.dart';
import 'screens/matrix.dart';
import 'screens/notebook.dart';
import 'screens/session.dart';
import 'screens/timetable.dart';
import 'screens/today.dart';
import 'store.dart';
import 'sync.dart';
import 'theme.dart';

class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({super.key, required AppStore store, required super.child}) : super(notifier: store);

  static AppStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppStore read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

final navKey = GlobalKey<NavigatorState>();

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (d) {
      FlutterError.presentError(d);
      recordCrash(d.exception, d.stack);
    };
    ErrorWidget.builder = crashBox;
    await loadCrash();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: K.bg,
    ));
    final store = AppStore();
    store.onPlanChanged = PhoneCalendar.syncAll;
    try {
      await store.load();
    } catch (e, st) {
      await recordCrash(e, st);
    }
    try {
      await initNotifications();
    } catch (e) {
      debugPrint('Notifications indisponibles : $e');
    }
    runApp(AppScope(store: store, child: const MickyQuestApp()));
  }, (e, st) => recordCrash(e, st));
}

class MickyQuestApp extends StatelessWidget {
  const MickyQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Micky Quest',
      debugShowCheckedModeBanner: false,
      navigatorKey: navKey,
      theme: K.theme(),
      home: const Shell(),
    );
  }
}

/// Ouvre un écran par-dessus les onglets.
Future<T?> openScreen<T>(BuildContext context, Widget screen) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => screen));

/// Après une session ou une tâche faite : « et maintenant, tu vas faire quoi ? » dans l'appli,
/// sans notification, et le check-in des 20 prochaines minutes est annulé.
Future<void> askNext(BuildContext context, String message) async {
  final store = AppScope.read(context);
  store.skipCheckins();
  await rescheduleAll(store);
  if (context.mounted) await showNextSheet(context, message);
}

/// Lance le choix de la tâche et du pari, puis la session.
Future<void> startFocus(BuildContext context) async {
  final store = AppScope.read(context);
  if (store.runningSession != null) {
    await openScreen(context, const SessionScreen());
    return;
  }
  // sur la vague : le bouton ▶ propose d'abord de lancer la vague
  if (store.today.mode == 'vague') {
    final f = store.today.focus;
    final ft = store.taskById(f);
    final name = ft?.title ?? f;
    final focusTasks = store.daySequence().where((t) => !t.done && store.inFocus(t)).toList();
    final pick = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('🌊 Sur la vague', style: K.display(20)),
            Text('Session ouverte, sans pari ni check-in, pause-corps toutes les 90 min.', style: K.body(12, color: K.muted)),
            const SizedBox(height: 12),
            PrimaryButton(label: '▶ Lancer la vague · $name', color: K.cyan, onPressed: () => Navigator.pop(ctx, 'wave')),
            if (focusTasks.isNotEmpty) ...[
              const SizedBox(height: 8),
              SecondaryButton(label: '▶ Sur « ${focusTasks.first.title} »', onPressed: () => Navigator.pop(ctx, 'first')),
            ],
            TextButton(onPressed: () => Navigator.pop(ctx, 'other'), child: Text('Autre chose (session normale)', style: K.body(13, color: K.muted))),
          ]),
        ),
      ),
    );
    if (pick == null || !context.mounted) return;
    if (pick == 'first') return launchTask(context, focusTasks.first);
    if (pick == 'wave') {
      if (ft != null) return launchTask(context, ft);
      await store.startSession('', name, 0, category: 'pro', silent: true, flow: true);
      await rescheduleAll(store);
      if (context.mounted) await openScreen(context, const SessionScreen());
      return;
    }
  }
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => AppScope(store: store, child: const StartSessionSheet()),
  );
  if (ok == true && context.mounted) {
    await rescheduleAll(store);
    if (context.mounted) await openScreen(context, const SessionScreen());
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _tab = 0;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    onOpenFromNotification = (type) async {
      final ctx = navKey.currentContext;
      if (ctx == null) return;
      final store = AppScope.read(ctx);
      await store.mergePending();
      if (!ctx.mounted) return;
      switch (type) {
        case 'checkin':
          // juste après une tâche ou une session : pas de « tu fais quoi ? », la suite directement
          if (store.skippedAt(DateTime.now())) {
            showNextSheet(ctx, 'Et maintenant ?');
          } else {
            openScreen(ctx, const CheckinScreen());
          }
          break;
        case 'briefing':
          openScreen(ctx, const BriefingScreen());
          break;
        case 'soir':
          openScreen(ctx, const EveningScreen());
          break;
        case 'habit':
          openScreen(ctx, const HabitsScreen());
          break;
        case 'stopsession':
          if (store.runningSession != null) openScreen(ctx, SessionScreen(stopAt: pendingStopTs));
          pendingStopTs = null;
          break;
        case 'session':
          if (store.runningSession != null) openScreen(ctx, const SessionScreen());
          break;
        case 'remind':
          final p = pendingReminder;
          pendingReminder = null;
          if (p == null) break;
          final t = store.taskById(p.task);
          if (t == null || t.done || t.removed) break;
          if (p.action == 'go') {
            store.answerReminder(t, p.ts, 'go');
            await store.commit();
            if (ctx.mounted) launchTask(ctx, t);
          } else if (p.action == 'later') {
            openScreen(ctx, PostponeScreen(task: t, ts: p.ts));
          } else {
            openScreen(ctx, ReminderScreen(task: t, ts: p.ts));
          }
          break;
      }
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _startup();
    }
  }

  Future<void> _startup() async {
    final store = AppScope.read(context);
    await requestNotificationPermission();
    await rescheduleAll(store);
    await _sync();
  }

  Future<void> _sync() async {
    final store = AppScope.read(context);
    if (!Sync.configured(store)) return;
    final err = await Sync.run(store, tablet: isTablet(context));
    if (err == null) await rescheduleAll(store);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      final store = AppScope.read(context);
      await store.mergePending();
      await rescheduleAll(store);
      await _sync();
    } else if (state == AppLifecycleState.paused) {
      await _sync();
    }
  }

  void goTo(int tab) => setState(() => _tab = tab);

  bool _celebrating = false;

  void _maybeCelebrate(AppStore store) {
    final msg = store.pendingCelebration;
    if (msg == null || _celebrating) return;
    _celebrating = true;
    store.pendingCelebration = null;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctx = navKey.currentContext;
      if (ctx != null) await showBigChest(ctx, msg);
      final ctx2 = navKey.currentContext;
      if (ctx2 != null && store.lastObject.isNotEmpty) await showLoot(ctx2, store, '');
      _celebrating = false;
    });
  }

  bool _cardWaiting = false;

  /// Filet de sécurité : une carte gagnée ailleurs (briefing, matrice, soir…) s'affiche dès qu'on revient ici.
  void _maybeCard(AppStore store) {
    if (store.pendingCard == null || _cardWaiting) return;
    _cardWaiting = true;
    Future.delayed(const Duration(milliseconds: 1500), () async {
      _cardWaiting = false;
      if (!mounted || store.pendingCard == null) return;
      if (ModalRoute.of(context)?.isCurrent != true) return; // un écran ou une feuille est ouvert : on attendra
      await showPendingCard(context);
    });
  }

  String _staleAsked = '';

  /// Une session oubliée (depuis hier, ou plus de 8 h) : on ouvre l'écran pour la fermer à la bonne heure.
  /// Une session arrêtée toute seule (pas de réponse) : on le dit, et on peut corriger l'heure.
  void _maybeAutoStopped(AppStore store) {
    final s = store.pendingAutoStop;
    if (s == null) return;
    store.pendingAutoStop = null;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await rescheduleAll(store);
      final ctx = navKey.currentContext;
      if (ctx == null) return;
      final fix = await showDialog<bool>(
        context: ctx,
        builder: (c) => AlertDialog(
          title: const Text('Session arrêtée'),
          content: Text('« ${s.title} » s\'est arrêtée à ${hm(DateTime.fromMillisecondsSinceEpoch(s.end))} : pas de réponse à « toujours dessus ? ». Le temps jusque-là compte.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Corriger l\'heure')),
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('OK')),
          ],
        ),
      );
      if (fix != true) return;
      final c2 = navKey.currentContext;
      if (c2 == null) return;
      final t0 = await showTimePicker(context: c2, initialTime: TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(s.end)), helpText: 'ARRÊTÉE À QUELLE HEURE ?');
      if (t0 == null) return;
      final st = DateTime.fromMillisecondsSinceEpoch(s.start);
      s.end = max(s.start + 60000, min(DateTime.now().millisecondsSinceEpoch, DateTime(st.year, st.month, st.day, t0.hour, t0.minute).millisecondsSinceEpoch));
      await store.commit();
    });
  }

  void _maybeStale(AppStore store) {
    final s = store.runningSession;
    if (s == null || !store.isStale(s) || _staleAsked == s.id) return;
    _staleAsked = s.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = navKey.currentContext;
      if (ctx != null) openScreen(ctx, const SessionScreen());
    });
  }

  @override
  Widget build(BuildContext context) {
    _maybeAutoStopped(AppScope.of(context));
    _maybeStale(AppScope.of(context));
    _maybeCelebrate(AppScope.of(context));
    _maybeCard(AppScope.of(context));
    final wide = MediaQuery.of(context).size.width >= 840;
    final tablet = isTablet(context);
    final running = AppScope.of(context).runningSession != null;
    if (!tablet && _tab == 5) _tab = 0;

    final pages = [
      wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: HomeScreen(onGoTo: goTo)),
                const VerticalDivider(width: 1, color: K.line),
                const Expanded(flex: 4, child: MatrixScreen()),
              ],
            )
          : HomeScreen(onGoTo: goTo),
      _limit(QuestsTab(matrix: const MatrixScreen()), wide ? 900 : null),
      const SizedBox.shrink(),
      _limit(const DiscoveriesScreen(), wide ? 820 : null),
      _limit(const EveningTab(), wide ? 760 : null),
      const NotebookScreen(),
    ];
    final body = SafeArea(child: IndexedStack(index: _tab, children: pages));

    final focusBtn = Semantics(
      button: true,
      label: 'Lancer une session',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => startFocus(context),
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(color: running ? K.gold : K.lime, shape: BoxShape.circle),
          child: Icon(running ? Icons.timer_rounded : Icons.play_arrow_rounded, color: K.bg, size: 32),
        ),
      ),
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            Container(
              width: 96,
              decoration: const BoxDecoration(color: K.bg, border: Border(right: BorderSide(color: K.line))),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    focusBtn,
                    const SizedBox(height: 20),
                    _railItem(0, Icons.home_rounded, 'QG'),
                    _railItem(1, Icons.grid_view_rounded, 'Quêtes'),
                    _railItem(3, Icons.travel_explore_rounded, 'Découvertes'),
                    _railItem(4, Icons.local_fire_department_rounded, 'Soir'),
                    if (tablet) _railItem(5, Icons.draw_rounded, 'Carnet'),
                  ],
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: K.bg, border: Border(top: BorderSide(color: K.line))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Row(
              children: [
                _navItem(0, Icons.home_rounded, 'QG'),
                _navItem(1, Icons.grid_view_rounded, 'Quêtes'),
                Expanded(child: SizedBox(height: 58, child: Center(child: focusBtn))),
                _navItem(3, Icons.travel_explore_rounded, 'Découvertes'),
                _navItem(4, Icons.local_fire_department_rounded, 'Soir'),
                if (tablet) _navItem(5, Icons.draw_rounded, 'Carnet'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _limit(Widget child, double? maxWidth) => maxWidth == null
      ? child
      : Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
        );

  Widget _railItem(int i, IconData icon, String label) {
    final on = _tab == i;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => goTo(i),
        child: Container(
          width: 80,
          height: 66,
          decoration: BoxDecoration(color: on ? K.raised : Colors.transparent, borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: on ? K.lime : K.muted, size: 26),
              const SizedBox(height: 4),
              FittedBox(child: Text(label, style: K.body(12, color: on ? K.lime : K.muted, w: FontWeight.w800))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, String label) {
    final on = _tab == i;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => goTo(i),
        child: SizedBox(
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: on ? K.lime : K.muted, size: 22),
              const SizedBox(height: 2),
              FittedBox(
                child: Text(label, style: K.body(11, color: on ? K.lime : K.muted, w: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
