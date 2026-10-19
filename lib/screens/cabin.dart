import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'block.dart';
import 'slot.dart' show EmotionWords, MiniMoodGrid, moodColor;
import 'timetable.dart' show askText;
import 'problems.dart' show ProblemScreen, problemColor;

const _lav = Color(0xFFB9A7FF);

TextStyle _quoteStyle(double size) => GoogleFonts.lora(fontSize: size, fontStyle: FontStyle.italic, height: 1.5, color: K.ink);

/// Ce qui pèse : familles et précisions.
class _Weight {
  final String id, label;
  final Color color;
  final List<String> subs;
  const _Weight(this.id, this.label, this.color, this.subs);
}

const _weights = [
  _Weight('culpabilité', 'Culpabilité', Color(0xFFFFB27A), ['pas assez avancé', 'envers quelqu\'un, sociale', 'envers moi, mon corps', 'sans raison claire']),
  _Weight('tristesse', 'Tristesse', Color(0xFF6F8FE0), ['solitude', 'une perte, un manque', 'sans raison']),
  _Weight('lassitude', 'Lassitude · à quoi bon', _lav, ['tout est gris', 'rien n\'a de sens', 'fatigue de tout']),
  _Weight('découragement', 'Découragement', K.cyan, ['trop gros', 'je n\'y arriverai pas', 'ça n\'avance pas']),
  _Weight('anxiété', 'Anxiété', K.coral, ['tout presse', 'peur de rater', 'sans objet']),
  _Weight('honte', 'Honte', Color(0xFFFFB27A), ['de moi', 'devant quelqu\'un']),
  _Weight('colère', 'Colère', Color(0xFFE0605A), ['contre quelqu\'un', 'contre moi', 'contre la situation']),
  _Weight('solitude', 'Solitude', Color(0xFF7FD6C2), ['personne à qui parler', 'incomprise']),
];

/// Un angle : une école, une citation, des questions.
class _Angle {
  final String id, school, name, line;
  final Color color;
  final String quote, source;
  final List<String> prompts;
  final List<String> forWeights;
  const _Angle(this.id, this.school, this.name, this.line, this.color, this.quote, this.source, this.prompts, this.forWeights);
}

const _angles = [
  _Angle('faute', 'PSYCHO', 'Faute ou honte ?', 'Une faute se répare. Une honte se dépose.', Color(0xFFFFB27A),
      'Le repentir n\'est pas une vertu, il ne naît pas de la raison : qui se repent de ce qu\'il a fait est deux fois misérable.',
      'Spinoza, Éthique IV',
      ['Ce que je me reproche', 'Ce que je me dirais si c\'était une amie'], ['culpabilité', 'honte']),
  _Angle('fleche', 'BOUDDHISME', 'La deuxième flèche', 'Ce qui fait mal, et ce que j\'y ajoute.', Color(0xFFFFD24A),
      'Quand on est touché par une flèche, on souffre. Puis on s\'en tire souvent une deuxième soi-même.',
      'd\'après le Sallatha Sutta',
      ['La première flèche (ce qui fait mal, en vrai)', 'La deuxième flèche (ce que j\'y ajoute)', 'Ce que je garde, sans la deuxième'],
      ['culpabilité', 'honte', 'découragement', 'anxiété', 'tristesse', 'colère']),
  _Angle('rain', 'BOUDDHISME · RAIN', 'Reconnaître, accueillir', 'Reconnaître, Accepter, Investiguer, Nourrir.', Color(0xFFFFD24A),
      'Ce qui est là a le droit d\'être là. On le regarde avec douceur, sans chercher à le chasser.',
      'd\'après Tara Brach',
      ['Reconnaître : qu\'est-ce qui est là ?', 'Accepter : est-ce que je peux le laisser être là un moment ?', 'Investiguer : où dans le corps ? qu\'est-ce que ça croit ?', 'Nourrir : de quoi j\'aurais besoin, là ?'],
      ['tristesse', 'solitude', 'anxiété', 'lassitude']),
  _Angle('causes', 'SPINOZA', 'Comprendre les causes', 'Une suite de causes, pas une faute.', Color(0xFF7FD6C2),
      'Ne pas rire, ne pas pleurer, ne pas détester, mais comprendre.',
      'Spinoza, Traité politique',
      ['Je me sens… parce que…', '… et ça, ça vient de…', '… et encore avant…', 'Qu\'est-ce qui augmenterait un tout petit peu ma puissance d\'agir ?'],
      ['culpabilité', 'découragement', 'tristesse', 'colère', 'lassitude']),
  _Angle('oui', 'NIETZSCHE · AMOR FATI', 'Dire oui', 'Le prochain petit oui, pas le sens de tout.', K.pink,
      'Il faut porter encore en soi un chaos pour pouvoir enfanter une étoile dansante.',
      'Nietzsche, Ainsi parlait Zarathoustra',
      ['Une chose d\'aujourd\'hui à laquelle je peux dire oui, même petite', 'Qu\'est-ce qui m\'a déjà donné envie, un jour comme ça ?', 'Le prochain petit oui, dans l\'heure'],
      ['lassitude', 'découragement', 'tristesse']),
  _Angle('sisyphe', 'CAMUS', 'Sisyphe', 'Le geste a du goût, même si le rocher redescend.', Color(0xFFC9A227),
      'La lutte elle-même vers les sommets suffit à remplir un cœur d\'homme. Il faut imaginer Sisyphe heureux.',
      'Camus, Le Mythe de Sisyphe',
      ['Mon rocher aujourd\'hui', 'Ce que j\'aime dans le geste lui-même, pas dans le résultat'],
      ['lassitude', 'découragement']),
  _Angle('stoique', 'STOÏCISME · ÉPICTÈTE', 'Ce qui dépend de moi', 'Deux colonnes.', K.cyan,
      'Parmi les choses, les unes dépendent de nous, les autres n\'en dépendent pas.',
      'Épictète, Manuel',
      ['Ce qui ne dépend pas de moi', 'Ce qui dépend de moi', 'La plus petite chose que je peux faire'],
      ['anxiété', 'colère', 'culpabilité', 'découragement']),
  _Angle('tcc', 'TCC', 'La pensée plus juste', 'Ce qui la soutient, ce qui la contredit.', K.lime,
      'Une pensée n\'est pas un fait. On peut l\'examiner comme une hypothèse.',
      '',
      ['La pensée qui tourne', 'Ce qui la soutient', 'Ce qui la contredit', 'Une version plus juste'],
      ['culpabilité', 'honte', 'anxiété', 'découragement', 'tristesse', 'solitude', 'colère', 'lassitude']),
];

