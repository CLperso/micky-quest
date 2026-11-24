import 'package:flutter/material.dart';

import '../bio.dart';
import '../model.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Les formats d'écriture : (titre, sous-titre, amorce, couleur).
const journalKinds = {
  'libre': ('Expression libre', 'ce qui vient, sans relire', '', 0xFFB9A7C2),
  'gratitude': ('Trois bonnes choses', 'gratitude, 3 lignes', '1.\n2.\n3.', 0xFFC6A26A),
  'pages': ('Pages du matin', '3 pages sans s’arrêter', '', 0xFFB9A7C2),
  'pese': ('Ce qui pèse', 'le poser, puis un petit geste', '', 0xFFA9BCD3),
  'fierte': ('Une fierté', 'même minuscule', '', 0xFFD7A6A8),
  'lettre': ('Lettre à moi', 'comme à une amie', 'Chère Charlotte,\n', 0xFFA9B8A0),
  'appris': ('Ce que j’ai appris', 'sur moi, cette semaine', '', 0xFFB0707A),
};

const _moments = {'matin': 'le matin', 'soir': 'le soir', 'libre': 'quand je veux'};

// =====================================================================
// Page de gauche : expression libre (et les formats choisis ce jour-là)
// =====================================================================
class JournalFree extends StatelessWidget {
  final String day;
  const JournalFree({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final d = parseDay(day);
    final list = store.dayJournal(day);
    final hasFree = list.any((j) => j.kind == 'libre');
    final defMoment = DateTime.now().hour < 14 ? 'matin' : 'soir';
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageTitle(id: 'jrn.L', over: '{jour} {n} {mois}', title: 'Expression libre', vars: dayVars(d)),
        Text('Tu écris ce qui vient, sans relire ni corriger. Pas de question, pas de cadre.', style: body(11.5, pal.soft, w: FontWeight.w700)),
        const SizedBox(height: 8),
        if (!hasFree)
          _EntryView(
            key: const ValueKey('new-libre'),
            entry: null,
            day: day,
            kind: 'libre',
            moment: defMoment,
          ),
        for (final j in list) _EntryView(key: ValueKey(j.id), entry: j, day: day, kind: j.kind, moment: j.moment),
      ]),
    );
  }
}

class _EntryView extends StatefulWidget {
  final JEntry? entry;
  final String day, kind, moment;
  const _EntryView({super.key, required this.entry, required this.day, required this.kind, required this.moment});
  @override
  State<_EntryView> createState() => _EntryViewState();
}

class _EntryViewState extends State<_EntryView> {
  JEntry? _e;
  late String _moment = widget.moment;

  @override
  void initState() {
    super.initState();
    _e = widget.entry;
  }

  Future<JEntry> _ensure(Store store) async {
    _e ??= await store.addJournal(widget.day, kind: widget.kind, moment: _moment);
    return _e!;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final k = journalKinds[widget.kind] ?? journalKinds['libre']!;
    final e = _e;
    final share = e?.share ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.only(top: 6),
      decoration: widget.kind == 'libre' ? null : BoxDecoration(border: Border(top: BorderSide(color: Color(k.$4), width: 3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 4, children: [
          if (widget.kind != 'libre') Text(k.$1, style: hand(22, pal.ink)),
          for (final m in _moments.entries)
            ChoiceChip(
              visualDensity: VisualDensity.compact,
              label: Text(m.value, style: body(11.5, pal.ink, w: FontWeight.w800)),
              selected: _moment == m.key,
              onSelected: (_) async {
                setState(() => _moment = m.key);
                final x = await _ensure(store);
                x.moment = m.key;
                await store.touchJournal(x);
              },
            ),
        ]),
        HandField(
          value: e?.text ?? '',
          hint: widget.kind == 'libre' ? 'écris ici…' : (k.$3.isEmpty ? k.$2 : k.$3),
          size: 24,
          color: const Color(0xFF5A4A6A),
          maxLines: 30,
          onChanged: (v) async {
            final x = await _ensure(store);
            x.text = v;
            await store.touchJournal(x);
          },
        ),
        const SizedBox(height: 6),
        Row(children: [
          Icon(share ? Icons.lock_open_rounded : Icons.lock_outline_rounded, size: 16, color: pal.soft),
          const SizedBox(width: 6),
          Expanded(child: Text(share ? 'Micky peut lire cette page' : 'Page privée · Micky ne la lit pas', style: body(11.5, pal.soft, w: FontWeight.w700))),
          TextButton(
            onPressed: () async {
              final x = await _ensure(store);
              x.share = !x.share;
              await store.touchJournal(x);
              setState(() {});
            },
            child: Text(share ? 'garder privée' : 'montrer à Micky'),
          ),
          if (e != null && widget.kind != 'libre')
            IconButton(
              tooltip: 'Supprimer',
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                e.del = true;
                await store.touchJournal(e);
              },
              icon: Icon(Icons.delete_outline_rounded, size: 18, color: pal.soft),
            ),
        ]),
      ]),
    );
  }
}

