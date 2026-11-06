import 'package:flutter/material.dart';

import '../canvas.dart';
import '../model.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

const freePapers = [('dots', 'Points'), ('grid', 'Quadrillé'), ('lines', 'Lignes'), ('plain', 'Uni')];

/// L'index des pages libres : journal, dessins, mind maps…
class FreeIndex extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const FreeIndex({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final pages = store.activeFree;
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const PageTitle(over: 'mes pages', title: 'Pages libres'),
        Text('journal, dessin, mind map… appui long pour renommer, déplacer, supprimer', style: hand(20, pal.soft)),
        const SizedBox(height: 14),
        Wrap(spacing: 12, runSpacing: 14, children: [
          for (final p in pages)
            GestureDetector(
              onTap: () => onSelect(p.id),
              onLongPress: () => _menu(context, store, p),
              child: SizedBox(
                width: 112,
                child: Column(children: [
                  Container(
                    width: 104,
                    height: 136,
                    decoration: BoxDecoration(
                      color: pal.paper,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: p.id == selected ? pal.acc : pal.line, width: p.id == selected ? 3 : 1.5),
                      boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    child: ClipRRect(borderRadius: BorderRadius.circular(8), child: CustomPaint(painter: MiniPaper(p.paper, pal.dot))),
                  ),
                  const SizedBox(height: 5),
                  Text(p.title.isEmpty ? 'Sans titre' : p.title, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: body(12, pal.ink, w: FontWeight.w800)),
                ]),
              ),
            ),
          GestureDetector(
            onTap: () => _add(context, store),
            child: Container(
              width: 104,
              height: 136,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: pal.acc.withValues(alpha: .5), width: 2)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_rounded, color: pal.acc, size: 30),
                Text('une page', style: body(12, pal.acc, w: FontWeight.w800)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }

  Future<void> _add(BuildContext context, Store store) async {
    final pal = Pal.byId(store.settings.theme);
    final paper = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: pal.paper,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Une nouvelle page', style: titleFont(30, pal.ink)),
            const SizedBox(height: 14),
            Wrap(spacing: 14, children: [
              for (final (k, n) in freePapers)
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, k),
                  child: Column(children: [
                    Container(
                      width: 74,
                      height: 96,
                      decoration: BoxDecoration(color: pal.paper, borderRadius: BorderRadius.circular(8), border: Border.all(color: pal.line, width: 1.5)),
                      child: ClipRRect(borderRadius: BorderRadius.circular(7), child: CustomPaint(painter: MiniPaper(k, pal.dot))),
                    ),
                    const SizedBox(height: 4),
                    Text(n, style: body(12, pal.ink)),
                  ]),
                ),
            ]),
          ]),
        ),
      ),
    );
    if (paper == null) return;
    final p = await store.addFreePage(paper: paper);
    onSelect(p.id);
  }

  Future<void> _menu(BuildContext context, Store store, FreePage p) async {
    final r = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Renommer'), onTap: () => Navigator.pop(ctx, 'rename')),
          ListTile(leading: const Icon(Icons.arrow_back_rounded), title: const Text('Avancer'), onTap: () => Navigator.pop(ctx, 'up')),
          ListTile(leading: const Icon(Icons.arrow_forward_rounded), title: const Text('Reculer'), onTap: () => Navigator.pop(ctx, 'down')),
          ListTile(leading: const Icon(Icons.delete_outline_rounded), title: const Text('Supprimer'), onTap: () => Navigator.pop(ctx, 'del')),
        ]),
      ),
    );
    if (r == null || !context.mounted) return;
    switch (r) {
      case 'rename':
        final t = await askText(context, 'Titre de la page', initial: p.title);
        if (t == null) return;
        p.title = t;
        await store.touchFree(p);
        break;
      case 'up':
        await store.moveFree(p, -1);
        break;
      case 'down':
        await store.moveFree(p, 1);
        break;
      case 'del':
        p.del = true;
        await store.touchFree(p);
        break;
    }
  }
}

/// Une page libre : un titre, et toute la place pour écrire, dessiner, coller.
class FreePageView extends StatelessWidget {
  final String id;
  const FreePageView({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final p = store.freePages[id];
    if (p == null || p.del) {
      return Center(child: Text('Crée une page à gauche ✿', style: hand(26, pal.soft)));
    }
    return Align(
      alignment: Alignment.topLeft,
      child: GestureDetector(
        onTap: () async {
          final t = await askText(context, 'Titre de la page', initial: p.title);
          if (t == null) return;
          p.title = t;
          await store.touchFree(p);
        },
        child: Text(p.title.isEmpty ? 'Sans titre' : p.title, style: titleFont(34, p.title.isEmpty ? pal.soft : pal.ink)),
      ),
    );
  }
}

class MiniPaper extends CustomPainter {
  final String pattern;
  final Color c;
  MiniPaper(this.pattern, this.c);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = c
      ..strokeWidth = 0.8;
    const step = 9.0;
    switch (pattern) {
      case 'dots':
        for (var x = step; x < size.width; x += step) {
          for (var y = step; y < size.height; y += step) {
            canvas.drawCircle(Offset(x, y), 0.9, p);
          }
        }
        break;
      case 'grid':
        for (var x = step; x < size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        }
        for (var y = step; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
        break;
      case 'lines':
        for (var y = 18.0; y < size.height; y += 11) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(MiniPaper o) => o.pattern != pattern || o.c != c;
}