class _Gesture {
  final String id, icon, label, sub;
  const _Gesture(this.id, this.icon, this.label, this.sub);
}

const _gestures = [
  _Gesture('micky', '🐈', 'Jouer avec Micky', '10 min · minuteur'),
  _Gesture('someone', '🎁', 'Faire quelque chose pour quelqu\'un', 'un message, un service'),
  _Gesture('book', '📖', '10 pages au hasard', 'dans ta pile de philo'),
  _Gesture('meditate', '🧘', 'Méditer 5 min', 'respiration ou pensée suivante'),
  _Gesture('outside', '🚶', 'Dehors sans téléphone', '10 min'),
  _Gesture('music', '🎵', 'Une musique qui porte', 'juste une chanson'),
];

/// La cabane de Micky : souffler, évaluer, ce qui pèse, un angle, un geste, après.
class CabinScreen extends StatefulWidget {
  const CabinScreen({super.key});

  @override
  State<CabinScreen> createState() => _CabinScreenState();
}

class _CabinScreenState extends State<CabinScreen> {
  int _step = 0; // 0 souffle, 1 évaluer, 2 ce qui pèse, 3 angle, 4 geste, 5 après
  String _breath = '';
  int _mood = 0, _energy = -1, _before = -1, _after = -1;
  String _emotion = '', _body = '', _origin = '';
  final Map<String, Set<String>> _weightsSel = {};
  _Angle? _angle;
  final List<TextEditingController> _fields = [];
  String _fauteOrHonte = '';
  String _probLabel = ''; // à quel problème ce regard s'applique
  bool _triaged = false; // problèmes triés : résoudre / traverser / les deux
  final List<({String title, String kind, Problem? existing})> _cands = [];
  final List<Problem> _queue = [];
  final Set<String> _done = {}; // 'r:id' résolu, 't:id' traversé
  Problem? _for; // problème pour lequel on choisit un regard
  final _pas = TextEditingController();
  final List<({String label, _Angle angle, List<String> notes})> _problems = []; // problèmes déjà regardés
  String _gesture = '';
  String _bookPick = '';
  bool _saved = false;

  static const _stepNames = ['Souffle', 'Évaluer', 'Ce qui pèse', 'Angle', 'Geste', 'Après'];