// =====================================================================
// Page de droite : envies d'écrire, il y a un mois, mots du mois
// =====================================================================
const _stop = {
  'avec', 'dans', 'pour', 'mais', 'plus', 'tout', 'tous', 'toute', 'toutes', 'cette', 'comme', 'être', 'avoir', 'fait', 'faire', 'suis', 'était', 'sont', 'elle', 'elles', 'nous', 'vous', 'leur', 'leurs', 'quand', 'alors', 'aussi', 'encore', 'très', 'peut', 'même', 'sans', 'chez', 'sous', 'vers', 'entre', 'après', 'avant', 'depuis', 'pendant', 'parce', 'donc', 'puis', 'rien', 'quoi', 'juste', 'trop', 'bien', 'moins', 'ceux', 'celle', 'celui', 'cela', 'ça', 'qu’il', 'qu’elle', 'c’est', 'j’ai', 'n’ai', 'n’est', 'm’a', 'j’en', 'faut', 'veux', 'vais', 'ai', 'avait', 'aujourd’hui', 'demain', 'hier', 'matin', 'soir', 'journée', 'chose', 'choses', 'beaucoup', 'peu', 'vraiment', 'dont', 'notre', 'votre', 'quelque', 'autre', 'autres', 'déjà', 'jamais', 'toujours', 'ici', 'voilà', 'enfin', 'envie', 'pense', 'crois', 'sais', 'aller', 'reste', 'moment', 'temps',
};

class JournalIdeas extends StatelessWidget {
  final String day;
  final VoidCallback onWrite;
  const JournalIdeas({super.key, required this.day, required this.onWrite});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final d = parseDay(day);

    // il y a un mois (± 3 jours)
    JEntry? past;
    for (final off in [30, 29, 31, 28, 32, 27, 33]) {
      final k = dayKey(d.subtract(Duration(days: off)));
      final l = store.dayJournal(k).where((j) => j.text.trim().length > 20).toList();
      if (l.isNotEmpty) {
        past = l.first;
        break;
      }
    }

