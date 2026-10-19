import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';

/// Évaluation en un tap après une session.
class RateSheet extends StatefulWidget {
  final SessionRec session;
  const RateSheet({super.key, required this.session});

  @override
  State<RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<RateSheet> {
  int _diff = 0;
  int _feel = 0;
  int _intr = -1;
  int _bossP = -1;
  int _focus = -1; // -1 = pas encore initialisé
  int _prog = -1;
  int _tMet = -1;
  String _suite = ''; // tâche en plusieurs sessions : now, plan, tomorrow
  final _helped = TextEditingController();
  final _hard = TextEditingController();
  final _worth = TextEditingController();

  @override
  void dispose() {
    _helped.dispose();
    _hard.dispose();
    _worth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final store = AppScope.of(context);
    final boss = s.taskId.isEmpty ? null : store.taskById(s.taskId);
    final isBoss = boss != null && boss.isBoss;
    if (isBoss && _bossP < 0) _bossP = boss.bossProgress;
    final task = isBoss ? null : boss;
    if (_focus < 0) _focus = s.focus > 0 ? s.focus : s.suggestedFocus;
    final from = s.progFrom >= 0 ? s.progFrom : (task?.progress ?? 0);
    if (_prog < 0) _prog = s.progTo >= 0 ? s.progTo : (s.advance && s.predProg >= 0 ? s.predProg : (s.finished && task != null ? 100 : from));
    if (_tMet < 0 && s.targetMet >= 0) _tMet = s.targetMet;
    final pro = store.sessionCategory(s) == Act.pro;
    final ratio = s.ratio;
    String verdict;
    if (!s.finished) {
      verdict = 'Interrompue après ${s.actualMin.round()} min. Ça arrive, on regarde pourquoi juste après.';
    } else if (ratio == 0) {
      verdict = '';
    } else if (ratio > 1.2) {
      verdict = '${s.actualMin.round()} min pour ${s.predictedMin} prévues : plus long que ton pari.';
    } else if (ratio < 0.8) {
      verdict = '${s.actualMin.round()} min pour ${s.predictedMin} prévues : plus rapide que ton pari.';
    } else {
      verdict = '${s.actualMin.round()} min pour ${s.predictedMin} prévues : pari tenu !';
    }
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          children: [
            Text('Débrief', style: K.display(22)),
            if (verdict.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(verdict, style: K.body(14, color: K.muted)),
            ],
            const SizedBox(height: 14),
            Panel(
              child: Row(children: [
                Text('${s.actualMin.round()} min', style: K.display(28, color: K.lime)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('1 · EFFORT', style: K.body(10, color: K.lime, w: FontWeight.w900)),
                    Text('Tu es restée dessus. Rester, c\'est un muscle.', style: K.body(12, color: K.muted)),
                  ]),
                ),
                if (pro) Text('+${s.actualMin.clamp(0, 180).round()} XP', style: K.body(13, color: K.lime, w: FontWeight.w900)),
              ]),
            ),
            const SizedBox(height: 8),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('2 · CONCENTRATION', style: K.body(10, color: K.cyan, w: FontWeight.w900)),
                if (s.atts.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    for (final c in s.atts.split(''))
                      Container(
                        width: 24,
                        height: 8,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(color: _attColors[(int.tryParse(c) ?? 1).clamp(0, 3)], borderRadius: BorderRadius.circular(4)),
                      ),
                    const SizedBox(width: 4),
                    Text('pendant la session', style: K.body(11, color: K.dim)),
                  ]),
                ],
                const SizedBox(height: 8),
                _row(['1', '2', '3', '4', '5'], _focus, K.cyan, (i) => setState(() => _focus = i)),
                const SizedBox(height: 4),
                Text(s.suggestedFocus > 0 ? 'Prérempli d\'après tes réponses. Tu peux corriger : ça ne change pas tes XP.' : 'Ta note ne change pas tes XP : réponds franchement.',
                    style: K.body(11, color: K.muted)),
              ]),
            ),
            if (task != null) ...[
              const SizedBox(height: 8),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('3 · AVANCEMENT DE L\'ÉTAPE', style: K.body(10, color: K.gold, w: FontWeight.w900))),
                    Text('$_prog %', style: K.display(18, color: K.gold)),
                  ]),
                  Slider(
                    value: _prog.toDouble(),
                    max: 100,
                    divisions: 20,
                    activeColor: K.gold,
                    onChanged: (v) => setState(() => _prog = v.round()),
                  ),
                  Row(children: [
                    Expanded(
                      child: Text(_prog > from ? 'avant : $from % · +${_prog - from} points' : 'avant : $from %', style: K.body(12, color: K.muted)),
                    ),
                    TextButton(onPressed: () => setState(() => _prog = 100), child: const Text('Étape finie')),
                  ]),
                  if (s.advance && s.predProg >= 0)
                    Text('Tu visais ~${s.predProg} %.', style: K.body(11, color: K.dim)),
                  if (_prog < 100 && (s.advance || !s.finished)) ...[
                    const SizedBox(height: 8),
                    Text('La suite ?', style: K.body(13, w: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final o in const [('now', 'Je continue maintenant'), ('plan', 'Je la cale dans le planning'), ('tomorrow', 'Demain')])
                        ChoiceChip(
                          label: Text(o.$2),
                          selected: _suite == o.$1,
                          onSelected: (_) => setState(() => _suite = _suite == o.$1 ? '' : o.$1),
                          selectedColor: K.gold,
                          labelStyle: K.body(12, color: _suite == o.$1 ? K.bg : K.ink, w: FontWeight.w800),
                          backgroundColor: K.raised,
                          side: BorderSide.none,
                          showCheckmark: false,
                        ),
                    ]),
                  ],
                ]),
              ),
            ],
            if (s.target.isNotEmpty) ...[
              const SizedBox(height: 8),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('TU VOULAIS AVOIR', style: K.body(10, color: K.lime, w: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('« ${s.target} »', style: K.body(14)),
                  const SizedBox(height: 8),
                  _row(['Non', 'En partie', 'Oui'], _tMet + 1, K.lime, (i) => setState(() => _tMet = i - 1)),
                ]),
              ),
            ],
            if (isBoss) ...[
              const SizedBox(height: 14),
              Panel(
                border: K.coral,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.pest_control_rounded, color: K.coral),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Le boss : tu en es où ?', style: K.display(16))),
                      Text('$_bossP %', style: K.display(18, color: K.coral)),
                    ]),
                    Slider(
                      value: _bossP.toDouble(),
                      max: 100,
                      divisions: 20,
                      activeColor: K.coral,
                      onChanged: (v) => setState(() => _bossP = v.round()),
                    ),
                    Row(children: [
                      Expanded(child: Text(_bossP >= 100 ? 'Boss vaincu : +300 XP et un objet épique !' : 'Ce coup : ${s.actualMin.round()} min. La jauge de dégâts suit ton avancement.', style: K.body(12, color: K.muted))),
                      TextButton(onPressed: () => setState(() => _bossP = 100), child: const Text('Vaincu !')),
                    ]),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text('Interrompue ?', style: K.body(13, color: K.muted)),
            const SizedBox(height: 6),
            _row(['Non', '1 fois', 'Plusieurs'], _intr + 1, K.lime, (i) => setState(() => _intr = i - 1)),
            const SizedBox(height: 4),
            Text(
              _intr == 0
                  ? 'Les ${s.actualMin.round()} min comptent en entier dans ta barre Focus.'
                  : _intr == 1
                      ? 'La moitié des minutes compte dans ta barre Focus.'
                      : _intr >= 2
                          ? 'Cette session ne remplit pas la barre Focus, mais le temps est bien compté.'
                          : 'Seules les sessions pro sans interruption remplissent la barre Focus.',
              style: K.body(12, color: K.muted),
            ),
            const SizedBox(height: 12),
            Text('Difficulté', style: K.body(13, color: K.muted)),
            const SizedBox(height: 6),
            _row(['Facile', 'Correct', 'Dur'], _diff, K.cyan, (i) => setState(() => _diff = i)),
            const SizedBox(height: 12),
            Text('Ressenti', style: K.body(13, color: K.muted)),
            const SizedBox(height: 6),
            _row(['Pénible', 'Neutre', 'Agréable'], _feel, K.pink, (i) => setState(() => _feel = i)),
            const SizedBox(height: 12),
            TextField(
              controller: _helped,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: s.finished ? 'Ce qui m\'a aidée (facultatif)' : 'Ce qui marchait avant de décrocher (facultatif)',
              ),
            ),
            if (s.finished) ...[
              const SizedBox(height: 12),
              Text('Deux minutes pour ancrer :', style: K.body(13, color: K.muted)),
              const SizedBox(height: 6),
              TextField(
                controller: _hard,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'C\'était dur en quoi ?'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _worth,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Pourquoi ça valait le coup ?'),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(label: 'Passer', onPressed: () => Navigator.pop(context)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: 'Valider',
                    onPressed: (_diff == 0 && _feel == 0 && _intr < 0 && _helped.text.trim().isEmpty && !isBoss && _focus <= 0 && task == null && _tMet < 0)
                        ? null
                        : () async {
                            if (isBoss && _bossP != boss.bossProgress) await store.setBossProgress(boss, _bossP);
                            await store.rateProgress(s,
                                focus: _focus > 0 ? _focus : null,
                                progTo: isBoss ? _bossP : (task != null ? _prog : null),
                                targetMet: _tMet >= 0 ? _tMet : null);
                            if (task != null && _prog >= 100 && !task.done) await store.completeTask(task);
                            await AppScope.read(context).rateSession(s,
                                difficulty: _diff,
                                feeling: _feel,
                                helped: _helped.text.trim(),
                                interrupted: _intr,
                                hardWhat: _hard.text.trim(),
                                worthWhy: _worth.text.trim());
                            if (context.mounted) Navigator.pop(context, _suite);
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const _attColors = [Color(0xFF3E8E57), Color(0xFF7FD6C2), Color(0xFFC9A227), Color(0xFFB5443A)];

  Widget _row(List<String> labels, int value, Color c, void Function(int) onTap) => Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: value == i + 1 ? c : K.bg,
                    foregroundColor: value == i + 1 ? K.bg : K.ink,
                    side: BorderSide(color: value == i + 1 ? c : K.line, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () => onTap(value == i + 1 ? 0 : i + 1),
                  child: Text(labels[i], style: K.body(14, color: value == i + 1 ? K.bg : K.ink, w: FontWeight.w800)),
                ),
              ),
            ),
            if (i < labels.length - 1) const SizedBox(width: 8),
          ],
        ],
      );
}

