import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';

/// Image d'un objet, ou un pictogramme si l'illustration n'existe pas encore.
class ObjectImage extends StatelessWidget {
  final GameObject o;
  final double size;
  const ObjectImage(this.o, {super.key, this.size = 64});

  static const _icons = {
    'canape': Icons.weekend_rounded,
    'lampe': Icons.light_rounded,
    'lit': Icons.bed_rounded,
    'biblio': Icons.menu_book_rounded,
    'lunettes': Icons.visibility_rounded,
    'echarpe': Icons.checkroom_rounded,
  };

  @override
  Widget build(BuildContext context) {
    if (o.asset.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: K.raised, borderRadius: BorderRadius.circular(size / 5), border: Border.all(color: K.line, width: 2)),
        child: Icon(_icons[o.id] ?? Icons.category_rounded, color: K.gold, size: size * 0.55),
      );
    }
    return Image.asset(o.asset, width: size, height: size, fit: BoxFit.contain);
  }
}

Color rarityColor(int r) => r == 3 ? K.pink : r == 2 ? K.cyan : K.lime;

/// Montre le butin : la carte de l'objet s'il y en a un, sinon le coffre classique.
Future<void> showLoot(BuildContext context, AppStore store, String item) async {
  final id = store.lastObject;
  if (id.isNotEmpty && Objects.byId(id) != null) {
    store.lastObject = '';
    await openScreen(context, ObjectRevealScreen(object: Objects.byId(id)!, reason: item));
  } else {
    await showChest(context, item);
  }
}

/// Carte « nouvel objet ! », façon booster.
class ObjectRevealScreen extends StatefulWidget {
  final GameObject object;
  final String reason;
  const ObjectRevealScreen({super.key, required this.object, this.reason = ''});

  @override
  State<ObjectRevealScreen> createState() => _ObjectRevealScreenState();
}

