import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';

class CheckinScreen extends StatefulWidget {
  final String? focusLog;
  const CheckinScreen({super.key, this.focusLog});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  String _act = '';
  String _reason = '';
  int _mood = 0;
  double _energy = 50;
  bool _energySet = false;
  final _note = TextEditingController();
  final List<String> _added = [];

  @override
  void initState() {
    super.initState();
    if (widget.focusLog == LogKind.meal) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _meal());
    } else if (widget.focusLog == LogKind.free) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _free());
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _log(String kind, {String note = '', String photo = ''}) async {
    await AppScope.read(context).addLog(
      LogEntry(ts: DateTime.now().millisecondsSinceEpoch, kind: kind, note: note, photo: photo),
    );
    if (!mounted) return;
    setState(() => _added.add(LogKind.labels[kind] ?? kind));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${LogKind.labels[kind]} noté à ${hm(DateTime.now())}')));
  }

  Future<void> _meal() async {
    final src = await showModalBottomSheet<ImageSource?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: K.gold),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: K.gold),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.schedule_rounded, color: K.muted),
              title: const Text('Juste noter l\'heure'),
              onTap: () => Navigator.pop(ctx, null),
            ),
          ],
        ),
      ),
    );
    var path = '';
    if (src != null) {
      try {
        final x = await ImagePicker().pickImage(source: src, maxWidth: 1200, imageQuality: 75);
        if (x != null) {
          final dir = await getApplicationDocumentsDirectory();
          final folder = Directory('${dir.path}/repas');
          if (!folder.existsSync()) folder.createSync(recursive: true);
          final dest = '${folder.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
          await File(x.path).copy(dest);
          path = dest;
        } else {
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Photo impossible : $e')));
        }
      }
    }
    if (mounted) await _log(LogKind.meal, photo: path);
  }

  Future<void> _free() async {
    final c = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: K.card,
        title: Text('Note libre', style: K.display(20)),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'sieste, sport, médicament, appel…'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Ajouter')),
        ],
      ),
    );
    c.dispose();
    if (text != null && text.trim().isNotEmpty && mounted) await _log(LogKind.free, note: text.trim());
  }

  Future<void> _send() async {
    final store = AppScope.read(context);
    if (_act.isEmpty && _mood == 0 && !_energySet && _note.text.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }
    await store.addCheckIn(CheckIn(
      ts: DateTime.now().millisecondsSinceEpoch,
      activity: _act,
      reason: _act == Act.quest ? '' : _reason,
      mood: _mood,
      energy: _energySet ? _energy.round() : -1,
      note: _note.text.trim(),
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check-in envoyé · +5 XP')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final logsFirst = widget.focusLog != null;
    final logs = _logsSection();
    return Scaffold(
      appBar: AppBar(title: Text(logsFirst ? 'Noter' : 'Check-in')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (logsFirst) ...logs,
            if (!logsFirst) ...[
              const MickySays('Tu fais quoi, là tout de suite ?', pose: 'window', ring: K.lime),
              const SizedBox(height: 12),
            ],
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Activité', style: K.display(17)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in Act.labels.entries)
                        _chip(e.value, _act == e.key, e.key == Act.quest ? K.lime : K.cyan,
                            () => setState(() => _act = _act == e.key ? '' : e.key)),
                    ],
                  ),
                  if (_act.isNotEmpty && _act != Act.quest) ...[
                    const SizedBox(height: 14),
                    Text('Qu\'est-ce qui t\'a attirée ailleurs ?', style: K.display(15)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final r in Act.reasons)
                          _chip(r, _reason == r, K.coral, () => setState(() => _reason = _reason == r ? '' : r)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ton humeur', style: K.display(17)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: _mood == i,
                            label: AppStore.moodLabels[i - 1],
                            child: GestureDetector(
                              onTap: () => setState(() => _mood = _mood == i ? 0 : i),
                              child: Column(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: _mood == i ? 50 : 44,
                                    height: _mood == i ? 50 : 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _mood == i ? K.moodColors[i - 1] : K.raised,
                                      border: Border.all(color: K.moodColors[i - 1], width: 2),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(AppStore.moodLabels[i - 1],
                                      style: K.body(11, color: _mood == i ? K.ink : K.muted)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('Énergie', style: K.body(14)),
                      Expanded(
                        child: Slider(
                          value: _energy,
                          max: 100,
                          onChanged: (v) => setState(() {
                            _energy = v;
                            _energySet = true;
                          }),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text(_energySet ? '${_energy.round()} %' : '—', style: K.body(13, color: K.cyan)),
                      ),
                    ],
                  ),
                  TextField(
                    controller: _note,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Un mot sur ce moment (facultatif)'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (!logsFirst) ...logs,
            const SizedBox(height: 16),
            PrimaryButton(label: 'Envoyer · +5 XP', onPressed: _send),
          ],
        ),
      ),
    );
  }

  List<Widget> _logsSection() => [
        const SectionLabel('Depuis le dernier check-in'),
        Row(
          children: [
            Expanded(child: _logBtn(Icons.photo_camera_rounded, 'Repas', K.gold, _meal)),
            const SizedBox(width: 6),
            Expanded(child: _logBtn(Icons.bolt_rounded, 'Energy drink', K.cyan, () => _log(LogKind.energy))),
            const SizedBox(width: 6),
            Expanded(child: _logBtn(Icons.coffee_rounded, 'Café', K.pink, () => _log(LogKind.coffee))),
            const SizedBox(width: 6),
            Expanded(child: _logBtn(Icons.add_rounded, 'Autre', K.lime, _free)),
          ],
        ),
        if (_added.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Noté : ${_added.join(', ')}', style: K.body(12, color: K.muted)),
        ],
        const SizedBox(height: 10),
      ];

  Widget _logBtn(IconData icon, String label, Color c, VoidCallback onTap) => Material(
        color: K.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            height: 72,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: K.line, width: 2)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: c),
                const SizedBox(height: 4),
                Text(label, textAlign: TextAlign.center, style: K.body(11, w: FontWeight.w800)),
              ],
            ),
          ),
        ),
      );

  Widget _chip(String label, bool on, Color c, VoidCallback onTap) => Material(
        color: on ? c : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: on ? c : K.line, width: 2),
            ),
            child: Text(label, style: K.body(13, color: on ? K.bg : K.ink, w: FontWeight.w800)),
          ),
        ),
      );
}
