import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'store.dart';

const _checkChannel = 'checkins';
const _dayChannel = 'journee';
const _quietChannel = 'confirmations';

final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

/// Ouvre un écran quand on touche une notification (type : checkin, briefing, soir, session).
void Function(String type)? onOpenFromNotification;

const _initSettings = InitializationSettings(
  android: AndroidInitializationSettings('@mipmap/ic_launcher'),
);

String? lastNotifError;
bool notificationsReady = false;
final List<DateTime> scheduledCheckins = [];

Future<void> initNotifications() async {
  tzdata.initializeTimeZones();
  try {
    await _plugin.initialize(
      _initSettings,
      onDidReceiveNotificationResponse: (r) => _handle(r, foreground: true),
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );
    notificationsReady = true;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final r = launch?.notificationResponse;
    if (launch?.didNotificationLaunchApp == true && r != null) {
      Future.delayed(const Duration(milliseconds: 900), () => _handle(r, foreground: true));
    }
  } catch (e) {
    lastNotifError = 'Initialisation : $e';
    rethrow;
  }
}

Future<bool> requestNotificationPermission() async {
  try {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final ok = await android?.requestNotificationsPermission();
    if (ok == false) lastNotifError = 'Notifications refusées dans les paramètres Android';
    return ok ?? true;
  } catch (e) {
    lastNotifError = 'Permission : $e';
    return false;
  }
}

/// Sans session : on ne présume de rien, le panneau complet est à un tap.
const _freeActions = [
  AndroidNotificationAction('other', 'Répondre', showsUserInterface: true),
  AndroidNotificationAction('pause', 'En pause', cancelNotification: false),
];

/// Pendant une session : un tap pour confirmer, sinon le panneau.
const _sessionActions = [
  AndroidNotificationAction('quest', 'Oui, dessus', cancelNotification: false),
  AndroidNotificationAction('other', 'J\'ai décroché', showsUserInterface: true),
];

const _checkinTitles = [
  'Micky jette un œil : tu fais quoi ?',
  'Petit check-in : tu fais quoi, là ?',
  'Micky s\'étire… et toi, tu fais quoi ?',
  'Coucou ! Tu es sur quoi en ce moment ?',
];

AndroidNotificationDetails _checkDetails({bool session = false, int timeoutMin = 30}) => AndroidNotificationDetails(
      _checkChannel,
      'Check-ins',
      channelDescription: 'Micky te demande ce que tu fais',
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFFB8FF3C),
      actions: session ? _sessionActions : _freeActions,
      // la notification reste jusqu'au check-in suivant ; après, on répond depuis le QG
      timeoutAfter: timeoutMin * 60 * 1000,
    );

AndroidNotificationDetails _dayDetails() => const AndroidNotificationDetails(
      _dayChannel,
      'Briefing et feu de camp',
      channelDescription: 'Les rendez-vous du matin et du soir',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFFFFD24A),
    );