/// « Qu'est-ce qui s'est passé ? » — ouvert, curieux, sans jugement, et tourné vers la prochaine fois.
class ReflectionScreen extends StatefulWidget {
  final String kind; // decroche, pasfaite
  final String taskId;
  final String title;
  const ReflectionScreen({super.key, required this.kind, this.taskId = '', this.title = ''});

  @override
  State<ReflectionScreen> createState() => _ReflectionScreenState();
}

class _ReflectionScreenState extends State<ReflectionScreen> {
  final Set<String> _reasons = {};
  String _emotion = '';
  int _reasonable = 0; // 1 oui, 2 trop gros, 3 pas clair
  int _origin = 0; // 1 moi, 2 « je devrais », 3 quelqu'un d'autre
  final _text = TextEditingController();
  static const _emotions = ['Ennui', 'Peur de rater', 'Honte', 'Flou', 'Fatigue', 'Colère', 'Tristesse', 'Rien de spécial'];
  final _if = TextEditingController();
  final _then = TextEditingController();

  static const _ideas = {
    'Trop flou, je ne savais pas par où commencer': ('je ne sais pas par où commencer', 'j\'écris la toute première action en une phrase'),
    'Trop gros d\'un coup': ('la tâche me paraît énorme', 'je la découpe en étapes de 15 minutes'),
    'Peur de mal faire': ('j\'ai peur de mal faire', 'je fais une version brouillon volontairement imparfaite'),
    'Ennui, pas assez stimulant': ('je m\'ennuie', 'je mets un minuteur de 10 minutes et une musique'),
    'Pas l\'énergie': ('je n\'ai pas l\'énergie', 'je choisis jusqu\'où je PEUX aller, même une seule étape'),
    'Interrompue': ('on m\'interrompt', 'je note où j\'en suis avant de répondre'),
    'Je l\'ai oubliée': ('je risque d\'oublier', 'je la mets dans « Faire maintenant » dès le briefing'),
    'Émotion difficile': ('une émotion me submerge', 'je respire 2 minutes et je nomme ce que je ressens'),
  };