    // mots du mois
    final counts = <String, int>{};
    for (final j in store.journals.values) {
      if (j.del) continue;
      final jd = DateTime.tryParse(j.day);
      if (jd == null || d.difference(jd).inDays > 30 || jd.isAfter(d)) continue;
      for (final w in j.text.toLowerCase().replaceAll('\'', '’').split(RegExp(r'[^a-zà-ÿœæ’-]+'))) {
        if (w.length < 4 || _stop.contains(w)) continue;
        counts[w] = (counts[w] ?? 0) + 1;
      }
    }
    final words = counts.entries.where((e) => e.value >= 2).toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = words.take(12).toList();
    final maxC = top.isEmpty ? 1 : top.first.value;
    final wcols = [pal.acc, pal.acc2, pal.acc3, const Color(0xFFB9A7C2), const Color(0xFFA9BCD3)];

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const PageTitle(id: 'jrn.R', over: 'mon journal', title: 'Envie d’écrire sur…'),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, box) {
          final w = (box.maxWidth - 10) / 2;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final e in journalKinds.entries.where((e) => e.key != 'libre'))
              SizedBox(
                width: w,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    await store.addJournal(day, kind: e.key, moment: DateTime.now().hour < 14 ? 'matin' : 'soir', text: e.value.$3);
                    onWrite();
                  },
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                    decoration: BoxDecoration(
                      color: pal.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border(top: BorderSide(color: Color(e.value.$4), width: 4), left: BorderSide(color: pal.line), right: BorderSide(color: pal.line), bottom: BorderSide(color: pal.line)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.value.$1, style: titleFont(19, pal.ink)),
                      Text(e.value.$2, style: body(11, pal.soft, w: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
          ]);
        }),
        const SizedBox(height: 18),
        if (past != null) ...[
          Label('il y a un mois · ${niceDay(parseDay(past.day))}', pal.soft),
          const SizedBox(height: 6),
          Transform.rotate(
            angle: -0.03,
            child: Container(
              margin: const EdgeInsets.only(right: 60),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: BoxDecoration(color: pal.card, boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 3))]),
              child: Text('« ${_excerpt(past.text)} »', style: hand(20, const Color(0xFF5A4A6A))),
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (top.isNotEmpty) ...[
          Label('mes mots du mois', pal.soft),
          Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.end, children: [
            for (var i = 0; i < top.length; i++)
              Text(top[i].key, style: titleFont(16 + 16 * top[i].value / maxC, wcols[i % wcols.length]).copyWith(fontStyle: FontStyle.italic)),
          ]),
        ],
        if (past == null && top.isEmpty)
          Text('Plus tu écris, plus cette page se remplit : une phrase d’il y a un mois, et les mots qui reviennent.', style: body(12, pal.soft, w: FontWeight.w700)),
      ]),
    );
  }

  static String _excerpt(String t) {
    final s = t.trim().replaceAll('\n', ' ');
    final dot = s.indexOf(RegExp(r'[.!?]'), 30);
    final cut = dot > 0 && dot < 180 ? dot + 1 : (s.length > 160 ? 160 : s.length);
    return '${s.substring(0, cut)}${cut < s.length && (dot <= 0 || dot >= 180) ? '…' : ''}';
  }
}

// =====================================================================
// Le journal comme un vrai carnet : deux pages libres, et un cadenas
// =====================================================================

/// Page de journal libre (gauche : la date ; droite : rien que la place pour écrire).
class JournalPage extends StatelessWidget {
  final String day;
  final bool left;
  const JournalPage({super.key, required this.day, required this.left});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final d = parseDay(day);
    final typed = store.dayJournal(day).where((j) => j.text.trim().isNotEmpty).toList();
    if (!left) return const SizedBox.expand();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageTitle(id: 'jrnp.L', over: 'journal', title: '{jour} {n} {mois}', vars: dayVars(d)),
      // ce qui avait été tapé avant reste là, comme écrit
      for (final j in typed)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(j.text, style: hand(21, const Color(0xFF5A4A6A))),
        ),
      if (typed.isEmpty) Text('écris ce qui vient, au stylet, n’importe où', style: body(11, pal.soft, w: FontWeight.w700)),
    ]);
  }
}

/// Empreinte d'un code (FNV-1a 32 bits, deux passes) : on ne garde jamais le code lui-même.
/// Calcul sans dépasser 2^53, pour donner le même résultat sur la tablette et sur le PC.
String pinHash(String pin) {
  int fnv(String t, int h) {
    for (final c in t.codeUnits) {
      h = (h ^ c) & 0xFFFFFFFF;
      // h * 16777619 = h * 0x193 + h * 2^24, modulo 2^32
      h = (h * 0x193 + ((h & 0xFF) << 24)) & 0xFFFFFFFF;
    }
    return h;
  }

  final a = fnv('carnet-micky:$pin', 0x811c9dc5);
  final b = fnv('$pin:micky-carnet', a);
  return '${a.toRadixString(16)}${b.toRadixString(16)}';
}