class _ObjectRevealScreenState extends State<ObjectRevealScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final o = widget.object;
    final c = rarityColor(o.rarity);
    final owned = Objects.inSeries(o.series).where((x) => store.inventory.contains(x.id)).length;
    final total = Objects.inSeries(o.series).length;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -0.4), radius: 0.9, colors: [Color(0xFF3A2F5E), K.bg]),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
            children: [
              Center(child: Text(o.accessory ? 'NOUVEL ACCESSOIRE !' : 'NOUVEL OBJET !', style: K.body(12, color: K.gold, w: FontWeight.w900).copyWith(letterSpacing: 2))),
              const SizedBox(height: 4),
              Center(child: Text('Gagné avec : ${widget.reason.isEmpty ? 'un coffre' : widget.reason}', style: K.body(13, color: K.muted))),
              const SizedBox(height: 18),
              Center(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, child) {
                    final v = Curves.elasticOut.transform(_c.value);
                    return Transform.scale(scale: 0.6 + 0.4 * v, child: Transform.rotate(angle: (1 - _c.value) * 0.3, child: child));
                  },
                  child: Container(
                    width: 240,
                    height: 330,
                    decoration: BoxDecoration(
                      color: K.card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: c, width: 4),
                      boxShadow: [BoxShadow(color: c.withValues(alpha: 0.45), blurRadius: 40, spreadRadius: 4)],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                          child: Row(children: [
                            Text(o.rarityLabel, style: K.body(11, color: c, w: FontWeight.w900)),
                            const Spacer(),
                            Text('${Objects.seriesNames[o.series]} · $owned/$total', style: K.body(11, color: K.muted, w: FontWeight.w800)),
                          ]),
                        ),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: const RadialGradient(colors: [Color(0xFF3A2F5E), Color(0xFF2A2450)]),
                            ),
                            child: Center(child: ObjectImage(o, size: 170)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.name, style: K.display(20)),
                              Text(o.flavor, style: K.body(12, color: K.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                  child: PrimaryButton(
                    label: o.accessory ? 'L\'enfiler à Micky' : 'Poser chez Micky',
                    color: c,
                    onPressed: () async {
                      Navigator.pop(context);
                      final ctx = navKey.currentContext;
                      if (ctx != null) openScreen(ctx, HouseScreen(place: o.id));
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: SecondaryButton(label: 'Plus tard', onPressed: () => Navigator.pop(context))),
              ]),
              const SizedBox(height: 16),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text('Série « ${Objects.seriesNames[o.series]} »', style: K.display(15))),
                      Text('$owned / $total', style: K.body(12, color: K.gold, w: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 8),
                    SeriesRow(series: o.series, highlight: o.id),
                    const SizedBox(height: 6),
                    Text(
                      o.series == 'salon'
                          ? 'Série complète : la chambre s\'ouvre + 200 XP.'
                          : o.series == 'chambre'
                              ? 'Série complète : le jardin s\'ouvre + 200 XP.'
                              : 'Série complète : titre « Styliste de Micky » + 200 XP.',
                      style: K.body(12, color: K.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Les cases d'une série : possédé (image) ou vide (pointillés).
class SeriesRow extends StatelessWidget {
  final String series;
  final String highlight;
  const SeriesRow({super.key, required this.series, this.highlight = ''});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final list = Objects.inSeries(series);
    return Row(
      children: [
        for (final o in list)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: store.inventory.contains(o.id) ? K.raised : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: highlight == o.id ? K.ink : (store.inventory.contains(o.id) ? K.raised : K.line),
                    width: 2,
                    style: store.inventory.contains(o.id) ? BorderStyle.solid : BorderStyle.solid,
                  ),
                ),
                child: store.inventory.contains(o.id) ? Center(child: ObjectImage(o, size: 36)) : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// Album : toutes les séries, objets possédés ou à gagner.
class AlbumScreen extends StatelessWidget {
  const AlbumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Album')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            Text('${store.ownedObjects.length}/${Objects.all.length} objets · ${store.jokers} joker${store.jokers > 1 ? 's' : ''} de série', style: K.body(13, color: K.muted)),
            for (final s in Objects.seriesOrder) ...[
              SectionLabel(Objects.seriesNames[s]!),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.78,
                children: [
                  for (final o in Objects.inSeries(s))
                    Builder(builder: (context) {
                      final owned = store.inventory.contains(o.id);
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: owned ? () => openScreen(context, ObjectRevealScreen(object: o, reason: 'déjà à toi')) : null,
                        child: Container(
                          decoration: BoxDecoration(
                            color: owned ? K.card : const Color(0xFF1C1736),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: owned ? rarityColor(o.rarity) : K.line, width: 2),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              owned
                                  ? ObjectImage(o, size: 52)
                                  : const Icon(Icons.help_outline_rounded, color: K.dim, size: 36),
                              const SizedBox(height: 4),
                              Text(owned ? o.name : '???', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: K.body(10, color: owned ? K.ink : K.muted, w: FontWeight.w800)),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ],
            if (store.inventory.any((i) => Objects.byId(i) == null)) ...[
              const SectionLabel('Anciens trésors'),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final i in store.inventory.where((i) => Objects.byId(i) == null)) Pill(i, color: K.gold)]),
            ],
          ],
        ),
      ),
    );
  }
}

/// La maison de Micky : petit monde isométrique, objets à déplacer sur la grille.
class HouseScreen extends StatefulWidget {
  final String? place; // objet à poser en arrivant
  const HouseScreen({super.key, this.place});

  @override
  State<HouseScreen> createState() => _HouseScreenState();
}

class _HouseScreenState extends State<HouseScreen> {
  String _room = 'salon';
  String? _dragging;
  Offset? _dragPos;
  static const n = 5; // grille n × n
  static const cw = 64.0; // largeur d'une case à l'écran
  static const ch = 32.0;

