import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'canvas.dart';
import 'model.dart';
import 'store.dart';
import 'theme.dart';

/// L'atelier déco : washi, stickers, cadres, texte, papier, palette, favoris et modèles.
class Atelier extends StatefulWidget {
  const Atelier({super.key});
  @override
  State<Atelier> createState() => _AtelierState();
}

class _AtelierState extends State<Atelier> {
  int _tab = 0;
  static const _tabs = ['Washi', 'Stickers', 'Cadres', 'Texte', 'Papier', 'Favoris'];

  String _page(Desk desk) => desk.focusPage;

  Future<void> _place(Store store, Desk desk, Deco d) async {
    if (_page(desk).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Touche d’abord la page à décorer')));
      return;
    }
    await store.addDeco(d);
    desk.select(d.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final desk = DeskScope.of(context);
    final pal = Pal.byId(store.settings.theme);
    final page = _page(desk);

    Widget section(String t) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(t.toUpperCase(), style: body(11, pal.soft, w: FontWeight.w800).copyWith(letterSpacing: 1.4)),
        );

    Widget content;
    switch (_tab) {
      case 0:
        final colors = store.settings.palette.where((c) => c != 0xFFFFFFFF).toList();
        content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Choisis un rouleau, puis tire-le sur la page.', style: body(13, pal.soft)),
          for (final pat in washiPatterns) ...[
            section(pat == 'stripes' ? 'Rayures' : pat == 'dots' ? 'Pois' : pat == 'grid' ? 'Quadrillé' : pat == 'solid' ? 'Uni' : pat == 'zigzag' ? 'Zigzag' : 'Damier'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in colors)
                GestureDetector(
                  onTap: () => desk.arm({'color': c, 'pattern': pat, 'opacity': 0.75}),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: desk.washi != null && desk.washi!['color'] == c && desk.washi!['pattern'] == pat ? pal.ink : Colors.transparent, width: 2),
                    ),
                    child: CustomPaint(size: const Size(76, 22), painter: WashiPainter(Color(c), pat, 0.75)),
                  ),
                ),
            ]),
          ],
          const SizedBox(height: 10),
          if (desk.washi != null) TextButton(onPressed: () => desk.arm(null), child: const Text('Ranger le rouleau')),
        ]);
        break;
      case 1:
        final mine = store.images.keys.toList();
        content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          section('Micky'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 1; i <= 38; i++)
              GestureDetector(
                onTap: () => _place(store, desk, Deco(page: page, type: 'sticker', x: 300, y: 360, w: 150, h: 150, rot: -0.08, style: {'asset': 'm${two(i)}', 'shape': 'round'})),
                child: ClipOval(child: Image.asset('assets/micky/m${two(i)}.jpg', width: 58, height: 58, fit: BoxFit.cover)),
              ),
          ]),
          section('Mes images'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final id in mine)
              GestureDetector(
                onTap: () => _place(store, desk, Deco(page: page, type: 'image', x: 300, y: 360, w: 160, h: 160, style: {'img': id, 'shape': 'square'})),
                child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(base64Decode(store.images[id]!), width: 58, height: 58, fit: BoxFit.cover)),
              ),
            GestureDetector(
              onTap: () async {
                final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 500, maxHeight: 500, imageQuality: 72);
                if (x == null) return;
                final id = await store.addImage(encodeImage(await x.readAsBytes()));
                await _place(store, desk, Deco(page: page, type: 'image', x: 300, y: 360, w: 170, h: 170, style: {'img': id, 'shape': 'square'}));
              },
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: pal.line, width: 2)),
                child: Icon(Icons.add_photo_alternate_rounded, color: pal.soft),
              ),
            ),
          ]),
          for (final e in stickerEmojis.entries) ...[
            section(e.key),
            Wrap(spacing: 4, runSpacing: 4, children: [
              for (final em in e.value)
                GestureDetector(
                  onTap: () => _place(store, desk, Deco(page: page, type: 'emoji', x: 300, y: 360, w: 80, h: 80, style: {'emoji': em})),
                  child: SizedBox(width: 44, height: 44, child: Center(child: Text(em, style: const TextStyle(fontSize: 30)))),
                ),
            ]),
          ],
        ]);
        break;
      case 2:
        content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pose un cadre, puis agrandis-le autour de ce que tu veux mettre en valeur.', style: body(13, pal.soft)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final f in framePatterns)
              GestureDetector(
                onTap: () => _place(
                    store,
                    desk,
                    Deco(
                        page: page,
                        type: 'frame',
                        x: 300,
                        y: 360,
                        w: f == 'polaroid' ? 200 : 300,
                        h: f == 'polaroid' ? 240 : (f == 'tag' ? 70 : 180),
                        style: {'pattern': f, 'color': pal.acc.value})),
                child: Column(children: [
                  CustomPaint(size: const Size(80, 56), painter: FramePainter(f, pal.acc, null)),
                  const SizedBox(height: 4),
                  Text(frameNames[f] ?? f, style: body(11, pal.ink)),
                ]),
              ),
          ]),
        ]);
        break;
      case 3:
        content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Des titres décoratifs, posés où tu veux.', style: body(13, pal.soft)),
          const SizedBox(height: 8),
          for (final (label, font) in [('Écriture manuscrite', 'hand'), ('Titre', 'title')])
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(label, style: font == 'hand' ? hand(26, pal.ink) : titleFont(20, pal.ink)),
              trailing: const Icon(Icons.add_rounded),
              onTap: () async {
                final t = await askText(context, 'Ton texte', hint: 'Novembre ✨');
                if (t == null || t.isEmpty) return;
                await _place(store, desk, Deco(page: page, type: 'text', x: 300, y: 120, w: 260, h: 70, style: {'text': t, 'font': font, 'color': pal.acc.value}));
              },
            ),
        ]);
        break;
      case 4:
        final p = store.paper(page);
        content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          section('Couleur du papier'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in [0, ...paperColors])
              GestureDetector(
                onTap: () => store.setPaper(page, color: c),
                child: Container(
                  width: 44,
                  height: 44,
                  child: c == 0 ? Icon(Icons.auto_awesome, size: 16, color: pal.soft) : null,
                  decoration: BoxDecoration(color: c == 0 ? pal.paper : Color(c), borderRadius: BorderRadius.circular(10), border: Border.all(color: p.color == c ? pal.acc : pal.line, width: 3)),
                ),
              ),
          ]),
          section('Motif'),
          Wrap(spacing: 8, children: [
            for (final (k, n) in [('dots', 'Pointillé'), ('lines', 'Ligné'), ('grid', 'Quadrillé'), ('plain', 'Uni')])
              ChoiceChip(label: Text(n), selected: p.pattern == k, onSelected: (_) => store.setPaper(page, pattern: k)),
          ]),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () async {
              final kind = page.split(':').first;
              await store.setPaper('kind:$kind', color: p.color, pattern: p.pattern);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appliqué à toutes les pages de ce type')));
            },
            child: const Text('Utiliser pour toutes les pages de ce type'),
          ),
          section('Ma palette'),
          Text('Touche une couleur pour la changer. Elle sert pour le washi, les cadres, le stylo.', style: body(12, pal.soft)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < store.settings.palette.length; i++)
              GestureDetector(
                onTap: () async {
                  final c = await pickColor(context, store, title: 'Nouvelle couleur de palette');
                  if (c == null) return;
                  store.settings.palette[i] = c;
                  await store.touchSettings();
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: Color(store.settings.palette[i]), shape: BoxShape.circle, border: Border.all(color: pal.line, width: 2)),
                ),
              ),
          ]),
          section('Ambiance du carnet'),
          Wrap(spacing: 8, children: [
            for (final t in Pal.all)
              ChoiceChip(
                label: Text(t.name),
                selected: store.settings.theme == t.id,
                onSelected: (_) async {
                  store.settings.theme = t.id;
                  await store.setPaper('default', color: 0);
                  await store.touchSettings();
                },
              ),
          ]),
        ]);
        break;
      default:
        content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          section('Favoris'),
          if (store.favorites.isEmpty) Text('Sélectionne un élément posé et touche ♡ pour le garder ici.', style: body(13, pal.soft)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in store.favorites)
              GestureDetector(
                onTap: () async {
                  if (page.isEmpty) return;
                  await store.applyTemplate(f, page);
                },
                onLongPress: () => store.deleteTemplate(f),
                child: Container(
                  width: 80,
                  height: 64,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: pal.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: pal.line)),
                  child: FittedBox(child: SizedBox(width: 160, height: 120, child: Center(child: _mini(Deco.fromJson(f.items.first), store)))),
                ),
              ),
          ]),
          section('Modèles de page'),
          Text('Garde la déco d’une page pour la reposer ailleurs en un geste.', style: body(12, pal.soft)),
          const SizedBox(height: 6),
          for (final t in store.pageTemplates)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(t.name, style: body(14, pal.ink)),
              subtitle: Text('${t.items.length} éléments', style: body(11, pal.soft)),
              onTap: () => page.isEmpty ? null : store.applyTemplate(t, page),
              trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => store.deleteTemplate(t)),
            ),
          OutlinedButton.icon(
            onPressed: page.isEmpty
                ? null
                : () async {
                    final n = await askText(context, 'Nom du modèle', hint: 'Ma page de novembre');
                    if (n == null || n.isEmpty) return;
                    await store.saveTemplate(n, page);
                  },
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('Garder la déco de cette page'),
          ),
        ]);
    }

    return Material(
      color: pal.card,
      child: Column(children: [
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
            for (var i = 0; i < _tabs.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
                child: ChoiceChip(label: Text(_tabs[i]), selected: _tab == i, onSelected: (_) => setState(() => _tab = i)),
              ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 24), child: content)),
      ]),
    );
  }

  Widget _mini(Deco d, Store store) => Transform.rotate(angle: d.rot, child: SizedBox(width: d.w.clamp(10, 160), height: d.h.clamp(10, 120), child: renderDeco(d, store)));
}
