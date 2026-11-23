import 'package:flutter/material.dart';

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