/// Reprogramme check-ins, briefing, feu de camp et fin de pari.
Future<void> rescheduleAll(AppStore store) async {
  scheduledCheckins.clear();
  if (!notificationsReady) {
    try {
      await initNotifications();
    } catch (_) {
      return;
    }
  }
  try {
    await _plugin.cancelAll();
  } catch (e) {
    lastNotifError = 'Annulation : $e';
  }
  final s = store.settings;
  final now = DateTime.now();
  final rnd = Random();

  // fenêtre de la session en cours, sans check-in
  DateTime? quietFrom, quietTo;
  final run = store.runningSession;
  if (run != null && !s.checkinsDuringSession) {
    quietFrom = DateTime.fromMillisecondsSinceEpoch(run.start);
    quietTo = quietFrom.add(Duration(minutes: max(run.predictedMin + 15, (run.predictedMin * 1.5).round())));
  }

  for (var d = 0; d < 2; d++) {
    final day = DateTime(now.year, now.month, now.day).add(Duration(days: d));

    // check-ins
    final interval = max(15, s.intervalMin);
    var i = 0;
    for (var m = s.startHour * 60 + interval; m <= s.endHour * 60; m += interval) {
      final t = day.add(Duration(minutes: m));
      i++;
      if (!t.isAfter(now.add(const Duration(minutes: 1)))) continue;
      if (quietFrom != null && t.isAfter(quietFrom) && t.isBefore(quietTo!)) continue;
      if (store.pausedAt(t)) continue;
      final inSession = run != null && s.checkinsDuringSession && d == 0 && t.isBefore(now.add(const Duration(hours: 3)));
      await _schedule(
        id: 2000 + d * 200 + i,
        when: t,
        title: inSession ? 'Toujours sur « ${run.title} » ?' : _checkinTitles[rnd.nextInt(_checkinTitles.length)],
        body: inSession
            ? 'Un tap pour confirmer, ou dis ce qui s\'est passé.'
            : 'Touche pour dire sur quoi tu es, depuis quand et comment tu te sens.',
        details: _checkDetails(session: inSession, timeoutMin: interval),
        payload: jsonEncode({'type': 'checkin', 'ts': t.millisecondsSinceEpoch, 'task': inSession ? run.taskId : ''}),
      );
      scheduledCheckins.add(t);
    }

    // briefing
    final brief = day.add(Duration(hours: s.briefingHour, minutes: s.briefingMinute));
    final briefDone = d == 0 && store.today.briefingDone;
    if (brief.isAfter(now) && !briefDone) {
      await _schedule(
        id: 10 + d,
        when: brief,
        title: 'Bonjour ! On prépare la journée ?',
        body: 'Tes quêtes pro et perso, en 2 minutes.',
        details: _dayDetails(),
        payload: jsonEncode({'type': 'briefing'}),
      );
    }

    // feu de camp
    final eve = day.add(Duration(hours: s.eveningHour));
    final eveDone = d == 0 && store.today.eveningDone;
    if (eve.isAfter(now) && !eveDone) {
      await _schedule(
        id: 20 + d,
        when: eve,
        title: 'Feu de camp avec Micky',
        body: 'On range les tâches pas faites et on ouvre le coffre du soir.',
        details: _dayDetails(),
        payload: jsonEncode({'type': 'soir'}),
      );
    }
  }

  // rappels d'habitudes
  for (final h in store.activeHabits.where((h) => h.reminderMin >= 0)) {
    for (var d = 0; d < 2; d++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: d));
      final when = day.add(Duration(minutes: h.reminderMin));
      if (!when.isAfter(now)) continue;
      if (d == 0 && store.habitLevel(h, store.todayKey) > 0) continue;
      await _schedule(
        id: 3000 + (h.id.hashCode.abs() % 400) * 2 + d,
        when: when,
        title: h.cue.isNotEmpty ? '${h.cue} : ${h.name}' : 'C\'est l\'heure : ${h.name}',
        body: h.mini.isNotEmpty ? 'Pas le temps ? La version mini compte : ${h.mini}' : 'Un petit pas suffit.',
        details: const AndroidNotificationDetails(
          _dayChannel,
          'Briefing et feu de camp',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFF4FE3FF),
          actions: [
            AndroidNotificationAction('h2', 'Faite'),
            AndroidNotificationAction('h1', 'Version mini'),
          ],
        ),
        payload: jsonEncode({'type': 'habit', 'habit': h.id, 'day': dayKey(day)}),
      );
    }
  }

  // fin de la pause
  final pause = store.activePause;
  if (pause != null && pause.end > now.millisecondsSinceEpoch) {
    await _schedule(
      id: 40,
      when: DateTime.fromMillisecondsSinceEpoch(pause.end),
      title: 'Micky reprend les check-ins',
      body: 'Fin de ta pause « ${pause.label} ». Tu pourras toujours la prolonger depuis le QG.',
      details: _dayDetails(),
      payload: jsonEncode({'type': 'home'}),
    );
  }

  // fin du pari
  if (run != null) {
    final due = DateTime.fromMillisecondsSinceEpoch(run.start).add(Duration(minutes: run.predictedMin));
    if (due.isAfter(now)) {
      await _schedule(
        id: 30,
        when: due,
        title: 'Ton pari arrive à échéance',
        body: '${run.title} : ${run.predictedMin} min écoulées. Tu en es où ?',
        details: _dayDetails(),
        payload: jsonEncode({'type': 'session'}),
      );
    }
  }
}

