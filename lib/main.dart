import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'notifications.dart';
import 'screens/briefing.dart';
import 'screens/checkin.dart';
import 'screens/discoveries.dart';
import 'screens/evening.dart';
import 'screens/home.dart';
import 'screens/matrix.dart';
import 'screens/session.dart';
import 'store.dart';
import 'theme.dart';

class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({super.key, required AppStore store, required super.child}) : super(notifier: store);

  static AppStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppStore read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

final navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: K.bg,
  ));
  final store = AppStore();
  await store.load();
  try {
    await initNotifications();
  } catch (e) {
    debugPrint('Notifications indisponibles : $e');
  }
  runApp(AppScope(store: store, child: const MickyQuestApp()));
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

/// Lance le choix de la tâche et du pari, puis la session.
Future<void> startFocus(BuildContext context) async {
  final store = AppScope.read(context);
  if (store.runningSession != null) {
    await openScreen(context, const SessionScreen());
    return;
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
          openScreen(ctx, const CheckinScreen());
          break;
        case 'briefing':
          openScreen(ctx, const BriefingScreen());
          break;
        case 'soir':
          openScreen(ctx, const EveningScreen());
          break;
        case 'session':
          if (store.runningSession != null) openScreen(ctx, const SessionScreen());
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
    }
  }

  void goTo(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onGoTo: goTo),
      const MatrixScreen(),
      const SizedBox.shrink(),
      const DiscoveriesScreen(),
      const EveningTab(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _tab, children: pages)),
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
                Expanded(
                  child: Center(
                    child: Semantics(
                      button: true,
                      label: 'Lancer une session',
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => startFocus(context),
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: AppScope.of(context).runningSession != null ? K.gold : K.lime,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            AppScope.of(context).runningSession != null ? Icons.timer_rounded : Icons.play_arrow_rounded,
                            color: K.bg,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _navItem(3, Icons.travel_explore_rounded, 'Découvertes'),
                _navItem(4, Icons.local_fire_department_rounded, 'Soir'),
              ],
            ),
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