  @override
  void initState() {
    super.initState();
    final o = widget.place == null ? null : Objects.byId(widget.place!);
    if (o != null) {
      _room = o.accessory ? 'micky' : (o.series == 'chambre' ? 'chambre' : 'salon');
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoPlace(o));
    }
  }

  Future<void> _autoPlace(GameObject o) async {
    final store = AppScope.read(context);
    if (o.accessory) {
      await store.placeObject(o.id, 'micky', 0, 0);
      return;
    }
    // première case libre
    for (var gy = n - 1; gy >= 0; gy--) {
      for (var gx = 0; gx < n; gx++) {
        if (!store.placements.any((p) => p.room == _room && p.gx == gx && p.gy == gy)) {
          await store.placeObject(o.id, _room, gx, gy);
          return;
        }
      }
    }
  }

  Offset _cell(int gx, int gy, Size size) {
    final cx = size.width / 2;
    final cy = 120.0;
    return Offset(cx + (gx - gy) * cw / 2, cy + (gx + gy) * ch / 2);
  }

  (int, int)? _hit(Offset p, Size size) {
    final cx = size.width / 2;
    const cy = 120.0;
    final dx = p.dx - cx, dy = p.dy - cy;
    final gx = (dx / cw + dy / ch);
    final gy = (dy / ch - dx / cw);
    final x = gx.floor(), y = gy.floor();
    if (x < 0 || y < 0 || x >= n || y >= n) return null;
    return (x, y);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final chambreOpen = store.seriesComplete('salon') || store.placements.any((p) => p.room == 'chambre');
    final placed = store.placements.where((p) => p.room == _room && Objects.byId(p.id) != null).toList()
      ..sort((a, b) => (a.gx + a.gy).compareTo(b.gx + b.gy));
    final inventory = store.unplacedObjects.where((o) => _room == 'micky' ? o.accessory : !o.accessory).toList();
    final worn = store.worn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chez Micky'),
        actions: [
          TextButton(onPressed: () => openScreen(context, const AlbumScreen()), child: const Text('Album')),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
          children: [
            Row(
              children: [
                for (final r in ['salon', 'chambre', 'micky'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(r == 'micky' ? 'Micky' : r == 'chambre' && !chambreOpen ? 'Chambre 🔒' : Objects.seriesNames[r]!),
                      selected: _room == r,
                      onSelected: (r == 'chambre' && !chambreOpen) ? null : (_) => setState(() => _room = r),
                      selectedColor: K.gold,
                      labelStyle: K.body(13, color: _room == r ? K.bg : K.ink),
                      backgroundColor: K.raised,
                      side: BorderSide.none,
                      showCheckmark: false,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_room == 'micky')
              _mickyView(store, worn)
            else
              LayoutBuilder(builder: (context, c) {
                final size = Size(c.maxWidth, 360);
                return GestureDetector(
                  onPanStart: (d) {
                    // objet sous le doigt ?
                    for (final p in placed.reversed) {
                      final o = Objects.byId(p.id)!;
                      final at = _cell(p.gx, p.gy, size);
                      final rect = Rect.fromCenter(center: at.translate(0, o.wall ? -70 : -26), width: 64, height: 70);
                      if (rect.contains(d.localPosition)) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _dragging = p.id;
                          _dragPos = d.localPosition;
                        });
                        return;
                      }
                    }
                  },
                  onPanUpdate: (d) {
                    if (_dragging != null) setState(() => _dragPos = d.localPosition);
                  },
                  onPanEnd: (_) async {
                    if (_dragging == null || _dragPos == null) return;
                    final cell = _hit(_dragPos!, size);
                    final id = _dragging!;
                    setState(() {
                      _dragging = null;
                      _dragPos = null;
                    });
                    if (cell != null) await store.placeObject(id, _room, cell.$1, cell.$2);
                  },
                  onTapUp: (d) async {
                    final cell = _hit(d.localPosition, size);
                    if (cell == null) return;
                    final occupied = placed.any((p) => p.gx == cell.$1 && p.gy == cell.$2);
                    if (occupied) {
                      final p = placed.firstWhere((p) => p.gx == cell.$1 && p.gy == cell.$2);
                      _objectMenu(store, Objects.byId(p.id)!);
                    } else if (inventory.isNotEmpty) {
                      final o = await _pickFromInventory(inventory);
                      if (o != null) await store.placeObject(o.id, _room, cell.$1, cell.$2);
                    }
                  },
                  child: Container(
                    height: size.height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: const RadialGradient(center: Alignment(0, -0.3), radius: 0.9, colors: [K.raised, K.bg]),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Stack(
                        children: [
                          Positioned.fill(child: CustomPaint(painter: _RoomPainter(_room, _cell, size, highlight: _dragging == null || _dragPos == null ? null : _hit(_dragPos!, size)))),
                          for (final p in placed)
                            if (p.id != _dragging)
                              _objectAt(Objects.byId(p.id)!, _cell(p.gx, p.gy, size)),
                          // Micky : à côté de son lit/panier (jamais par-dessus un objet), sinon près du centre
                          Builder(builder: (_) {
                            bool free(int x, int y) => x >= 0 && y >= 0 && x < 5 && y < 5 && !placed.any((p) => p.gx == x && p.gy == y);
                            final bed = placed.where((p) => p.id == 'panier' || p.id == 'lit').toList();
                            final (bx, by) = bed.isEmpty ? (2, 2) : (bed.first.gx, bed.first.gy);
                            (int, int)? spot;
                            for (var d = bed.isEmpty ? 0 : 1; d <= 4 && spot == null; d++) {
                              for (final (dx, dy) in [(d, 0), (0, d), (-d, 0), (0, -d), (d, d), (-d, d), (d, -d), (-d, -d)]) {
                                if (free(bx + dx, by + dy)) {
                                  spot = (bx + dx, by + dy);
                                  break;
                                }
                              }
                            }
                            final at = _cell((spot ?? (bx, by)).$1, (spot ?? (bx, by)).$2, size);
                            return Positioned(
                              left: at.dx - 21,
                              top: at.dy - 46,
                              child: IgnorePointer(child: _mickyMedallion(worn, 42)),
                            );
                          }),
                          if (_dragging != null && _dragPos != null)
                            Positioned(
                              left: _dragPos!.dx - 36,
                              top: _dragPos!.dy - 80,
                              child: Opacity(opacity: 0.9, child: ObjectImage(Objects.byId(_dragging!)!, size: 72)),
                            ),
                          Positioned(
                            left: 12,
                            bottom: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: K.bg.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(999)),
                              child: Text(
                                placed.isEmpty ? 'Touche une case pour poser un objet' : 'Glisse un objet pour le déplacer · touche-le pour les options',
                                style: K.body(11, color: K.lime, w: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 12),
            Text(_room == 'micky' ? 'Accessoires à enfiler' : 'Inventaire · à poser', style: K.display(15, color: K.gold)),
            const SizedBox(height: 6),
            if (inventory.isEmpty)
              Text(
                _room == 'micky' ? 'Gagne des accessoires dans les coffres.' : 'Tout est posé. Les prochains coffres (paris tenus, feu de camp, coffre géant) t\'en donneront d\'autres.',
                style: K.body(12, color: K.muted),
              )
            else
              SizedBox(
                height: 92,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final o in inventory)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            if (o.accessory) {
                              await store.placeObject(o.id, 'micky', 0, 0);
                            } else {
                              await _autoPlace(o);
                            }
                          },
                          child: Container(
                            width: 84,
                            decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: rarityColor(o.rarity), width: 2)),
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ObjectImage(o, size: 44),
                                const SizedBox(height: 4),
                                Text(o.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: K.body(10, w: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            for (final s in ['salon', 'chambre', 'micky'])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  SizedBox(width: 110, child: Text(Objects.seriesNames[s]!, style: K.body(12, color: K.muted))),
                  Expanded(child: SeriesRow(series: s)),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mickyMedallion(List<GameObject> worn, double size) => SizedBox(
        width: size + 20,
        height: size + 20,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: K.gold, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 6))],
                  image: DecorationImage(image: AssetImage(K.micky['face'] ?? K.micky['happy']!), fit: BoxFit.cover),
                ),
              ),
            ),
            for (final o in worn)
              if (o.id == 'couronne')
                Positioned(left: size / 2 - 8, top: -6, child: ObjectImage(o, size: size * 0.75))
              else if (o.id == 'noeud')
                Positioned(left: size / 2 - 4, top: size - 2, child: ObjectImage(o, size: size * 0.6))
              else
                Positioned(right: -4, bottom: -4, child: ObjectImage(o, size: size * 0.5)),
          ],
        ),
      );

  Widget _mickyView(AppStore store, List<GameObject> worn) => Container(
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const RadialGradient(center: Alignment(0, -0.2), radius: 0.9, colors: [K.raised, K.bg]),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _mickyMedallion(worn, 150),
            const SizedBox(height: 12),
            Text(worn.isEmpty ? 'Micky au naturel' : 'Micky porte : ${worn.map((o) => o.name.toLowerCase()).join(', ')}', style: K.body(13, color: K.muted)),
            if (worn.isNotEmpty)
              TextButton(
                onPressed: () async {
                  for (final o in worn) {
                    await store.unplaceObject(o.id);
                  }
                },
                child: const Text('Tout enlever'),
              ),
          ],
        ),
      );

  Widget _objectAt(GameObject o, Offset at) {
    final size = o.wall ? 76.0 : 72.0;
    return Positioned(
      left: at.dx - size / 2,
      top: at.dy - (o.wall ? size + 20 : size - 12),
      child: IgnorePointer(child: ObjectImage(o, size: size)),
    );
  }

  Future<GameObject?> _pickFromInventory(List<GameObject> inv) => showModalBottomSheet<GameObject>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in inv)
                  InkWell(
                    onTap: () => Navigator.pop(ctx, o),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [ObjectImage(o, size: 56), Text(o.name, style: K.body(11))]),
                  ),
              ],
            ),
          ),
        ),
      );

  Future<void> _objectMenu(AppStore store, GameObject o) async {
    final a = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: ObjectImage(o, size: 36), title: Text(o.name, style: K.display(16)), subtitle: Text(o.flavor, style: K.body(12, color: K.muted))),
            ListTile(leading: const Icon(Icons.inventory_2_outlined, color: K.gold), title: const Text('Remettre dans l\'inventaire'), onTap: () => Navigator.pop(ctx, 'unplace')),
            if (o.series == 'salon' || o.series == 'chambre')
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded, color: K.cyan),
                title: Text(_room == 'salon' ? 'Déplacer dans la chambre' : 'Déplacer dans le salon'),
                onTap: () => Navigator.pop(ctx, 'swap'),
              ),
          ],
        ),
      ),
    );
    if (a == 'unplace') await store.unplaceObject(o.id);
    if (a == 'swap') {
      final p = store.placementOf(o.id);
      if (p != null) await store.placeObject(o.id, _room == 'salon' ? 'chambre' : 'salon', p.gx, p.gy);
    }
  }
}

