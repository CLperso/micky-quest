import 'package:flutter/material.dart';

import 'pages/free.dart';
import 'store.dart';
import 'theme.dart';

/// « Mon style » : ambiance, papier, titres, niveau de déco, couverture, ton de Micky.
class StylePanel extends StatelessWidget {
  final VoidCallback onClose;
  const StylePanel({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final st = store.settings;
    final pal = Pal.byId(st.theme);
    Widget lab(String t) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 8), child: Label(t, pal.soft));
    Future<void> save() => store.touchSettings();
    final defPaper = store.paper('default');

    Widget swatch(Pal p) {
      final on = st.theme == p.id;
      return GestureDetector(
        onTap: () async {
          st.theme = p.id;
          await store.setPaper('default', color: 0);
          await save();
        },
        child: Container(
          width: 132,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: pal.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: on ? pal.ink : pal.line, width: on ? 2 : 1)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(height: 32, child: Row(children: [for (final c in [p.tint, p.cover, p.acc, p.paper]) Expanded(child: Container(color: c))])),
            ),
            const SizedBox(height: 6),
            Text(p.name, style: body(12, pal.ink, w: FontWeight.w800)),
          ]),
        ),
      );
    }

    Widget chip(String label, bool on, VoidCallback f, {TextStyle? style}) => Padding(
          padding: const EdgeInsets.only(right: 6, bottom: 6),
          child: ChoiceChip(label: Text(label, style: style), selected: on, onSelected: (_) => f()),
        );

    return Material(
      color: pal.paper,
      elevation: 6,
      borderRadius: BorderRadius.circular(24),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
          child: Row(children: [
            Expanded(child: Text('Mon style', style: titleFont(32, pal.ink))),
            IconButton(onPressed: onClose, icon: Icon(Icons.close_rounded, color: pal.soft)),
          ]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
            Text('Tout se change à tout moment. Le papier et les couleurs se règlent aussi page par page dans l’atelier.', style: body(12, pal.soft, w: FontWeight.w600)),
            lab('Ambiance'),
            Wrap(spacing: 10, runSpacing: 10, children: [for (final p in Pal.all) swatch(p)]),
            lab('Papier'),
            Wrap(spacing: 10, runSpacing: 8, children: [
              for (final (k, n) in [...freePapers, ('kraft', 'Kraft')])
                GestureDetector(
                  onTap: () => store.setPaper('default', pattern: k == 'kraft' ? 'dots' : k, color: k == 'kraft' ? 0xFFD8C3A5 : 0),
                  child: Column(children: [
                    Container(
                      width: 52,
                      height: 66,
                      decoration: BoxDecoration(
                        color: k == 'kraft' ? const Color(0xFFD8C3A5) : pal.paper,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: (k == 'kraft' ? defPaper.color == 0xFFD8C3A5 : defPaper.pattern == k && defPaper.color != 0xFFD8C3A5) ? pal.ink : pal.line,
                            width: 1.5),
                      ),
                      child: ClipRRect(borderRadius: BorderRadius.circular(5), child: CustomPaint(painter: MiniPaper(k == 'kraft' ? 'dots' : k, pal.dot))),
                    ),
                    const SizedBox(height: 3),
                    Text(n, style: body(10.5, pal.ink, w: FontWeight.w800)),
                  ]),
                ),
            ]),
            lab('Titres'),
            Wrap(children: [
              chip('Élégant', st.titleStyle == 'elegant', () {
                st.titleStyle = 'elegant';
                save();
              }),
              chip('Lettering', st.titleStyle == 'lettering', () {
                st.titleStyle = 'lettering';
                save();
              }),
              chip('Manuscrit', st.titleStyle == 'manuscrit', () {
                st.titleStyle = 'manuscrit';
                save();
              }),
            ]),
            lab('Niveau de déco'),
            Slider(
              value: st.decoLevel,
              min: 0,
              max: 2,
              divisions: 4,
              activeColor: pal.acc,
              onChanged: (v) {
                st.decoLevel = v;
                store.refresh();
              },
              onChangeEnd: (_) => save(),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('épuré', style: body(11, pal.soft, w: FontWeight.w800)),
              Text('doux', style: body(11, pal.soft, w: FontWeight.w800)),
              Text('kawaii à fond', style: body(11, pal.soft, w: FontWeight.w800)),
            ]),
            lab('Couverture'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in coverStyles.entries)
                GestureDetector(
                  onTap: () {
                    st.coverStyle = e.key;
                    save();
                  },
                  child: Container(
                    width: 44,
                    height: 58,
                    decoration: BoxDecoration(
                      color: e.value,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(3), right: Radius.circular(9)),
                      border: Border.all(color: st.coverStyle == e.key ? pal.ink : Colors.transparent, width: 2),
                    ),
                  ),
                ),
            ]),
            Text('Pour changer les textes de la couverture, touche l’étiquette sur la couverture.', style: body(11.5, pal.soft, w: FontWeight.w600)),
            lab('Étiquettes des jours (semaine)'),
            Wrap(children: [
              for (final (k, n) in [('tag', 'Étiquette'), ('washi', 'Washi'), ('souligne', 'Souligné'), ('cadre', 'Encadré'), ('script', 'Lettering')])
                chip(n, st.labelStyle == k, () {
                  st.labelStyle = k;
                  save();
                }),
            ]),
            lab('Textes et parties'),
            Text('Touche n’importe quel titre ou rubrique d’une page pour le renommer, le cacher ou masquer toute la partie.', style: body(11.5, pal.soft, w: FontWeight.w600)),
            if (st.hidden.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Parties masquées (touche pour les remettre) :', style: body(12, pal.ink, w: FontWeight.w800)),
              const SizedBox(height: 6),
              Wrap(children: [
                for (final h in [...st.hidden])
                  Padding(
                    padding: const EdgeInsets.only(right: 6, bottom: 6),
                    child: InputChip(
                      label: Text(st.labels[h]?.isNotEmpty == true ? st.labels[h]! : partName(h)),
                      onDeleted: () {
                        st.hidden.remove(h);
                        save();
                      },
                      onPressed: () {
                        st.hidden.remove(h);
                        save();
                      },
                    ),
                  ),
              ]),
            ],
            if (st.labels.isNotEmpty)
              TextButton(
                onPressed: () {
                  st.labels.clear();
                  save();
                },
                child: const Text('Remettre tous les textes par défaut'),
              ),
            lab('Ton de Micky'),
            Wrap(children: [
              for (final (k, n) in [('discrete', 'Discrète'), ('douce', 'Douce'), ('taquine', 'Taquine'), ('coach', 'Coach')])
                chip(n, st.mickyTone == k, () {
                  st.mickyTone = k;
                  save();
                }),
            ]),
            lab('Stylet'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Écrire seulement au stylet', style: body(14, pal.ink)),
              subtitle: Text('Les doigts servent à zoomer et à se déplacer.', style: body(12, pal.soft, w: FontWeight.w600)),
              value: st.stylusOnly,
              onChanged: (v) {
                st.stylusOnly = v;
                store.save();
                store.refresh();
              },
            ),
          ]),
        ),
      ]),
    );
  }
}

String partName(String id) => const {
      'day.intention': 'Intention',
      'day.goals': 'Objectifs du jour',
      'day.win': 'Victoire',
      'day.journal': 'Journal',
      'month.pro': 'Temps de travail du mois',
      'month.stats': 'Bilan du mois',
      'trk.period': 'Règles',
      'trk.mood': 'Humeur',
      'trk.energy': 'Énergie',
      'trk.pro': 'Temps de travail',
      'cover.card': 'Étiquette de la couverture',
      'week.focus': 'Cette semaine',
      'week.trackers': 'Trackers de la semaine',
    }[id] ??
    (id.startsWith('trk.') ? 'Un tracker' : id);
