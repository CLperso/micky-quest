import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'block.dart';
import 'cabin.dart';
import 'session.dart';
import 'timetable.dart' show askText;
import 'slot.dart' show EmotionWords;
import 'boost.dart';

class CheckinScreen extends StatefulWidget {
  final String? focusLog;

  /// Heure du check-in auquel on répond (en retard), sinon maintenant.
  final DateTime? at;

  /// Check-in existant à corriger.
  final CheckIn? existing;

  /// « Et maintenant, tu vas faire quoi ? » après une session ou une tâche (message de contexte).
  final String? nextAfter;

  /// Juste l'émotion (« Noter vite »).
  final bool moodOnly;
  const CheckinScreen({super.key, this.focusLog, this.at, this.existing, this.nextAfter, this.moodOnly = false});

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
  int _gridR = -1, _gridC = -1; // grille : rangée 0 = beaucoup d'énergie, colonne 0 = désagréable
  String _emotion = '';
  String _cause = '';
  bool _pauseAsked = false;
  bool? _onIt; // pendant une session : toujours dessus ?
  int _att = -1; // et l'attention : 0 à fond … 3 ailleurs
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
      _emotion = e.emotion;
      _cause = e.cause;
      if (e.mood > 0 && e.energy >= 0) {
        _gridC = e.mood - 1;
        _gridR = (4 - (e.energy / 25).round()).clamp(0, 4);
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
    final runS = store.runningSession;
    if (_onIt == true && _att >= 0 && runS != null) await store.recordAttention(runS, _att);
    if (!mounted) return;
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
      e.emotion = _emotion;
      e.cause = _cause;
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
      emotion: _emotion,
      cause: _cause,
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
    final inSession = run != null && widget.existing == null && widget.at == null && widget.nextAfter == null && !widget.moodOnly && widget.focusLog == null;
    final runCat = run == null ? '' : store.sessionCategory(run);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.moodOnly
            ? 'Mon émotion'
            : logsFirst
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
            if (!logsFirst && !widget.moodOnly && !inSession) ...[
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
            if (inSession) ...[
              MickySays('Toujours sur « ${run.title} » ?', pose: 'window', ring: runCat == Act.perso ? K.pink : K.lime),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: _pauseBtn(_onIt == true ? '✓ Oui, dessus' : 'Oui, toujours dessus', _onIt == true ? K.lime : K.raised, _onIt == true ? K.bg : K.ink, () => setState(() {
                        _onIt = true;
                        _act = runCat == Act.perso ? Act.perso : Act.pro;
                        _taskId = run.taskId;
                        _reason = '';
                      })),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _pauseBtn('J\'ai décroché', _onIt == false ? K.coral : K.raised, _onIt == false ? K.bg : K.ink, () => setState(() {
                        _onIt = false;
                        _act = '';
                        _taskId = '';
                      })),
                ),
              ]),
              if (_onIt == true) ...[
                const SizedBox(height: 10),
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Et ton attention, là ?', style: K.body(14, w: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Row(children: [
                      for (var i = 0; i < 4; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: i < 3 ? 6 : 0),
                            child: _pauseBtn(SessionRec.attLabels[i], _att == i ? _attColors[i] : K.raised, _att == i ? K.bg : K.ink,
                                () => setState(() => _att = _att == i ? -1 : i)),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 6),
                    Text('Pas de bonne ou mauvaise réponse : ça ne change pas tes XP.', style: K.body(11, color: K.muted)),
                    if (_att >= 2) ...[
                      const SizedBox(height: 8),
                      PrimaryButton(
                        label: 'Me relancer',
                        color: K.gold,
                        onPressed: () async {
                          final store = AppScope.read(context);
                          final r = store.runningSession;
                          if (r != null && _att >= 0) await store.recordAttention(r, _att);
                          _att = -1;
                          if (!context.mounted) return;
                          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => BoostScreen(session: r)));
                        },
                      ),
                    ],
                  ]),
                ),
              ],
              if (_onIt == false)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => openScreen(context, const SessionScreen()),
                    child: Text('Arrêter ou changer la session', style: K.body(12, color: K.muted)),
                  ),
                ),
              const SizedBox(height: 10),
            ],
            if (!widget.moodOnly && (!inSession || _onIt == false))
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(inSession ? 'Tu fais quoi à la place ?' : 'Tu fais quoi ?', style: K.display(17)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final a in Act.choices.where((a) => !(inSession && (a == Act.pro || a == runCat))))
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
                          if (p == 'Projet')
                            _chip('Projet…', false, K.pink, () async {
                              final n = await askText(context, 'Quel projet ?', hint: 'ces apps, le blog, la déco…');
                              if (n == null || n.isEmpty || !mounted) return;
                              await store.addProject(n);
                              setState(() {
                                _label = 'Projet : $n';
                                _taskId = '';
                              });
                            })
                          else
                            _chip(p, _label == p && _taskId.isEmpty, K.gold, () => setState(() {
                                  _label = _label == p ? '' : p;
                                  if (_label.isNotEmpty) _taskId = '';
                                })),
                        if (_act == Act.perso)
                          for (final n in store.settings.projects)
                            _chip('Projet : $n', _label == 'Projet : $n' && _taskId.isEmpty, K.pink, () => setState(() {
                                  _label = _label == 'Projet : $n' ? '' : 'Projet : $n';
                                  if (_label.isNotEmpty) _taskId = '';
                                })),
                        if (_act == Act.pro)
                          _chip('Préciser… (+2 XP)', false, K.lime, () async {
                            final n = await askText(context, 'Sur quoi exactement ?', hint: 'relire l\'intro, coder les analyses…');
                            if (n == null || n.isEmpty || !mounted) return;
                            final t = await store.addStepFromCheckin(n);
                            if (!mounted) return;
                            setState(() {
                              _taskId = t.id;
                              _label = '';
                            });
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Étape ajoutée à ton briefing · +2 XP')));
                          }),
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
            if (widget.existing == null && !widget.moodOnly)
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
                  const SizedBox(height: 2),
                  Text('Touche la case qui te ressemble : agréable ↔ désagréable, beaucoup ↔ peu d\'énergie.', style: K.body(12, color: K.muted)),
                  const SizedBox(height: 10),
                  _moodGrid(),
                  if (_gridR >= 0) ...[
                    const SizedBox(height: 12),
                    Text('Le mot le plus juste ? (facultatif)', style: K.body(13, w: FontWeight.w800)),
                    const SizedBox(height: 6),
                    EmotionWords(mood: _mood, energy: _energy.round(), value: _emotion, color: _quadColor(), onChanged: (w) => setState(() => _emotion = w)),
                    const SizedBox(height: 10),
                    Text('Plutôt à cause de…', style: K.body(13, w: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final c in const ['la tâche', 'mon corps (faim, fatigue)', 'quelqu\'un', 'je ne sais pas'])
                        _chip(c, _cause == c, K.gold, () => setState(() => _cause = _cause == c ? '' : c)),
                    ]),
                  ],
                  if (_gridC >= 0 && _gridC <= 1 && !_pauseAsked && widget.existing == null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF2A1630), borderRadius: BorderRadius.circular(16), border: Border.all(color: K.coral, width: 2)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Ça a l\'air lourd. Tu veux une pause ?', style: K.body(14, w: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: _pauseBtn('Pause 10 min', K.coral, K.bg, () async {
                            await store.startPause('Repos', DateTime.now().add(const Duration(minutes: 10)));
                            await store.noteSerenity('pause');
                            setState(() => _pauseAsked = true);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pause de 10 min, check-ins coupés. Respire.')));
                          })),
                          const SizedBox(width: 6),
                          Expanded(child: _pauseBtn('La cabane', const Color(0xFFB9A7FF), K.bg, () {
                            setState(() => _pauseAsked = true);
                            openScreen(context, const CabinScreen());
                          })),
                          const SizedBox(width: 6),
                          Expanded(child: _pauseBtn('Non, ça va', K.raised, K.ink, () => setState(() => _pauseAsked = true))),
                        ]),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _note,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Un mot sur ce moment (facultatif)'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (!logsFirst && !widget.moodOnly) ...logs,
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

  static const _cellColors = {
    'hu': Color(0xFFB5443A), // énergie haute, désagréable
    'hp': Color(0xFFC9A227), // énergie haute, agréable
    'lu': Color(0xFF3B5BA8), // énergie basse, désagréable
    'lp': Color(0xFF3E8E57), // énergie basse, agréable
  };

  Color _cellColor(int r, int c) {
    if (r < 2 && c < 2) return _cellColors['hu']!;
    if (r < 2 && c > 2) return _cellColors['hp']!;
    if (r > 2 && c < 2) return _cellColors['lu']!;
    if (r > 2 && c > 2) return _cellColors['lp']!;
    return K.raised;
  }

  static const _attColors = [Color(0xFF3E8E57), Color(0xFF7FD6C2), Color(0xFFC9A227), Color(0xFFB5443A)];

  Color _quadColor() => _gridR < 0 ? K.gold : (_cellColor(_gridR, _gridC) == K.raised ? K.gold : _cellColor(_gridR, _gridC));

  Widget _moodGrid() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: RotatedBox(
              quarterTurns: 3,
              child: Text('ÉNERGIE →', textAlign: TextAlign.center, style: K.body(10, color: K.muted, w: FontWeight.w900)),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(children: [
              for (var r = 0; r < 5; r++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    for (var c = 0; c < 5; c++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: c < 4 ? 4 : 0),
                          child: AspectRatio(
                            aspectRatio: 1.25,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                if (_gridR == r && _gridC == c) {
                                  _gridR = _gridC = -1;
                                  _mood = 0;
                                  _energySet = false;
                                } else {
                                  _gridR = r;
                                  _gridC = c;
                                  _mood = c + 1;
                                  _energy = (4 - r) * 25.0;
                                  _energySet = true;
                                  if (!EmotionWords.keeps(_emotion, c + 1, (4 - r) * 25)) _emotion = '';
                                }
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                decoration: BoxDecoration(
                                  color: _cellColor(r, c).withValues(alpha: _gridR == r && _gridC == c ? 1 : 0.8),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _gridR == r && _gridC == c ? K.ink : Colors.transparent, width: 3),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('désagréable', style: K.body(10, color: K.muted, w: FontWeight.w800)),
                Text('agréable', style: K.body(10, color: K.muted, w: FontWeight.w800)),
              ]),
            ]),
          ),
        ],
      );

  Widget _pauseBtn(String label, Color bg, Color fg, VoidCallback onTap) => SizedBox(
        height: 44,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Center(child: Text(label, textAlign: TextAlign.center, style: K.body(12, color: fg, w: FontWeight.w800))),
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