Future<void> _schedule({
  required int id,
  required DateTime when,
  required String title,
  required String body,
  required AndroidNotificationDetails details,
  required String payload,
}) async {
  Future<void> go(AndroidScheduleMode mode) => _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when.toUtc(), tz.UTC),
        NotificationDetails(android: details),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
  try {
    await go(AndroidScheduleMode.exactAllowWhileIdle);
  } catch (_) {
    try {
      await go(AndroidScheduleMode.inexactAllowWhileIdle);
    } catch (e) {
      lastNotifError = 'Programmation : $e';
    }
  }
}

Future<void> showTestCheckin() async {
  if (!notificationsReady) {
    try {
      await initNotifications();
    } catch (_) {
      return;
    }
  }
  final ts = DateTime.now().millisecondsSinceEpoch;
  await _plugin.show(
    99,
    _checkinTitles.first,
    'Touche pour dire sur quoi tu es, depuis quand et comment tu te sens.',
    NotificationDetails(android: _checkDetails()),
    payload: jsonEncode({'type': 'checkin', 'ts': ts, 'task': ''}),
  );
}

// ---------- Réponses ----------

@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse r) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await _plugin.initialize(_initSettings);
  await _handle(r, foreground: false);
}

Future<void> _savePending(Map<String, dynamic> c) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final list = prefs.getStringList(kPendingKey) ?? [];
  list.add(jsonEncode(c));
  await prefs.setStringList(kPendingKey, list);
}

Future<void> _handle(NotificationResponse r, {required bool foreground}) async {
  var type = '';
  var task = '';
  var ts = DateTime.now().millisecondsSinceEpoch;
  try {
    final p = jsonDecode(r.payload ?? '{}') as Map<String, dynamic>;
    type = (p['type'] as String?) ?? '';
    task = (p['task'] as String?) ?? '';
    // l'heure de la réponse compte, pas celle de la notification
    if (p['answer'] != null) ts = (p['answer'] as num).toInt();
  } catch (_) {}
  final action = r.actionId ?? '';
  final id = r.id ?? 0;

  if (action == 'h1' || action == 'h2') {
    try {
      final p = jsonDecode(r.payload ?? '{}') as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final list = prefs.getStringList(kPendingHabitsKey) ?? [];
      list.add(jsonEncode({'habit': p['habit'], 'day': p['day'], 'level': action == 'h2' ? 2 : 1}));
      await prefs.setStringList(kPendingHabitsKey, list);
    } catch (_) {}
    await _plugin.cancel(id);
    if (foreground) onOpenFromNotification?.call('refresh');
    return;
  }

  if (action.isEmpty || action == 'other') {
    if (foreground) onOpenFromNotification?.call(type.isEmpty ? 'checkin' : type);
    return;
  }

  if (action == 'quest' || action == 'pause') {
    await _savePending({'ts': ts, 'act': action, 'task': action == 'quest' ? task : ''});
    // deuxième temps : l'humeur, en un tap aussi
    await _plugin.show(
      id,
      action == 'quest' ? 'Bien joué ! Et ton humeur ?' : 'Bonne pause ! Et ton humeur ?',
      'Touche la notification pour plus de nuances.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _quietChannel,
          'Suite des check-ins',
          importance: Importance.low,
          priority: Priority.low,
          timeoutAfter: 10 * 60 * 1000,
          actions: [
            AndroidNotificationAction('m2', 'Bof'),
            AndroidNotificationAction('m3', 'Ça va'),
            AndroidNotificationAction('m4', 'Bien'),
          ],
        ),
      ),
      payload: jsonEncode({'type': 'checkin', 'answer': ts, 'task': task}),
    );
  } else if (action.startsWith('m')) {
    final mood = int.tryParse(action.substring(1)) ?? 0;
    await _savePending({'ts': ts, 'act': '', 'mood': mood});
    await _plugin.cancel(id);
  }
  if (foreground) onOpenFromNotification?.call('refresh');
}
