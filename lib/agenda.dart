import 'package:android_intent_plus/android_intent.dart';

/// Ouvre l'agenda du téléphone (Google Agenda) sur un nouvel événement prérempli.
/// L'événement apparaît ensuite partout où cet agenda est affiché (Notion Calendar compris).
Future<String?> addToPhoneAgenda(String title, DateTime day, {int? minutes, DateTime? at}) async {
  try {
    final allDay = at == null;
    final start = at ?? DateTime(day.year, day.month, day.day);
    final end = allDay ? start.add(const Duration(days: 1)) : start.add(Duration(minutes: minutes ?? 60));
    final intent = AndroidIntent(
      action: 'android.intent.action.INSERT',
      data: 'content://com.android.calendar/events',
      arguments: <String, dynamic>{
        'title': title,
        'beginTime': start.millisecondsSinceEpoch,
        'endTime': end.millisecondsSinceEpoch,
        'allDay': allDay,
        'description': 'Ajouté depuis Micky Quest',
      },
    );
    await intent.launch();
    return null;
  } catch (e) {
    return 'Impossible d\'ouvrir l\'agenda : $e';
  }
}