  @override
  void dispose() {
    _pas.dispose();
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  void _next() => setState(() => _step = min(5, _step + 1));

  /// Revenir d'un cran : sous-écran d'abord (exercice, regard, tri), puis l'étape précédente.
  /// Renvoie false s'il n'y a plus rien avant (on peut quitter la cabane).
  bool _back() {
    if (_step == 3) {
      if (_angle != null) {
        setState(() => _angle = null);
        return true;
      }
      if (_for != null) {
        setState(() => _for = null);
        return true;
      }
      if (_triaged) {
        setState(() {
          // les problèmes déjà créés reviennent dans le tri, sans doublon
          _cands
            ..clear()
            ..addAll([for (final p in _queue) (title: p.title, kind: p.kind, existing: p)]);
          _queue.clear();
          _triaged = false;
        });
        return true;
      }
    }
    if (_step == 0 && _breath.isNotEmpty) {
      setState(() => _breath = '');
      return true;
    }
    if (_step > 0) {
      setState(() => _step--);
      return true;
    }
    return false;
  }

  void _goTo(int i) {
    if (i >= _step) return;
    setState(() {
      _step = i;
      if (i < 3) {
        _angle = null;
        _for = null;
      }
    });
  }

  List<String> get _weightList => [
        for (final e in _weightsSel.entries)
          if (e.value.isEmpty) e.key else for (final s in e.value) '${e.key}:$s'
      ];

  List<String> _currentNotes() => [
        if (_fauteOrHonte.isNotEmpty) _fauteOrHonte,
        if (_angle != null)
          for (var i = 0; i < _fields.length && i < _angle!.prompts.length; i++)
            if (_fields[i].text.trim().isNotEmpty) '${_angle!.prompts[i]} : ${_fields[i].text.trim()}',
      ];

  /// Range le problème en cours et revient au choix d'un regard pour le suivant.
  void _archive() {
    if (_angle == null) return;
    _problems.add((label: _probLabel, angle: _angle!, notes: _currentNotes()));
    for (final c in _fields) {
      c.dispose();
    }
    _fields.clear();
    _angle = null;
    _fauteOrHonte = '';
    _probLabel = '';
  }

  List<({String label, _Angle angle, List<String> notes})> get _allProblems => [
        ..._problems,
        if (_angle != null) (label: _probLabel, angle: _angle!, notes: _currentNotes()),
      ];

  Future<void> _save() async {
    if (_saved) return;
    _saved = true;
    final store = AppScope.read(context);
    final all = _allProblems;
    final notes = <String>[
      for (var k = 0; k < all.length; k++) ...[
        if (all.length > 1) '— ${k + 1}. ${all[k].label.isEmpty ? all[k].angle.name : '${all[k].label.replaceAll(':', ' · ')} (${all[k].angle.name})'}',
        ...all[k].notes,
      ],
    ];
    await store.saveCabinVisit(CabinVisit(
      ts: DateTime.now().millisecondsSinceEpoch,
      mood: _mood,
      energy: _energy,
      emotion: _emotion,
      before: _before,
      after: _after,
      weights: _weightList,
      body: _body,
      origin: _origin,
      angle: {for (final p in all) p.angle.name}.join(' + '),
      gesture: _gesture,
      notes: notes.join('\n'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return PopScope(
      canPop: _step == 0 && _breath.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
      backgroundColor: K.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (!_back()) Navigator.of(context).maybePop();
          },
        ),
        title: Text(_step == 0 ? 'La cabane de Micky' : _stepNames[_step]),
        actions: [
          if (_step < 5) TextButton(onPressed: _next, child: Text('passer ›', style: K.body(13, color: K.muted))),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: K.muted),
            color: K.card,
            onSelected: (v) {
              if (v == 'books') openScreen(context, const _BooksScreen());
              if (v == 'letter') _editLetter(store);
              if (v == 'contacts') openScreen(context, const _ContactsScreen());
              if (v == 'library') openScreen(context, const _LibraryScreen());
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'library', child: Text('Ma bibliothèque')),
              PopupMenuItem(value: 'books', child: Text('Ma pile de livres')),
              PopupMenuItem(value: 'letter', child: Text('Ma lettre des bons jours')),
              PopupMenuItem(value: 'contacts', child: Text('Mes personnes')),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -1.2), radius: 1.2, colors: [Color(0xFF2A2350), K.bg])),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(children: [
                  for (var i = 0; i < 6; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _goTo(i),
                        child: Padding(
                          padding: EdgeInsets.only(right: i < 5 ? 4 : 0, top: 4, bottom: 4),
                          child: Column(children: [
                            Container(height: 4, decoration: BoxDecoration(color: i <= _step ? _lav : K.line, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(height: 3),
                            Text(_stepNames[i], style: K.body(9, color: i == _step ? _lav : (i < _step ? K.ink : K.muted), w: FontWeight.w800)),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
              Expanded(child: _body0(store)),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _body0(AppStore store) {
    switch (_step) {
      case 0:
        return _breathStep();
      case 1:
        return _evalStep();
      case 2:
        return _weightStep();
      case 3:
        if (!_triaged) return _triage(store);
        if (_angle != null) return _exercise(store);
        return _for != null ? _angleList(store) : _queueView(store);
      case 4:
        return _gestureStep(store);
      default:
        return _afterStep(store);
    }
  }

  // ---------- 0 · Souffle ----------

  Widget _breathStep() {
    if (_breath == 'alt') return _AltBreath(onDone: _next);
    if (_breath == 'next') return _NextThought(onDone: _next);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Panel(
          child: Row(children: [
            ClipOval(child: Image.asset(K.micky['bed'] ?? K.micky['happy']!, width: 52, height: 52, fit: BoxFit.cover)),
            const SizedBox(width: 12),
            Expanded(child: Text('On ne règle rien tout de suite. D\'abord le souffle. Choisis ce qui te tente.', style: K.body(14))),
          ]),
        ),
        const SizedBox(height: 12),
        _medCard('Respiration alternée', 'Une narine, puis l\'autre. Calme et redonne de l\'énergie à la fois : bien quand la culpabilité tourne en boucle.', '3 min', _lav, () => setState(() => _breath = 'alt')),
        _medCard('Quelle est la pensée suivante ?', 'Attendre la prochaine pensée comme un chat devant un trou de souris. On voit qu\'elles passent : on n\'est pas elles.', '3 min', K.cyan, () => setState(() => _breath = 'next')),
      ],
    );
  }

  Widget _medCard(String title, String sub, String dur, Color c, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: K.card,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: c, width: 2)),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: K.display(17)),
                    const SizedBox(height: 4),
                    Text(sub, style: K.body(12, color: K.muted)),
                  ]),
                ),
                const SizedBox(width: 8),
                Text(dur, style: K.body(12, color: c, w: FontWeight.w900)),
              ]),
            ),
          ),
        ),
      );

  // ---------- 1 · Évaluer ----------

  Widget _chip(String label, bool on, Color c, VoidCallback onTap, {bool dashed = false}) => Padding(
        padding: const EdgeInsets.only(right: 6, bottom: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: on ? c : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: on ? c : K.line, width: 2),
            ),
            child: Text(label, style: K.body(12, color: on ? K.bg : K.ink, w: FontWeight.w800)),
          ),
        ),
      );

  Widget _evalStep() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('L\'émotion', style: K.body(14, w: FontWeight.w800)),
              const SizedBox(height: 8),
              MiniMoodGrid(
                mood: _mood,
                energy: _energy,
                onChanged: (m, e) => setState(() {
                  _mood = m;
                  _energy = e;
                  if (!EmotionWords.keeps(_emotion, m, e)) _emotion = '';
                }),
              ),
              if (_mood > 0) ...[
                const SizedBox(height: 8),
                EmotionWords(mood: _mood, energy: _energy, value: _emotion, color: moodColor(_mood, _energy), onChanged: (w) => setState(() => _emotion = w)),
              ],
            ]),
          ),
          const SizedBox(height: 10),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Intensité', style: K.body(14, w: FontWeight.w800)),
              const SizedBox(height: 8),
              _scale(_before, (v) => setState(() => _before = v)),
            ]),
          ),
          const SizedBox(height: 10),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Où ça se loge ?', style: K.body(14, w: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(children: [
                for (final b in ['gorge', 'poitrine', 'ventre', 'épaules', 'tête', 'nulle part']) _chip(b, _body == b, _lav, () => setState(() => _body = _body == b ? '' : b)),
              ]),
            ]),
          ),
          const SizedBox(height: 10),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('C\'est d\'abord…', style: K.body(14, w: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(children: [
                for (final o in ['mon corps (faim, fatigue, cycle)', 'une pensée qui tourne', 'une situation réelle']) _chip(o, _origin == o, _lav, () => setState(() => _origin = _origin == o ? '' : o)),
              ]),
              if (_origin.startsWith('mon corps'))
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF2A2516), borderRadius: BorderRadius.circular(14), border: Border.all(color: K.gold, width: 2)),
                  child: Text('D\'abord le corps : manger un vrai truc, boire, t\'allonger 10 minutes ou sortir. La philo attendra, et souvent ça suffit.', style: K.body(13)),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Ce qui pèse', color: _lav, onPressed: _next),
        ],
      );

  Widget _scale(int value, void Function(int) onTap) => Row(children: [
        for (var i = 0; i <= 10; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 10 ? 3 : 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onTap(i),
                child: Container(
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: value == i ? _lav : K.raised, borderRadius: BorderRadius.circular(8)),
                  child: Text('$i', style: K.body(12, color: value == i ? K.bg : K.muted, w: FontWeight.w900)),
                ),
              ),
            ),
          ),
      ]);

  // ---------- 2 · Ce qui pèse ----------

  Widget _weightStep() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text('Coche tout ce qui est là, et précise si tu veux. Plusieurs à la fois, c\'est normal.', style: K.body(13, color: K.muted)),
          const SizedBox(height: 10),
          for (final w in _weights) ...[
            _chip(_weightsSel.containsKey(w.id) ? '${w.label} ✓' : w.label, _weightsSel.containsKey(w.id), w.color, () => setState(() {
                  if (_weightsSel.containsKey(w.id)) {
                    _weightsSel.remove(w.id);
                  } else {
                    _weightsSel[w.id] = {};
                  }
                })),
            if (_weightsSel.containsKey(w.id))
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 6),
                child: Wrap(children: [
                  for (final s in w.subs)
                    _chip(s, _weightsSel[w.id]!.contains(s), w.color.withValues(alpha: 0.85), () => setState(() {
                          final set = _weightsSel[w.id]!;
                          if (!set.remove(s)) set.add(s);
                        })),
                ]),
              ),
          ],
          const SizedBox(height: 14),
          PrimaryButton(label: 'Suite', color: _lav, onPressed: _next),
        ],
      );

  // ---------- 3 · Problèmes : résoudre ou traverser ----------

  void _buildCands(AppStore store) {
    if (_cands.isNotEmpty) return;
    for (final e in _weightsSel.entries) {
      final w = _weights.firstWhere((x) => x.id == e.key);
      final t = e.value.isEmpty ? w.label : '${w.label} · ${e.value.join(', ')}';
      final kind = const {'tristesse', 'lassitude', 'solitude', 'honte'}.contains(e.key) ? 'traverser' : 'resoudre';
      _cands.add((title: t, kind: kind, existing: null));
    }
  }

  Widget _kindChips(String kind, ValueChanged<String> on) => Row(children: [
        for (final k in Problem.kinds.entries)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: k.key == 'deux' ? 0 : 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => on(k.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: kind == k.key ? problemColor(Problem(ts: 0, title: '', kind: k.key)) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kind == k.key ? Colors.transparent : K.line, width: 2),
                  ),
                  child: Text(k.key == 'resoudre' ? 'Ça se résout' : k.key == 'traverser' ? 'Ça se traverse' : 'Les deux',
                      style: K.body(12, w: FontWeight.w800, color: kind == k.key ? K.bg : K.ink)),
                ),
              ),
            ),
          ),
      ]);

  Widget _triage(AppStore store) {
    _buildCands(store);
    final others = store.openProblems.where((p) => !_cands.any((c) => c.existing?.id == p.id)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text('Pour chaque problème : est-ce que ça se résout, ou est-ce que ça se traverse ?', style: K.body(13, color: K.muted)),
        const SizedBox(height: 10),
        for (var i = 0; i < _cands.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('${i + 1}', style: K.display(16, color: _lav)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: _cands[i].existing != null
                          ? null
                          : () async {
                              final t = await askText(context, 'Le problème, concrètement', initial: _cands[i].title);
                              if (t != null && t.trim().isNotEmpty) setState(() => _cands[i] = (title: t.trim(), kind: _cands[i].kind, existing: null));
                            },
                      child: Text(_cands[i].title, style: K.body(14, w: FontWeight.w800)),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _cands.removeAt(i)),
                    icon: const Icon(Icons.close_rounded, color: K.muted, size: 18),
                  ),
                ]),
                if (_cands[i].existing == null) Text('touche le titre pour le dire concrètement', style: K.body(10, color: K.dim)),
                const SizedBox(height: 8),
                _kindChips(_cands[i].kind, (k) => setState(() => _cands[i] = (title: _cands[i].title, kind: k, existing: _cands[i].existing))),
              ]),
            ),
          ),
        TextButton(
          onPressed: () async {
            final t = await askText(context, 'Un autre problème', hint: 'concret : « le mail à mon directeur »');
            if (t != null && t.trim().isNotEmpty) setState(() => _cands.add((title: t.trim(), kind: 'resoudre', existing: null)));
          },
          child: Align(alignment: Alignment.centerLeft, child: Text('+ un autre problème', style: K.body(13, color: K.cyan, w: FontWeight.w800))),
        ),
        if (others.isNotEmpty) ...[
          Text('Ou reprendre un problème ouvert :', style: K.body(12, color: K.muted)),
          const SizedBox(height: 6),
          Wrap(children: [
            for (final p in others) _chip('+ ${p.title}', false, problemColor(p), () => setState(() => _cands.add((title: p.title, kind: p.kind, existing: p)))),
          ]),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: _lav.withValues(alpha: 0.08),
            border: const Border(left: BorderSide(color: _lav, width: 3)),
            borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
          ),
          child: Text('Parmi les choses, les unes dépendent de nous, les autres n\'en dépendent pas. — Épictète', style: _quoteStyle(13)),
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: _cands.isEmpty ? 'Passer aux regards' : 'Commencer',
          color: _lav,
          onPressed: () async {
            for (final c in _cands) {
              if (c.existing != null) {
                c.existing!.kind = c.kind;
                _queue.add(c.existing!);
              } else {
                _queue.add(await store.addProblem(c.title, kind: c.kind, intensity: _before >= 0 ? _before : null));
              }
            }
            if (_cands.isEmpty) {
              // pas de problème nommé : on garde l'ancien parcours (un regard)
              _for = null;
            }
            await store.commit();
            setState(() => _triaged = true);
          },
        ),
      ],
    );
  }

  Widget _queueView(AppStore store) {
    if (_queue.isEmpty) return _angleList(store);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text('Un problème à la fois. Dans l\'ordre que tu veux.', style: K.body(13, color: K.muted)),
        const SizedBox(height: 10),
        for (final p in _queue)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(p.title, style: K.body(14, w: FontWeight.w800))),
                  Pill(Problem.kinds[p.kind]!, color: K.bg, fill: problemColor(p)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  if (p.kind != 'traverser')
                    Expanded(
                      child: _done.contains('r:${p.id}')
                          ? Text('✓ résolution posée', style: K.body(13, color: K.lime, w: FontWeight.w800))
                          : SecondaryButton(
                              label: 'Résoudre',
                              onPressed: () async {
                                final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ProblemScreen(problem: p, guided: true)));
                                if (ok == true) setState(() => _done.add('r:${p.id}'));
                              },
                            ),
                    ),
                  if (p.kind == 'deux') const SizedBox(width: 8),
                  if (p.kind != 'resoudre')
                    Expanded(
                      child: _done.contains('t:${p.id}')
                          ? Text('✓ regardé autrement', style: K.body(13, color: _lav, w: FontWeight.w800))
                          : SecondaryButton(label: 'Un regard', onPressed: () => setState(() => _for = p)),
                    ),
                ]),
              ]),
            ),
          ),
        const SizedBox(height: 6),
        Text('Tout reste dans « Mes problèmes » : tu suivras l\'intensité au feu de camp.', style: K.body(11, color: K.dim)),
        const SizedBox(height: 12),
        PrimaryButton(label: 'Un geste', color: _lav, onPressed: _next),
      ],
    );
  }

  // ---------- 3 · Angle ----------

  Widget _angleList(AppStore store) {
    final eff = store.angleEfficacy();
    final fav = store.settings.favAngles;
    final sel = _weightsSel.keys.toSet();
    int score(_Angle a) {
      var s = 0;
      if (fav.contains(a.id)) s += 100;
      s += a.forWeights.where(sel.contains).length * 10;
      s += ((eff[a.name] ?? 0) * 5).round();
      // culpabilité « pas assez avancé » : faute ou honte en premier
      if (a.id == 'faute' && (_weightsSel['culpabilité']?.contains('pas assez avancé') ?? false)) s += 20;
      return s;
    }

    final list = [..._angles]..sort((a, b) => score(b).compareTo(score(a)));
    final best = eff.entries.isEmpty ? null : (eff.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (_for != null) ...[
          Row(children: [
            Expanded(child: Text('Un regard pour « ${_for!.title} »', style: K.display(16))),
            TextButton(onPressed: () => setState(() => _for = null), child: Text('retour', style: K.body(12, color: K.muted))),
          ]),
          const SizedBox(height: 4),
        ],
        if (sel.isNotEmpty)
          Text('Pour ${_weightList.map((w) => w.replaceAll(':', ' · ')).join(' + ')}', style: K.body(11, color: K.muted, w: FontWeight.w900)),
        const SizedBox(height: 8),
        for (final a in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: K.card,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() {
                  _angle = a;
                  for (final c in _fields) {
                    c.dispose();
                  }
                  _fields
                    ..clear()
                    ..addAll(List.generate(a.prompts.length, (_) => TextEditingController()));
                }),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border(left: BorderSide(color: a.color, width: 4))),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(a.school, style: K.body(10, color: a.color, w: FontWeight.w900)),
                          if (best != null && best.key == a.name) ...[
                            const SizedBox(width: 6),
                            Pill('T\'AIDE LE PLUS · −${best.value.toStringAsFixed(1).replaceAll('.', ',')}', color: K.bg, fill: K.gold),
                          ],
                        ]),
                        Text(a.name, style: K.display(16)),
                        Text(a.line, style: _quoteStyle(12).copyWith(color: K.muted)),
                      ]),
                    ),
                    IconButton(
                      onPressed: () async {
                        if (!store.settings.favAngles.remove(a.id)) store.settings.favAngles.add(a.id);
                        await store.updateSettings();
                        setState(() {});
                      },
                      icon: Icon(fav.contains(a.id) ? Icons.star_rounded : Icons.star_border_rounded, color: K.gold),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _exercise(AppStore store) {
    final a = _angle!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Row(children: [
          Expanded(child: Text(a.name, style: K.display(20))),
          TextButton(onPressed: () => setState(() => _angle = null), child: Text('autre regard', style: K.body(12, color: K.muted))),
        ]),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: a.color.withValues(alpha: 0.08),
            border: Border(left: BorderSide(color: a.color, width: 3)),
            borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.quote, style: _quoteStyle(15)),
            if (a.source.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('— ${a.source}', style: K.body(11, color: K.muted))),
          ]),
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 12),
        for (var i = 0; i < a.prompts.length; i++) ...[
          Text(a.prompts[i], style: K.body(13, color: a.color, w: FontWeight.w800)),
          const SizedBox(height: 4),
          TextField(controller: _fields[i], maxLines: null, minLines: 2, textCapitalization: TextCapitalization.sentences),
          const SizedBox(height: 10),
          if (a.id == 'faute' && i == 0) ...[
            Text('C\'est plutôt…', style: K.body(13, w: FontWeight.w800)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _choice('Une faute', 'un acte précis, réparable', _fauteOrHonte == 'faute', a.color, () => setState(() => _fauteOrHonte = 'faute'))),
              const SizedBox(width: 8),
              Expanded(child: _choice('De la honte', '« je suis nulle »', _fauteOrHonte == 'honte', a.color, () => setState(() => _fauteOrHonte = 'honte'))),
            ]),
            if (_fauteOrHonte.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: a.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: a.color, width: 2)),
                child: _fauteOrHonte == 'honte'
                    ? Text('La honte vise qui tu es, pas ce que tu as fait : elle ne répare rien et pousse à fuir. Tu peux la déposer ici.', style: K.body(13))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Une faute se répare. Quelle petite réparation, ce soir ou demain ?', style: K.body(13)),
                        const SizedBox(height: 6),
                        SecondaryButton(
                          label: 'En faire une tâche',
                          onPressed: () async {
                            final t = await askText(context, 'Petite réparation', hint: 'relire une section, écrire à…');
                            if (t == null || t.isEmpty) return;
                            await store.addTask(t, quad: Quad.doNow);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('« $t » ajoutée à Faire maintenant')));
                          },
                        ),
                      ]),
              ),
            const SizedBox(height: 10),
          ],
          if (a.id == 'fleche' && i == 1) ...[
            Text('Est-ce que ce sera pareil…', style: K.body(13, w: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(children: [for (final w in ['dans 3 h ?', 'demain ?', 'dans un mois ?']) _chip(w, false, a.color, () {})]),
            Text('Rien ne reste. Pas même ça.', style: _quoteStyle(12).copyWith(color: K.muted)),
            const SizedBox(height: 10),
          ],
        ],
        if (_for != null) ...[
          Text('Un petit pas qui compte, malgré ça (facultatif)', style: K.body(13, color: K.lime, w: FontWeight.w800)),
          const SizedBox(height: 4),
          TextField(controller: _pas, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'ex. : marcher 20 min avec quelqu\'un')),
          const SizedBox(height: 4),
          Text('Il rejoint la fiche du problème, dans « Mes problèmes ».', style: K.body(11, color: K.dim)),
          const SizedBox(height: 10),
        ],
        Row(children: [
          Expanded(
            child: SecondaryButton(
              label: '☆ Garder la phrase',
              onPressed: () async {
                final last = _fields.reversed.map((c) => c.text.trim()).firstWhere((t) => t.isNotEmpty, orElse: () => a.quote);
                if (!store.settings.library.contains(last)) store.settings.library.insert(0, last);
                await store.updateSettings();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gardée dans ta bibliothèque')));
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PrimaryButton(
              label: _for != null ? 'Fini pour ce problème' : 'Un geste',
              color: _lav,
              onPressed: () async {
                final p = _for;
                if (p == null) return _next();
                if (_pas.text.trim().isNotEmpty) await store.addProblemStep(p, _pas.text.trim());
                _pas.clear();
                _probLabel = p.title;
                setState(() {
                  _archive();
                  _done.add('t:${p.id}');
                  _for = null;
                });
              },
            ),
          ),
        ]),
      ],
    );
  }

  Widget _choice(String t, String sub, bool on, Color c, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: on ? c : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: on ? c : K.line, width: 2)),
          child: Column(children: [
            Text(t, style: K.body(13, color: on ? K.bg : K.ink, w: FontWeight.w800)),
            Text(sub, textAlign: TextAlign.center, style: K.body(11, color: on ? K.bg : K.muted)),
          ]),
        ),
      );

  // ---------- 4 · Geste ----------

  Widget _gestureStep(AppStore store) {
    final books = store.settings.books;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.6,
          children: [
            for (final g in _gestures)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _doGesture(store, g),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _gesture == g.id ? _lav : K.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _gesture == g.id ? _lav : K.line, width: 2),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(g.icon, style: const TextStyle(fontSize: 20)),
                    Text(g.label, style: K.body(13, color: _gesture == g.id ? K.bg : K.ink, w: FontWeight.w800), maxLines: 2),
                    Text(g.sub, style: K.body(10, color: _gesture == g.id ? K.bg : K.muted)),
                  ]),
                ),
              ),
          ],
        ),
        if (_bookPick.isNotEmpty) ...[
          const SizedBox(height: 10),
          Panel(
            border: K.gold,
            child: Row(children: [
              const Text('📖', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(child: Text(_bookPick, style: K.body(14, w: FontWeight.w800))),
              TextButton(onPressed: () => _pickBook(store), child: Text(books.length > 1 ? 'autre livre' : 'autre page', style: K.body(12, color: K.gold))),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        PrimaryButton(label: 'Et maintenant ?', color: _lav, onPressed: _next),
      ],
    );
  }

  void _pickBook(AppStore store) {
    final books = store.settings.books;
    if (books.isEmpty) {
      openScreen(context, const _BooksScreen());
      return;
    }
    final r = Random();
    final b = books[r.nextInt(books.length)].split('|');
    final pages = b.length > 1 ? (int.tryParse(b[1]) ?? 300) : 300;
    final p = 1 + r.nextInt(max(1, pages - 10));
    setState(() => _bookPick = '${b[0]} · page $p → ${p + 10}');
  }

  Future<void> _doGesture(AppStore store, _Gesture g) async {
    setState(() => _gesture = g.id);
    switch (g.id) {
      case 'micky':
        await openScreen(context, const SimpleTimer(title: 'Jouer avec Micky', minutes: 10, hint: 'Plumeau, boulette de papier, laser : Micky choisit. Toi, tu joues.', what: 'jouer avec Micky'));
        break;
      case 'outside':
        await openScreen(context, const SimpleTimer(title: 'Dehors sans téléphone', minutes: 10, hint: 'Téléphone à la maison ou au fond du sac. Juste marcher et regarder.', what: 'dehors'));
        break;
      case 'meditate':
        await openScreen(context, Scaffold(appBar: AppBar(title: const Text('Méditer 5 min')), body: SafeArea(child: _AltBreath(onDone: () => Navigator.pop(context), cycles: 19))));
        break;
      case 'book':
        _pickBook(store);
        break;
      case 'someone':
        await showModalBottomSheet(
          context: context,
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pour quelqu\'un, maintenant', style: K.display(18)),
                const SizedBox(height: 8),
                for (final s in [
                  'Envoyer un message gentil à quelqu\'un à qui tu penses',
                  'Remercier quelqu\'un pour un truc précis',
                  'Rendre un petit service (une relecture, un lien utile)',
                  'Prendre des nouvelles de quelqu\'un qu\'on n\'a pas vu depuis longtemps',
                ])
                  Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('· $s', style: K.body(14))),
                if (store.settings.contacts.isNotEmpty) Text('Tes personnes : ${store.settings.contacts.join(', ')}', style: K.body(12, color: K.muted)),
              ]),
            ),
          ),
        );
        break;
    }
    if (g.id != 'book') await store.noteSerenity('cabane · ${g.label.toLowerCase()}');
  }

  // ---------- 5 · Après ----------

  Widget _afterStep(AppStore store) {
    final letter = store.settings.goodDaysLetter;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Et maintenant, l\'intensité ?', style: K.body(14, w: FontWeight.w800)),
            const SizedBox(height: 8),
            _scale(_after, (v) => setState(() => _after = v)),
            if (_before >= 0 && _after >= 0) ...[
              const SizedBox(height: 10),
              Row(children: [
                Text('$_before', style: K.display(30, color: K.muted).copyWith(decoration: TextDecoration.lineThrough)),
                const SizedBox(width: 10),
                const Text('→', style: TextStyle(fontSize: 22, color: _lav)),
                const SizedBox(width: 10),
                Text('$_after', style: K.display(40, color: _after < _before ? K.lime : K.ink)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _after < _before
                        ? '−${_before - _after}${_angle != null ? ' avec « ${_angle!.name} »' : ''}. Noté, +Sérénité.'
                        : 'Pas de baisse, et c\'est OK : tu as pris soin de toi quand même.',
                    style: K.body(12, color: K.muted),
                  ),
                ),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _lav.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
          child: Text('C\'est un moment difficile.\nD\'autres le traversent aussi, ce soir.\nQu\'est-ce que je peux m\'offrir, là ?', style: _quoteStyle(14)),
        ),
        const SizedBox(height: 10),
        if (letter.isNotEmpty && max(_before, _after) >= 6)
          Panel(
            border: K.gold,
            child: InkWell(
              onTap: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: K.card,
                  title: Text('Ta lettre des bons jours', style: K.display(18)),
                  content: SingleChildScrollView(child: Text(letter, style: _quoteStyle(15))),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Merci'))],
                ),
              ),
              child: Row(children: [
                const Text('✉', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(child: Text('Ta lettre des bons jours · « ${letter.length > 40 ? '${letter.substring(0, 40)}…' : letter} »', style: K.body(13))),
                Text('Lire', style: K.body(12, color: K.gold, w: FontWeight.w900)),
              ]),
            ),
          ),
        if (letter.isEmpty)
          TextButton(onPressed: () => _editLetter(store), child: const Text('Un jour où ça va : écrire ta lettre des bons jours')),
        if (store.cabinHeavy) ...[
          const SizedBox(height: 10),
          Panel(
            child: Text(
              store.settings.contacts.isEmpty
                  ? 'Ces derniers jours ont été lourds. Tu veux en parler à quelqu\'un de confiance ?'
                  : 'Ces derniers jours ont été lourds. Tu veux en parler à ${store.settings.contacts.join(' ou ')} ?',
              style: K.body(13),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: SecondaryButton(label: 'Ma bibliothèque', onPressed: () => openScreen(context, const _LibraryScreen()))),
          const SizedBox(width: 8),
          Expanded(
            child: PrimaryButton(
              label: 'Terminer',
              color: _lav,
              onPressed: () async {
                await _save();
                if (mounted) Navigator.pop(context);
              },
            ),
          ),
        ]),
      ],
    );
  }

  Future<void> _editLetter(AppStore store) async {
    final c = TextEditingController(text: store.settings.goodDaysLetter);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: K.card,
        title: Text('Lettre des bons jours', style: K.display(18)),
        content: TextField(
          controller: c,
          maxLines: 8,
          minLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'À toi, un soir de coup de mou : …'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Garder')),
        ],
      ),
    );
    c.dispose();
    if (v == null) return;
    store.settings.goodDaysLetter = v.trim();
    await store.updateSettings();
    if (mounted) setState(() {});
  }
}