class _RoomPainter extends CustomPainter {
  final String room;
  final Offset Function(int, int, Size) cell;
  final Size size;
  final (int, int)? highlight;
  _RoomPainter(this.room, this.cell, this.size, {this.highlight});

  @override
  void paint(Canvas canvas, Size s) {
    const n = _HouseScreenState.n;
    final a = cell(0, 0, size), b = cell(n, 0, size), c = cell(n, n, size), d = cell(0, n, size);
    final wallH = 120.0;
    // murs
    canvas.drawPath(
      Path()..moveTo(a.dx, a.dy)..lineTo(d.dx, d.dy)..lineTo(d.dx, d.dy - wallH)..lineTo(a.dx, a.dy - wallH)..close(),
      Paint()..color = room == 'chambre' ? const Color(0xFF4A2E5E) : const Color(0xFF3B3270),
    );
    canvas.drawPath(
      Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy)..lineTo(b.dx, b.dy - wallH)..lineTo(a.dx, a.dy - wallH)..close(),
      Paint()..color = room == 'chambre' ? const Color(0xFF5E3A78) : const Color(0xFF4A3F8A),
    );
    // fenêtre sur le mur gauche
    final w1 = cell(0, 2, size), w2 = cell(0, 4, size);
    canvas.drawPath(
      Path()..moveTo(w1.dx, w1.dy - 100)..lineTo(w2.dx, w2.dy - 100)..lineTo(w2.dx, w2.dy - 50)..lineTo(w1.dx, w1.dy - 50)..close(),
      Paint()..color = const Color(0xFF16263A),
    );
    canvas.drawPath(
      Path()..moveTo(w1.dx, w1.dy - 100)..lineTo(w2.dx, w2.dy - 100)..lineTo(w2.dx, w2.dy - 50)..lineTo(w1.dx, w1.dy - 50)..close(),
      Paint()..color = K.gold..style = PaintingStyle.stroke..strokeWidth = 3,
    );
    canvas.drawCircle(Offset((w1.dx + w2.dx) / 2 + 8, (w1.dy + w2.dy) / 2 - 84), 6, Paint()..color = K.gold);
    // sol
    canvas.drawPath(
      Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy)..lineTo(c.dx, c.dy)..lineTo(d.dx, d.dy)..close(),
      Paint()..color = room == 'chambre' ? const Color(0xFF6E5A8A) : const Color(0xFF8A6A4E),
    );
    final grid = Paint()..color = Colors.black.withValues(alpha: 0.18)..strokeWidth = 1;
    for (var i = 0; i <= n; i++) {
      final p1 = cell(i, 0, size), p2 = cell(i, n, size);
      canvas.drawLine(p1, p2, grid);
      final q1 = cell(0, i, size), q2 = cell(n, i, size);
      canvas.drawLine(q1, q2, grid);
    }
    if (highlight != null) {
      final (gx, gy) = highlight!;
      final p = Path()
        ..moveTo(cell(gx, gy, size).dx, cell(gx, gy, size).dy)
        ..lineTo(cell(gx + 1, gy, size).dx, cell(gx + 1, gy, size).dy)
        ..lineTo(cell(gx + 1, gy + 1, size).dx, cell(gx + 1, gy + 1, size).dy)
        ..lineTo(cell(gx, gy + 1, size).dx, cell(gx, gy + 1, size).dy)
        ..close();
      canvas.drawPath(p, Paint()..color = K.lime.withValues(alpha: 0.35));
      canvas.drawPath(p, Paint()..color = K.lime..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _RoomPainter old) => old.room != room || old.highlight != highlight;
}

