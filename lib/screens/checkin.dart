import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'block.dart';

class CheckinScreen extends StatefulWidget {
  final String? focusLog;

  /// Heure du check-in auquel on répond (en retard), sinon maintenant.
  final DateTime? at;

  /// Check-in existant à corriger.
  final CheckIn? existing;

  /// « Et maintenant, tu vas faire quoi ? » après une session ou une tâche (message de contexte).
  final String? nextAfter;
  const CheckinScreen({super.key, this.focusLog, this.at, this.existing, this.nextAfter});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  String _act = '';
  String _taskId = '';
  String _label = '';
  int _since = -1;
  String _reason = '';
  final _why = TextEditingController();
  static const _sinceChoices = [5, 15, 30, 45, 60, 90];
  int _mood = 0;
  double _energy = 50;
  bool _energySet = false;
  final _note = TextEditingController();
  final List<String> _added = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _act = e.activity;
      _taskId = e.taskId;
      _label = e.label;
      _since = e.sinceMin;
      _mood = e.mood;
      if (e.energy >= 0) {
        _energy = e.energy.toDouble();
        _energySet = true;
      }
      _note.text = e.note;
      final parts = e.reason.split(' · ');
      if (parts.isNotEmpty && Act.reasons.contains(parts.first)) {
        _reason = parts.first;
        _why.text = parts.skip(1).join(' · ');
      } else {
        _why.text = e.reason;
      }
    }
    if (widget.focusLog == LogKind.meal) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _meal());
    } else if (widget.focusLog == LogKind.free) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _free());
    }
  }

  @override
  void dispose() {
    _note.dispose();
    _why.dispose();
    super.dispose();
  }

  Future<void> _log(String kind, {String note = '', String photo = '', double qty = 1}) async {
    final e = LogEntry(ts: DateTime.now().millisecondsSinceEpoch, kind: kind, note: note, photo: photo, qty: qty);
    await AppScope.read(context).addLog(e);
    if (!mounted) return;
    setState(() => _added.add(e.label));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${e.label} noté à ${hm(DateTime.now())}')));
  }

  /// Quantité en un tap : ¼, ½, ¾ ou 1.
  Future<void> _logQty(String kind) async {
    final q = await showModalBottomSheet<double>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(LogKind.labels[kind] ?? kind, style: K.display(20)),
              const SizedBox(height: 4),
              Text('Quelle quantité ?', style: K.body(13, color: K.muted)),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final q in LogKind.qtyChoices) ...[
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: K.raised,
                            side: const BorderSide(color: K.line, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.pop(ctx, q),
                          child: Text(LogKind.qtyLabel(q), style: K.display(20)),
                        ),
                      ),
                    ),
                    if (q != 1.0) const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (q != null && mounted) await _log(kind, qty: q);
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
    final why = _why.text.trim();
    final reason = Act.isWork(_act) ? '' : [if (_reason.isNotEmpty) _reason, if (why.isNotEmpty) why].join(' · ');
    final e = widget.existing;
    if (e != null) {
      e.activity = _act;
      e.taskId = Act.isOnTask(_act) ? _taskId : '';
      e.label = Act.isOnTask(_act) && _taskId.isEmpty ? _label : '';
      e.sinceMin = _since;
      e.reason = reason;
      e.mood = _mood;
      e.energy = _energySet ? _energy.round() : -1;
      e.note = _note.text.trim();
      await store.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check-in corrigé')));
      Navigator.pop(context);
      return;
    }
    await store.addCheckIn(CheckIn(
      ts: (widget.at ?? DateTime.now()).millisecondsSinceEpoch,
      activity: _act,
      taskId: Act.isOnTask(_act) ? _taskId : '',
      label: Act.isOnTask(_act) && _taskId.isEmpty ? _label : '',
      sinceMin: _since,
      reason: reason,
      mood: _mood,
      energy: _energySet ? _energy.round() : -1,
      note: _note.text.trim(),
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check-in envoyé · +1 XP')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final logsFirst = widget.focusLog != null;
    final logs = _logsSection();
    final store = AppScope.of(context);
    final tasks = store.openTasks.where((t) => !t.done).toList()
      ..sort((a, b) {
        int rank(Task t) => t.category.isNotEmpty ? 0 : (t.quad == Quad.doNow ? 1 : 2);
        return rank(a).compareTo(rank(b));
      });
    final run = store.runningSession;
    if (run != null && _act.isEmpty && _taskId.isEmpty && widget.focusLog == null && widget.existing == null) {
      _act = store.taskById(run.taskId)?.category == 'perso' ? Act.perso : Act.pro;
      _taskId = run.taskId;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(logsFirst
            ? 'Noter'
            : widget.nextAfter != null
                ? 'Et maintenant ?'
                : widget.existing != null
                ? 'Corriger · ${hm(DateTime.fromMillisecondsSinceEpoch(widget.existing!.ts))}'
                : (widget.at == null ? 'Check-in' : 'Check-in de ${hm(widget.at!)}')),
        actions: [
          if (widget.existing != null)
            IconButton(
              tooltip: 'Supprimer',
              onPressed: () async {
                await store.removeCheckIn(widget.existing!);
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_outline_rounded, color: K.coral),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (logsFirst) ...logs,
            if (!logsFirst) ...[
              MickySays(
                  widget.nextAfter != null
                      ? '${widget.nextAfter} Et maintenant, tu vas faire quoi ?'
                      : widget.at != null
                          ? 'Tu faisais quoi vers ${hm(widget.at!)} ?'
                          : run != null
                              ? 'Toujours sur « ${run.title} » ?'
                              : 'Tu fais quoi, là tout de suite ?',
                  pose: widget.nextAfter != null ? 'happy' : 'window',
                  ring: K.lime),
              const SizedBox(height: 12),
            ],
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tu fais quoi ?', style: K.display(17)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final a in Act.choices)
                        _chip(Act.labels[a]!, _act == a, a == Act.pro ? K.lime : (a == Act.perso ? K.pink : K.cyan), () => setState(() {
                              _act = _act == a ? '' : a;
                              if (!Act.isOnTask(_act)) _taskId = '';
                            })),
                    ],
                  ),
                  if (_act == Act.pro || _act == Act.perso) ...[
                    const SizedBox(height: 4),
                    Text(Act.hints[_act]!, style: K.body(12, color: K.muted)),
                    const SizedBox(height: 12),
                    Text('Sur quoi ?', style: K.display(15)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in Act.presets[_act]!)
                          _chip(p, _label == p && _taskId.isEmpty, K.gold, () => setState(() {
                                _label = _label == p ? '' : p;
                                if (_label.isNotEmpty) _taskId = '';
                              })),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(tasks.where((t) => t.category.isEmpty || t.category == _act).isEmpty
                        ? 'Tes étapes de quête du jour apparaîtront ici (briefing ou Quêtes).'
                        : 'Ou une de tes tâches du jour :', style: K.body(12, color: K.muted)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in tasks.where((t) => t.category.isEmpty || t.category == _act))
                          _chip(
                            t.category.isNotEmpty ? '${t.category == 'pro' ? 'PRO' : 'PERSO'} · ${t.title}' : t.title,
                            _taskId == t.id,
                            t.category == 'perso' ? K.pink : K.lime,
                            () => setState(() {
                              _taskId = _taskId == t.id ? '' : t.id;
                              if (_taskId.isNotEmpty) _label = '';
                            }),
                          ),
                      ],
                    ),
                  ],
                  if (_act.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text('Depuis combien de temps ?', style: K.display(15)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in _sinceChoices)
                          _chip('$m min', _since == m, K.gold, () => setState(() => _since = _since == m ? -1 : m)),
                      ],
                    ),
                  ],
                  if (_act.isNotEmpty && !Act.isWork(_act)) ...[
                    const SizedBox(height: 14),
                    Text(_act == Act.perso ? 'Un mot sur ce que tu fais ? (facultatif)' : 'Pourquoi pas sur une quête ?',
                        style: K.display(15)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final r in Act.reasons)
                          _chip(r, _reason == r, K.coral, () => setState(() => _reason = _reason == r ? '' : r)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _why,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Avec tes mots, si tu veux'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (widget.existing == null)
              Material(
                color: K.card,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => openScreen(context, BlockScreen(task: _taskId.isEmpty ? null : store.taskById(_taskId))),
                  child: Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: K.coral, width: 2)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [
                      const Icon(Icons.support_rounded, color: K.coral),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Je bloque · coups de pouce', style: K.body(14, w: FontWeight.w800))),
                      const Icon(Icons.chevron_right_rounded, color: K.muted),
                    ]),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Comment tu te sens ?', style: K.display(17)),
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
            PrimaryButton(label: widget.existing != null ? 'Enregistrer la correction' : 'Envoyer · +1 XP', onPressed: _send),
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
            Expanded(child: _logBtn(Icons.bolt_rounded, 'Energy', K.cyan, () => _logQty(LogKind.energy))),
            const SizedBox(width: 6),
            Expanded(child: _logBtn(Icons.coffee_rounded, 'Café', K.pink, () => _log(LogKind.coffee))),
            const SizedBox(width: 6),
            Expanded(child: _logBtn(Icons.medication_rounded, 'Pilule', K.coral, () => _logQty(LogKind.pill))),
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
