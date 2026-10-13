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
              Text('Deux minutes pour ancrer (Dr K) :', style: K.body(13, color: K.muted)),
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
                    label: '+2 XP',
                    onPressed: (_diff == 0 && _feel == 0 && _intr < 0 && _helped.text.trim().isEmpty)
                        ? null
                        : () async {
                            await AppScope.read(context).rateSession(s,
                                difficulty: _diff,
                                feeling: _feel,
                                helped: _helped.text.trim(),
                                interrupted: _intr,
                                hardWhat: _hard.text.trim(),
                                worthWhy: _worth.text.trim());
                            if (context.mounted) Navigator.pop(context);
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
  final _text = TextEditingController();
  final _if = TextEditingController();
  final _then = TextEditingController();

  static const _ideas = {
    'Trop flou, je ne savais pas par où commencer': ('je ne sais pas par où commencer', 'j\'écris la toute première action en une phrase'),
    'Trop gros d\'un coup': ('la tâche me paraît énorme', 'je la découpe en étapes de 15 minutes'),
    'Peur de mal faire': ('j\'ai peur de mal faire', 'je fais une version brouillon volontairement imparfaite'),
    'Ennui, pas assez stimulant': ('je m\'ennuie', 'je mets un minuteur de 10 minutes et une musique'),
    'Pas l\'énergie': ('je n\'ai pas l\'énergie', 'je fais 5 minutes puis je décide si je continue'),
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
    final empty = _reasons.isEmpty && _text.text.trim().isEmpty && _if.text.trim().isEmpty;
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
                            await store.addReflection(Reflection(
                              ts: DateTime.now().millisecondsSinceEpoch,
                              taskId: widget.taskId,
                              title: widget.title,
                              kind: widget.kind,
                              reasons: _reasons.toList(),
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
}
