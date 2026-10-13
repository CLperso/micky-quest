import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../notifications.dart';
import '../sync.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _token = TextEditingController();
  final _db = TextEditingController();
  final _titleProp = TextEditingController();
  final _dateProp = TextEditingController();
  final _repo = TextEditingController();
  final _syncToken = TextEditingController();
  bool _init = false;
  bool _syncing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final s = AppScope.read(context).settings;
    _token.text = s.notionToken;
    _db.text = s.notionDb;
    _titleProp.text = s.notionTitleProp;
    _dateProp.text = s.notionDateProp;
    _repo.text = s.syncRepo;
    _syncToken.text = s.syncToken;
  }

  @override
  void dispose() {
    for (final c in [_token, _db, _titleProp, _dateProp, _repo, _syncToken]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _apply() async {
    final store = AppScope.read(context);
    final s = store.settings;
    s.notionToken = _token.text.trim();
    s.notionDb = _db.text.trim();
    s.notionTitleProp = _titleProp.text.trim().isEmpty ? 'Name' : _titleProp.text.trim();
    s.notionDateProp = _dateProp.text.trim().isEmpty ? 'Date' : _dateProp.text.trim();
    s.syncRepo = _repo.text.trim();
    s.syncToken = _syncToken.text.trim();
    await store.updateSettings();
    await rescheduleAll(store);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.settings;
    final upcoming = scheduledCheckins.where((t) => t.isAfter(DateTime.now())).toList();

    return PopScope(
      onPopInvokedWithResult: (_, __) => _apply(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Réglages')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
          children: [
            const SectionLabel('Check-ins'),
            Panel(
              child: Column(
                children: [
                  _stepper('Début de journée', '${s.startHour} h', () {
                    if (s.startHour > 5) s.startHour--;
                  }, () {
                    if (s.startHour < s.endHour - 1) s.startHour++;
                  }),
                  _stepper('Fin de journée', '${s.endHour} h', () {
                    if (s.endHour > s.startHour + 1) s.endHour--;
                  }, () {
                    if (s.endHour < 23) s.endHour++;
                  }),
                  _stepper('Toutes les', '${s.intervalMin} min', () {
                    s.intervalMin = s.intervalMin <= 15 ? 15 : s.intervalMin - 15;
                  }, () {
                    s.intervalMin = s.intervalMin >= 120 ? 120 : s.intervalMin + 15;
                  }),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Pendant les sessions aussi', style: K.body(15)),
                    subtitle: Text('Sinon, Micky te laisse tranquille pendant une session.', style: K.body(12, color: K.muted)),
                    value: s.checkinsDuringSession,
                    onChanged: (v) async {
                      s.checkinsDuringSession = v;
                      await _apply();
                    },
                  ),
                ],
              ),
            ),
            const SectionLabel('Rendez-vous'),
            Panel(
              child: Column(
                children: [
                  _stepper('Briefing du matin', '${s.briefingHour}h${s.briefingMinute.toString().padLeft(2, '0')}', () {
                    final m = s.briefingHour * 60 + s.briefingMinute - 15;
                    if (m >= 300) {
                      s.briefingHour = m ~/ 60;
                      s.briefingMinute = m % 60;
                    }
                  }, () {
                    final m = s.briefingHour * 60 + s.briefingMinute + 15;
                    if (m <= 12 * 60) {
                      s.briefingHour = m ~/ 60;
                      s.briefingMinute = m % 60;
                    }
                  }),
                  _stepper('Feu de camp', '${s.eveningHour} h', () {
                    if (s.eveningHour > 17) s.eveningHour--;
                  }, () {
                    if (s.eveningHour < 23) s.eveningHour++;
                  }),
                ],
              ),
            ),
            const SectionLabel('Cycle'),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.cycleStart.isEmpty ? 'Premier jour des dernières règles : non renseigné' : 'Dernières règles : ${_fr(s.cycleStart)}',
                          style: K.body(14),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 90)),
                            lastDate: DateTime.now(),
                            helpText: 'Premier jour des règles',
                          );
                          if (d != null) {
                            s.cycleStart = dayKey(d);
                            await _apply();
                          }
                        },
                        child: const Text('Choisir'),
                      ),
                    ],
                  ),
                  _stepper('Durée du cycle', '${s.cycleLength} j', () {
                    if (s.cycleLength > 20) s.cycleLength--;
                  }, () {
                    if (s.cycleLength < 40) s.cycleLength++;
                  }),
                  Text('Mets à jour la date à chaque début de règles pour garder les phases justes.',
                      style: K.body(12, color: K.muted)),
                ],
              ),
            ),
            const SectionLabel('Agenda'),
            Panel(
              child: Text(
                'Au feu de camp, le bouton « Agenda » ouvre ton agenda Google avec la tâche déjà remplie : '
                'choisis le jour, valide, et elle apparaît aussi dans Notion Calendar. Aucun réglage nécessaire.',
                style: K.body(13, color: K.muted),
              ),
            ),
            const SectionLabel('Synchronisation téléphone ↔ tablette'),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. Sur GitHub, crée un dépôt privé vide (par exemple micky-data).\n'
                    '2. Settings › Developer settings › Fine-grained tokens : un jeton limité à ce dépôt, '
                    'avec « Contents » en lecture et écriture.\n'
                    '3. Mets le même dépôt et le même jeton sur ton téléphone et ta tablette.',
                    style: K.body(13, color: K.muted),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: _repo, decoration: const InputDecoration(labelText: 'Dépôt (ex. CLperso/micky-data)')),
                  const SizedBox(height: 8),
                  TextField(controller: _syncToken, obscureText: true, decoration: const InputDecoration(labelText: 'Jeton GitHub')),
                  const SizedBox(height: 8),
                  Text(
                    s.lastSync == 0
                        ? 'Jamais synchronisé. Les photos de repas restent sur l\'appareil qui les a prises.'
                        : 'Dernière synchro : ${hm(DateTime.fromMillisecondsSinceEpoch(s.lastSync))}. Les photos de repas restent sur l\'appareil qui les a prises.',
                    style: K.body(12, color: K.muted),
                  ),
                  if (Sync.lastError != null) ...[
                    const SizedBox(height: 4),
                    Text(Sync.lastError!, style: K.body(12, color: K.coral)),
                  ],
                  const SizedBox(height: 10),
                  SecondaryButton(
                    label: _syncing ? 'Synchronisation…' : 'Synchroniser maintenant',
                    onPressed: _syncing
                        ? null
                        : () async {
                            await _apply();
                            if (!context.mounted) return;
                            setState(() => _syncing = true);
                            final err = Sync.configured(store)
                                ? await Sync.run(store, tablet: MediaQuery.of(context).size.shortestSide >= 600)
                                : 'Indique le dépôt et le jeton.';
                            await rescheduleAll(store);
                            if (!mounted) return;
                            setState(() => _syncing = false);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text(err ?? 'Synchronisé !')),
                            );
                          },
                  ),
                ],
              ),
            ),
            const SectionLabel('Notifications'),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${upcoming.length} check-ins programmés'
                      '${upcoming.isEmpty ? '' : ', prochain à ${hm(upcoming.first)}'}',
                      style: K.body(14)),
                  if (lastNotifError != null) ...[
                    const SizedBox(height: 4),
                    Text(lastNotifError!, style: K.body(12, color: K.coral)),
                  ],
                  const SizedBox(height: 10),
                  SecondaryButton(label: 'Tester un check-in maintenant', onPressed: showTestCheckin),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fr(String k) {
    final d = parseDay(k);
    return '${d.day}/${d.month}';
  }

  Widget _stepper(String label, String value, VoidCallback minus, VoidCallback plus) {
    return Row(
      children: [
        Expanded(child: Text(label, style: K.body(15))),
        IconButton(
          tooltip: 'Moins',
          onPressed: () async {
            minus();
            await _apply();
          },
          icon: const Icon(Icons.remove_circle_outline_rounded, color: K.muted),
        ),
        SizedBox(width: 64, child: Center(child: Text(value, style: K.display(16, color: K.cyan)))),
        IconButton(
          tooltip: 'Plus',
          onPressed: () async {
            plus();
            await _apply();
          },
          icon: const Icon(Icons.add_circle_outline_rounded, color: K.muted),
        ),
      ],
    );
  }
}