/// Le cadenas du journal : un code à 4 chiffres, ou l'empreinte sur la tablette.
class JournalLock extends StatefulWidget {
  final VoidCallback onUnlock;
  const JournalLock({super.key, required this.onUnlock});
  @override
  State<JournalLock> createState() => _JournalLockState();
}

class _JournalLockState extends State<JournalLock> {
  String _code = '';
  String? _first; // création du code : première saisie
  String _msg = '';
  bool _bio = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBio(auto: true));
  }

  Future<void> _tryBio({bool auto = false}) async {
    if (!mounted || StoreScope.read(context).settings.jrnPin.isEmpty) return;
    final ok = await biometricUnlock();
    if (!mounted) return;
    if (ok == null) return;
    setState(() => _bio = true);
    if (ok) widget.onUnlock();
  }

  Future<void> _digit(String d) async {
    final store = StoreScope.read(context);
    if (_code.length >= 4) return;
    setState(() {
      _code += d;
      _msg = '';
    });
    if (_code.length < 4) return;
    await Future.delayed(const Duration(milliseconds: 120));
    final pin = store.settings.jrnPin;
    if (pin.isEmpty) {
      if (_first == null) {
        setState(() {
          _first = _code;
          _code = '';
          _msg = 'Encore une fois, pour confirmer';
        });
      } else if (_first == _code) {
        store.settings.jrnPin = pinHash(_code);
        await store.touchSettings();
        widget.onUnlock();
      } else {
        setState(() {
          _first = null;
          _code = '';
          _msg = 'Les deux codes ne sont pas pareils, on recommence';
        });
      }
      return;
    }
    if (pinHash(_code) == pin) {
      widget.onUnlock();
    } else {
      setState(() {
        _code = '';
        _msg = 'Ce n’est pas le bon code';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final creating = store.settings.jrnPin.isEmpty;
    Widget key(String t, {VoidCallback? onTap, Widget? child}) => Padding(
          padding: const EdgeInsets.all(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: onTap ?? (t.isEmpty ? null : () => _digit(t)),
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(color: t.isEmpty && child == null ? Colors.transparent : pal.card, shape: BoxShape.circle, border: Border.all(color: t.isEmpty && child == null ? Colors.transparent : pal.line)),
              child: Center(child: child ?? Text(t, style: titleFont(28, pal.ink))),
            ),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFFECE5F0), pal.tint]),
      ),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_rounded, size: 46, color: pal.acc),
            const SizedBox(height: 6),
            Text('Mon journal', style: titleFont(38, pal.ink)),
            Text(creating ? (_first == null ? 'Choisis un code à 4 chiffres' : 'Encore une fois') : 'rien que pour moi', style: body(13, pal.soft, w: FontWeight.w800)),
            const SizedBox(height: 16),
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < 4; i++)
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: i < _code.length ? pal.acc : Colors.transparent, border: Border.all(color: pal.acc, width: 2)),
                ),
            ]),
            SizedBox(height: 26, child: Center(child: Text(_msg, style: body(12, pal.acc, w: FontWeight.w800)))),
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
            ])
              Row(mainAxisSize: MainAxisSize.min, children: [for (final t in row) key(t)]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _bio || !creating ? key('', onTap: () => _tryBio(), child: Icon(Icons.fingerprint_rounded, color: pal.acc, size: 30)) : key(''),
              key('0'),
              key('', onTap: () => setState(() => _code = _code.isEmpty ? '' : _code.substring(0, _code.length - 1)), child: Icon(Icons.backspace_outlined, color: pal.ink, size: 22)),
            ]),
            const SizedBox(height: 10),
            Text('Le journal se reverrouille dès que tu changes d’onglet. Micky n’y a pas accès.', textAlign: TextAlign.center, style: body(11, pal.soft, w: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}