/// Respiration alternée guidée (4 s par phase, on change de côté après l'inspiration).
class _AltBreath extends StatefulWidget {
  final VoidCallback onDone;
  final int cycles;
  const _AltBreath({required this.onDone, this.cycles = 12});

  @override
  State<_AltBreath> createState() => _AltBreathState();
}

class _AltBreathState extends State<_AltBreath> {
  int _t = 0; // secondes écoulées
  Timer? _timer;
  bool _running = false;

  int get _total => widget.cycles * 16;

  void _start() {
    _running = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _t++;
        if (_t % 4 == 0) HapticFeedback.lightImpact();
        if (_t >= _total) {
          _timer?.cancel();
          AppScope.read(context).noteSerenity('respiration alternée');
          widget.onDone();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = (_t ~/ 4) % 4; // 0 inspire G, 1 expire D, 2 inspire D, 3 expire G
    final left = phase == 0 || phase == 3;
    final inhale = phase.isEven;
    final count = 4 - _t % 4;
    Widget nostril(String label, bool active) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 96,
          height: 128,
          decoration: BoxDecoration(
            color: active ? _lav.withValues(alpha: 0.3) : K.card,
            borderRadius: BorderRadius.circular(48),
            border: Border.all(color: active ? _lav : K.line, width: 3),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label, style: K.body(11, color: active ? _lav : K.muted, w: FontWeight.w900)),
            Text(active ? (inhale ? '↑' : '↓') : '✋', style: K.display(26, color: active ? K.ink : K.muted)),
            Text(active ? (inhale ? 'inspire' : 'expire') : 'fermée', style: K.body(12, color: active ? K.ink : K.muted, w: FontWeight.w800)),
          ]),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text('Pouce droit sur la narine droite, annulaire sur la gauche. Dos droit, épaules basses. Tu peux fermer les yeux : une vibration marque chaque changement.', style: K.body(13, color: K.muted)),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          nostril('GAUCHE', _running && left),
          const SizedBox(width: 28),
          nostril('DROITE', _running && !left),
        ]),
        const SizedBox(height: 18),
        Center(child: Text(_running ? '$count' : '3 min', style: K.display(52, color: _lav))),
        Center(child: Text('cycle ${min(widget.cycles, _t ~/ 16 + 1)} / ${widget.cycles} · 4 s par phase', style: K.body(12, color: K.muted))),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: _t / _total, minHeight: 8, backgroundColor: K.raised, color: _lav),
        ),
        const SizedBox(height: 24),
        if (!_running) PrimaryButton(label: 'Commencer', color: _lav, onPressed: () => setState(_start)),
        if (_running) SecondaryButton(label: 'Ça suffit, continuer', onPressed: () {
          _timer?.cancel();
          widget.onDone();
        }),
      ],
    );
  }
}