  @override
  void dispose() {
    _text.dispose();
    _if.dispose();
    _then.dispose();
    super.dispose();
  }

  void _toggle(String r) {
    setState(() {
      if (!_reasons.remove(r)) _reasons.add(r);
      // propose un plan tant que l'utilisatrice n'a rien écrit elle-même
      final idea = _ideas[r];
      if (_reasons.contains(r) && idea != null && _if.text.isEmpty && _then.text.isEmpty) {
        _if.text = idea.$1;
        _then.text = idea.$2;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final empty = _reasons.isEmpty && _emotion.isEmpty && _reasonable == 0 && _text.text.trim().isEmpty && _if.text.trim().isEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(widget.kind == 'decroche' ? 'Qu\'est-ce qui s\'est passé ?' : 'Pourquoi pas aujourd\'hui ?')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          children: [
            MickySays(
              widget.kind == 'decroche'
                  ? 'Pas de reproche : on cherche juste ce qui t\'a fait décrocher, pour que ce soit plus facile la prochaine fois.'
                  : 'Une tâche pas faite, c\'est une info, pas un échec. Qu\'est-ce qui a coincé ?',
              pose: 'belly',
              ring: K.coral,
            ),
            if (widget.title.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(widget.title, style: K.display(18)),
            ],
            const SectionLabel('Qu\'est-ce que j\'évitais de ressentir ?'),
            Text('Procrastiner enlève une émotion désagréable. La nommer lui enlève de la force.', style: K.body(12, color: K.muted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _emotions)
                  FilterChip(
                    label: Text(e),
                    selected: _emotion == e,
                    onSelected: (_) => setState(() => _emotion = _emotion == e ? '' : e),
                    selectedColor: K.pink,
                    backgroundColor: K.raised,
                    labelStyle: K.body(13, color: _emotion == e ? K.bg : K.ink),
                    side: BorderSide.none,
                    showCheckmark: false,
                  ),
              ],
            ),
            const SectionLabel('Ce qui a joué (plusieurs possibles)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in Reflection.suggestions)
                  FilterChip(
                    label: Text(r),
                    selected: _reasons.contains(r),
                    onSelected: (_) => _toggle(r),
                    selectedColor: K.coral,
                    backgroundColor: K.raised,
                    labelStyle: K.body(13, color: _reasons.contains(r) ? K.bg : K.ink),
                    side: BorderSide.none,
                    showCheckmark: false,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              maxLines: null,
              minLines: 3,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Avec tes mots : qu\'est-ce qui se passait, dans ta tête ou autour de toi ?',
              ),
            ),
            const SectionLabel('Autopsie, sans honte'),
            Text('L\'objectif était-il raisonnable ?', style: K.body(13, color: K.muted)),
            const SizedBox(height: 6),
            _seg(['Oui', 'Trop gros', 'Pas clair'], _reasonable, (v) => setState(() => _reasonable = v)),
            const SizedBox(height: 10),
            Text('D\'où venait l\'envie de la faire ?', style: K.body(13, color: K.muted)),
            const SizedBox(height: 6),
            _seg(['De moi', '« Je devrais »', 'De quelqu\'un'], _origin, (v) => setState(() => _origin = v)),
            const SizedBox(height: 4),
            Text('La pression et la honte « marchent » mais demandent toujours plus. Un objectif d\'action qui vient de toi tient mieux.',
                style: K.body(12, color: K.muted)),
            const SectionLabel('La prochaine fois'),
            Panel(
              child: Column(
                children: [
                  Row(children: [
                    SizedBox(width: 48, child: Text('Si', style: K.display(16, color: K.gold))),
                    Expanded(
                      child: TextField(
                        controller: _if,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(hintText: 'la situation se représente'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    SizedBox(width: 48, child: Text('alors', style: K.display(16, color: K.gold))),
                    Expanded(
                      child: TextField(
                        controller: _then,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(hintText: 'je fais cette petite chose'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text('Ce plan deviendra ton plan B du prochain briefing.', style: K.body(12, color: K.muted)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: SecondaryButton(label: 'Plus tard', onPressed: () => Navigator.pop(context))),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: '+3 XP',
                    onPressed: empty
                        ? null
                        : () async {
                            const reas = ['', 'objectif raisonnable', 'objectif trop gros', 'objectif pas clair'];
                            const orig = ['', 'envie venue de moi', 'envie « je devrais »', 'envie venue de quelqu\'un'];
                            await store.addReflection(Reflection(
                              ts: DateTime.now().millisecondsSinceEpoch,
                              taskId: widget.taskId,
                              title: widget.title,
                              kind: widget.kind,
                              reasons: [
                                if (_emotion.isNotEmpty) 'Émotion : $_emotion',
                                ..._reasons,
                                if (_reasonable > 0) reas[_reasonable],
                                if (_origin > 0) orig[_origin],
                              ],
                              text: _text.text.trim(),
                              ifCue: _if.text.trim(),
                              thenDo: _then.text.trim(),
                            ));
                            if (context.mounted) Navigator.pop(context, true);
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _seg(List<String> labels, int value, void Function(int) onTap) => Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: value == i + 1 ? K.coral : K.bg,
                    side: BorderSide(color: value == i + 1 ? K.coral : K.line, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () => onTap(value == i + 1 ? 0 : i + 1),
                  child: Text(labels[i], style: K.body(12, color: value == i + 1 ? K.bg : K.ink, w: FontWeight.w800), textAlign: TextAlign.center),
                ),
              ),
            ),
            if (i < labels.length - 1) const SizedBox(width: 6),
          ],
        ],
      );
}
