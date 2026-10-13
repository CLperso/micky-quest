import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'store.dart';

/// Agenda du téléphone (Google Agenda synchronisé sur Android) : lecture des événements
/// et écriture des blocs prévus. Tout est best-effort : sans permission, rien ne casse.
class PhoneCalendar {
  static final _plugin = DeviceCalendarPlugin();

  /// Un événement lu, prêt pour « Ma journée ».
  static Future<bool> requestAccess() async {
    try {
      var r = await _plugin.hasPermissions();
      if (r.isSuccess && r.data == true) return true;
      r = await _plugin.requestPermissions();
      return r.isSuccess && r.data == true;
    } catch (e) {
      debugPrint('Agenda : $e');
      return false;
    }
  }

  /// Agendas où l'on peut écrire.
  static Future<List<({String id, String name})>> writableCalendars() async {
    try {
      final r = await _plugin.retrieveCalendars();
      final out = <({String id, String name})>[];
      for (final c in r.data ?? <Calendar>[]) {
        if (c.id == null || c.isReadOnly == true) continue;
        out.add((id: c.id!, name: '${c.name ?? 'Agenda'}${c.accountName != null ? ' · ${c.accountName}' : ''}'));
      }
      return out;
    } catch (e) {
      debugPrint('Agenda : $e');
      return [];
    }
  }

  /// Événements d'un jour, tous agendas confondus.
  static Future<List<CalEvent>> eventsOn(DateTime day) async {
    final out = <CalEvent>[];
    try {
      final cals = await _plugin.retrieveCalendars();
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));
      for (final c in cals.data ?? <Calendar>[]) {
        if (c.id == null) continue;
        final r = await _plugin.retrieveEvents(c.id, RetrieveEventsParams(startDate: start, endDate: end));
        for (final e in r.data ?? <Event>[]) {
          if (e.start == null) continue;
          if ((e.title ?? '').startsWith('[Micky Quest]')) continue; // nos propres blocs
          out.add(CalEvent(
            id: e.eventId ?? '',
            title: e.title ?? '(sans titre)',
            start: e.start!.toLocal(),
            end: (e.end ?? e.start!.add(const Duration(hours: 1))).toLocal(),
            allDay: e.allDay ?? false,
            calendar: c.name ?? '',
          ));
        }
      }
    } catch (e) {
      debugPrint('Agenda : $e');
    }
    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }

  /// Écrit (ou met à jour) le bloc d'une tâche dans l'agenda choisi.
  static Future<void> writeBlock(AppStore store, Task t) async {
    final calId = store.settings.calendarId;
    if (calId.isEmpty || t.plannedAt == 0) return;
    try {
      final start = DateTime.fromMillisecondsSinceEpoch(t.plannedAt);
      final end = start.add(Duration(minutes: t.blockMin));
      final ev = Event(
        calId,
        eventId: t.calEventId.isEmpty ? null : t.calEventId,
        title: '[Micky Quest] ${t.title}',
        start: tz.TZDateTime.from(start.toUtc(), tz.UTC),
        end: tz.TZDateTime.from(end.toUtc(), tz.UTC),
      );
      final r = await _plugin.createOrUpdateEvent(ev);
      if (r != null && r.isSuccess && (r.data ?? '').isNotEmpty && r.data != t.calEventId) {
        t.calEventId = r.data!;
        await store.commit();
      }
    } catch (e) {
      debugPrint('Agenda : $e');
    }
  }

  /// Retire le bloc de l'agenda (tâche déplacée hors de la journée, faite, effacée…).
  static Future<void> removeBlock(AppStore store, Task t) async {
    final calId = store.settings.calendarId;
    if (calId.isEmpty || t.calEventId.isEmpty) return;
    try {
      await _plugin.deleteEvent(calId, t.calEventId);
    } catch (e) {
      debugPrint('Agenda : $e');
    }
    t.calEventId = '';
    await store.commit();
  }

  /// Après un changement de planning : écrit ce qui est placé, retire ce qui ne l'est plus.
  static Future<void> syncAll(AppStore store) async {
    if (store.settings.calendarId.isEmpty) return;
    for (final t in store.tasks) {
      if (t.plannedAt > 0 && !t.done && !t.removed) {
        await writeBlock(store, t);
      } else if (t.calEventId.isNotEmpty) {
        await removeBlock(store, t);
      }
    }
  }
}

class CalEvent {
  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String calendar;
  const CalEvent({required this.id, required this.title, required this.start, required this.end, required this.allDay, required this.calendar});
}