/// « Quelle est la pensée suivante ? » : 3 minutes à attendre les pensées.
class _NextThought extends StatefulWidget {
  final VoidCallback onDone;
  const _NextThought({required this.onDone});

  @override
  State<_NextThought> createState() => _NextThoughtState();
}

class _NextThoughtState extends State<_NextThought> {
  int _t = 0;
  int _seen = 0;
  Timer? _timer;
  bool _running = false;
  static const _total = 180;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text('Assise, les yeux ouverts ou fermés. Demande-toi : « Quelle est ma pensée suivante ? » et attends-la, comme un chat devant un trou de souris. Quand une pensée arrive, touche le rond, laisse-la passer, et attends la suivante.',
              style: K.body(13, color: K.muted)),
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: _running
                  ? () {
                      HapticFeedback.selectionClick();
                      setState(() => _seen++);
                    }
                  : null,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(shape: BoxShape.circle, color: K.cyan.withValues(alpha: 0.12), border: Border.all(color: K.cyan, width: 3)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_running ? '$_seen' : '?', style: K.display(48, color: K.cyan)),
                  Text(_running ? 'pensées vues passer' : 'la pensée suivante', style: K.body(12, color: K.muted)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text(_running ? '${(_total - _t) ~/ 60}:${((_total - _t) % 60).toString().padLeft(2, '0')}' : '3 min', style: K.body(14, color: K.muted, w: FontWeight.w800))),
          const SizedBox(height: 8),
          Center(child: Text('Elles viennent, elles passent : tu n\'es pas elles.', style: _quoteStyle(13).copyWith(color: K.muted))),
          const SizedBox(height: 24),
          if (!_running)
            PrimaryButton(
              label: 'Commencer',
              color: K.cyan,
              onPressed: () => setState(() {
                _running = true;
                _timer = Timer.periodic(const Duration(seconds: 1), (_) {
                  if (!mounted) return;
                  setState(() => _t++);
                  if (_t >= _total) {
                    _timer?.cancel();
                    HapticFeedback.heavyImpact();
                    AppScope.read(context).noteSerenity('pensée suivante');
                    widget.onDone();
                  }
                });
              }),
            ),
          if (_running) SecondaryButton(label: 'Ça suffit, continuer', onPressed: () {
            _timer?.cancel();
            widget.onDone();
          }),
        ],
      );
}

