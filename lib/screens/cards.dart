import 'package:flutter/material.dart';

import '../cards.dart';
import '../main.dart';
import '../theme.dart';

Color rarityColor(int r) => r == 3 ? K.gold : (r == 2 ? K.cyan : K.lime);

/// Révèle la carte en attente (tâche pro finie), s'il y en a une.
Future<void> showPendingCard(BuildContext context) async {
  final store = AppScope.read(context);
  final d = store.pendingCard;
  if (d == null) return;
  store.pendingCard = null;
  final c = Cards.byId(d.card);
  if (c == null) return;
  final n = store.cardCounts[c.id] ?? 1;
  await showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CardFace(card: c, count: n, xp: d.xp, title: d.title, isNew: n == 1),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: SecondaryButton(
              label: 'Ma collection',
              onPressed: () {
                Navigator.pop(ctx);
                openScreen(context, const CardsScreen());
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: PrimaryButton(label: 'Miaou !', onPressed: () => Navigator.pop(ctx))),
        ]),
      ]),
    ),
  );
}

/// Une carte : photo, nom, rareté, XP de la tâche, nombre d'exemplaires (×3 = brillante).
class CardFace extends StatelessWidget {
  final MickyCard card;
  final int count, xp;
  final String title;
  final bool isNew;
  const CardFace({super.key, required this.card, this.count = 1, this.xp = 0, this.title = '', this.isNew = false});

  @override
  Widget build(BuildContext context) {
    final c = rarityColor(card.rarity);
    final shiny = count >= 3;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: K.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c, width: 3),
        gradient: shiny ? LinearGradient(colors: [c.withValues(alpha: 0.35), K.card, c.withValues(alpha: 0.35)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
        boxShadow: [BoxShadow(color: c.withValues(alpha: shiny ? 0.6 : 0.3), blurRadius: shiny ? 28 : 14)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(Cards.rarityNames[card.rarity].toUpperCase(), style: K.body(11, color: c, w: FontWeight.w900).copyWith(letterSpacing: 1)),
          const Spacer(),
          if (isNew) Pill('NOUVELLE', color: K.bg, fill: c) else Text(shiny ? '✨ ×$count brillante' : '×$count', style: K.body(12, color: c, w: FontWeight.w900)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(aspectRatio: 4 / 5, child: Image.asset(card.asset, fit: BoxFit.cover)),
        ),
        const SizedBox(height: 10),
        Text(card.name, textAlign: TextAlign.center, style: K.display(22)),
        if (xp > 0) Text('+$xp XP', textAlign: TextAlign.center, style: K.display(18, color: c)),
        if (title.isNotEmpty) Text('pour « $title »', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: K.body(12, color: K.muted)),
      ]),
    );
  }
}

/// La galerie : toutes les cartes, celles qui manquent restent cachées.
class CardsScreen extends StatelessWidget {
  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final counts = store.cardCounts;
    final owned = Cards.all.where((c) => counts.containsKey(c.id)).length;
    final drops = store.drops;
    return Scaffold(
      appBar: AppBar(title: const Text('Cartes Micky')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
          children: [
            Text('$owned / ${Cards.all.length} cartes · ${drops.length} gagnées en tout', style: K.body(13, color: K.muted, w: FontWeight.w800)),
            Text('Une carte par tâche pro finie. Trois fois la même : elle devient brillante.', style: K.body(12, color: K.dim)),
            const SizedBox(height: 10),
            for (final r in [3, 2, 1]) ...[
              Text(Cards.rarityNames[r], style: K.display(16, color: rarityColor(r))),
              const SizedBox(height: 6),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.8,
                children: [
                  for (final c in Cards.all.where((c) => c.rarity == r))
                    Builder(builder: (context) {
                      final n = counts[c.id] ?? 0;
                      final col = rarityColor(r);
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: n == 0
                            ? null
                            : () => showDialog(
                                  context: context,
                                  builder: (ctx) => Dialog(
                                    backgroundColor: Colors.transparent,
                                    insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                                    child: GestureDetector(onTap: () => Navigator.pop(ctx), child: CardFace(card: c, count: n)),
                                  ),
                                ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: K.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: n == 0 ? K.line : col, width: n >= 3 ? 3 : 2),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: n == 0
                              ? Center(child: Icon(Icons.pets_rounded, color: K.line, size: 30))
                              : Stack(fit: StackFit.expand, children: [
                                  Image.asset(c.asset, fit: BoxFit.cover),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      color: Colors.black54,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      child: Text('${c.name}${n > 1 ? ' ×$n' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: K.body(10, color: Colors.white, w: FontWeight.w800)),
                                    ),
                                  ),
                                ]),
                        ),
                      );
                    }),
                ],
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

/// Petite carte d'entrée vers la collection.
class CardsEntry extends StatelessWidget {
  const CardsEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final owned = store.cardCounts.length;
    final last = store.drops.isEmpty ? null : Cards.byId(store.drops.last.card);
    return Material(
      color: K.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openScreen(context, const CardsScreen()),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: last == null
                  ? Container(width: 46, height: 46, color: K.raised, child: const Icon(Icons.pets_rounded, color: K.muted))
                  : Image.asset(last.asset, width: 46, height: 46, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Cartes Micky', style: K.display(15)),
                Text('$owned / ${Cards.all.length} · une par tâche pro finie', style: K.body(12, color: K.muted)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: K.gold),
          ]),
        ),
      ),
    );
  }
}