/// Calendrier des médailles : un mois, bronze / argent / or / couronne, et le détail d'un jour.
class MedalCalendar extends StatefulWidget {
  const MedalCalendar({super.key});

  @override
  State<MedalCalendar> createState() => _MedalCalendarState();
}

class _MedalCalendarState extends State<MedalCalendar> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String? _sel;

  static const _names = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
  static const colors = [K.line, Color(0xFFC98A5B), Color(0xFFC9C4E8), Color(0xFFF2C14E), K.gold];

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final first = _month;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = first.weekday - 1;
    final today = store.todayKey;
    final counts = List.filled(5, 0);
    final medals = <String, int>{};
    for (var d = 1; d <= days; d++) {
      final k = dayKey(DateTime(_month.year, _month.month, d));
      if (k.compareTo(today) > 0) continue;
      final m = store.medalOn(k);
      medals[k] = m;
      counts[m]++;
    }
    final sel = _sel ?? today;
    final g = store.gainsOn(sel);
    final p = store.plan(sel);
    final sm = store.medalOn(sel);
    final sd = parseDay(sel);
    const wd = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('${_names[_month.month - 1][0].toUpperCase()}${_names[_month.month - 1].substring(1)} ${_month.year}', style: K.display(16))),
            IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)), icon: const Icon(Icons.chevron_left_rounded, color: K.muted)),
            IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)), icon: const Icon(Icons.chevron_right_rounded, color: K.muted)),
          ]),
          Row(children: [
            for (final i in [4, 3, 2, 1]) ...[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(color: K.bg, borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    Text('${counts[i]}', style: K.display(18, color: colors[i], w: FontWeight.w700)),
                    Text(['', 'bronze', 'argent', 'or', 'couronnes'][i], style: K.body(10, color: K.muted)),
                  ]),
                ),
              ),
              if (i != 1) const SizedBox(width: 6),
            ],
          ]),
          const SizedBox(height: 8),
          Row(children: [for (final l in ['L', 'M', 'M', 'J', 'V', 'S', 'D']) Expanded(child: Center(child: Text(l, style: K.body(10, color: K.muted, w: FontWeight.w800))))]),
          const SizedBox(height: 4),
          for (var row = 0; row < ((offset + days + 6) ~/ 7); row++)
            Row(children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: Builder(builder: (_) {
                    final d = row * 7 + col - offset + 1;
                    if (d < 1 || d > days) return const SizedBox(height: 46);
                    final k = dayKey(DateTime(_month.year, _month.month, d));
                    final m = medals[k];
                    final isSel = k == sel;
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: m == null ? null : () => setState(() => _sel = k),
                      child: Container(
                        height: 46,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: m == null ? const Color(0xFF1C1736) : K.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSel ? K.lime : (k == today ? K.gold : Colors.transparent), width: 2),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$d', style: K.body(9, color: K.muted, w: FontWeight.w800)),
                            if (m == 4)
                              const Padding(padding: EdgeInsets.only(bottom: 3), child: Icon(Icons.workspace_premium_rounded, color: K.gold, size: 20))
                            else if (m != null && m > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: colors[m], boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 2)]),
                                ),
                              )
                            else
                              const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
            ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: K.bg, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(sm == 4 ? Icons.workspace_premium_rounded : Icons.military_tech_rounded, color: colors[sm], size: 22),
                  const SizedBox(width: 6),
                  Expanded(child: Text('${wd[sd.weekday - 1]} ${sd.day}${sm == 0 ? '' : ' · ${sm == 4 ? 'journée parfaite' : AppStore.medalNames[sm].toLowerCase()}'}', style: K.body(14, w: FontWeight.w800))),
                  Text('+${g.xp} XP', style: K.display(14, color: K.gold)),
                ]),
                const SizedBox(height: 4),
                Text(
                  [
                    '${store.proMinutesOn(sel).round()} min de pro${p.proGoalMin > 0 ? ' / ${p.proGoalMin} visées' : ''}',
                    if (p.persoGoal.isNotEmpty) 'perso : ${p.persoGoal}${p.persoGoalDone ? ' ✓' : ''}',
                    ...g.byReason.entries.take(4).map((e) => '${e.key} +${e.value}'),
                    ...g.loot,
                  ].join(' · '),
                  style: K.body(12, color: K.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text('Bronze : 1 h de pro · Argent : objectif pro · Or : pro et perso · Couronne : tout, habitudes comprises.', style: K.body(11, color: K.muted)),
        ],
      ),
    );
  }
}

/// Carte « Chez Micky » pour le QG et l'onglet Moi : aperçu + boutons.
class HouseCard extends StatelessWidget {
  const HouseCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final n = store.ownedObjects.length;
    final toPlace = store.unplacedObjects.length;
    return Panel(
      border: toPlace > 0 ? K.gold : null,
      child: InkWell(
        onTap: () => openScreen(context, const HouseScreen()),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                children: [
                  for (var i = 0; i < min(3, store.ownedObjects.length); i++)
                    Positioned(left: i * 14.0, top: i * 6.0, child: ObjectImage(store.ownedObjects[store.ownedObjects.length - 1 - i], size: 44)),
                  if (store.ownedObjects.isEmpty) const Icon(Icons.home_rounded, color: K.gold, size: 44),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chez Micky', style: K.display(16)),
                  Text(
                    toPlace > 0
                        ? '$toPlace objet${toPlace > 1 ? 's' : ''} à poser !'
                        : '$n/${Objects.all.length} objets · ${store.worn.isEmpty ? 'Micky au naturel' : 'Micky porte ${store.worn.first.name.toLowerCase()}'}',
                    style: K.body(12, color: toPlace > 0 ? K.gold : K.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: K.muted),
          ],
        ),
      ),
    );
  }
}