class _BooksScreen extends StatefulWidget {
  const _BooksScreen();
  @override
  State<_BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<_BooksScreen> {
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final books = store.settings.books;
    return Scaffold(
      appBar: AppBar(title: const Text('Ma pile de livres')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('Les livres où piocher 10 pages au hasard.', style: K.body(13, color: K.muted)),
          const SizedBox(height: 10),
          for (final b in [...books])
            ListTile(
              title: Text(b.split('|').first, style: K.body(15)),
              subtitle: Text('${b.split('|').length > 1 ? b.split('|')[1] : '?'} pages', style: K.body(12, color: K.muted)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: K.muted),
                onPressed: () async {
                  books.remove(b);
                  await store.updateSettings();
                  setState(() {});
                },
              ),
            ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: '+ Ajouter un livre',
            onPressed: () async {
              final t = await askText(context, 'Titre et auteur', hint: 'L\'Éthique, Spinoza');
              if (t == null || t.isEmpty || !context.mounted) return;
              final p = await askText(context, 'Nombre de pages', hint: '350');
              books.add('$t|${int.tryParse(p ?? '') ?? 300}');
              await store.updateSettings();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}

class _ContactsScreen extends StatefulWidget {
  const _ContactsScreen();
  @override
  State<_ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<_ContactsScreen> {
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final list = store.settings.contacts;
    return Scaffold(
      appBar: AppBar(title: const Text('Mes personnes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('Une ou deux personnes à qui tu pourrais parler les jours lourds.', style: K.body(13, color: K.muted)),
          const SizedBox(height: 10),
          for (final c in [...list])
            ListTile(
              title: Text(c, style: K.body(15)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: K.muted),
                onPressed: () async {
                  list.remove(c);
                  await store.updateSettings();
                  setState(() {});
                },
              ),
            ),
          SecondaryButton(
            label: '+ Ajouter',
            onPressed: () async {
              final t = await askText(context, 'Qui ?', hint: 'un prénom');
              if (t == null || t.isEmpty) return;
              list.add(t);
              await store.updateSettings();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}

class _LibraryScreen extends StatefulWidget {
  const _LibraryScreen();
  @override
  State<_LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<_LibraryScreen> {
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final lib = store.settings.library;
    return Scaffold(
      appBar: AppBar(title: const Text('Ma bibliothèque')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (lib.isEmpty) Text('Les phrases que tu gardes dans la cabane arrivent ici.', style: K.body(13, color: K.muted)),
          for (final l in [...lib])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Dismissible(
                key: ValueKey(l),
                onDismissed: (_) async {
                  lib.remove(l);
                  await store.updateSettings();
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _lav.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: const Border(left: BorderSide(color: _lav, width: 3))),
                  child: Text(l, style: _quoteStyle(14)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
