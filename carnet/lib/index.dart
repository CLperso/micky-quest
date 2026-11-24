import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'canvas.dart';
import 'model.dart';
import 'store.dart';
import 'theme.dart';

// =====================================================================
// La bande des pages, en bas : on glisse vers le passé ou la suite
// =====================================================================
class DayStrip extends StatefulWidget {
  final DateTime day;
  final String pagePrefix; // day, jrn, track
  final ValueChanged<DateTime> onPick;
  final VoidCallback onIndex;
  const DayStrip({super.key, required this.day, required this.pagePrefix, required this.onPick, required this.onIndex});
  @override
  State<DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<DayStrip> {
  static const back = 60, ahead = 30;
  static const itemW = 58.0;
  late final ScrollController _c;

  int _index(DateTime d) => d.difference(dateOnly(DateTime.now())).inDays + back;

  @override
  void initState() {
    super.initState();
    _c = ScrollController(initialScrollOffset: max(0, _index(widget.day) * itemW - 300));
  }

  @override
  void didUpdateWidget(DayStrip old) {
    super.didUpdateWidget(old);
    if (old.day != widget.day && _c.hasClients) {
      final w = _c.position.viewportDimension;
      final target = (_index(widget.day) * itemW - w / 2 + itemW / 2).clamp(0.0, _c.position.maxScrollExtent);
      _c.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = Pal.byId(store.settings.theme);
    final today = dateOnly(DateTime.now());
    return Row(children: [
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(
          avatar: Icon(Icons.menu_book_rounded, size: 18, color: pal.acc),
          label: Text('Index', style: body(12, pal.ink, w: FontWeight.w900)),
          backgroundColor: pal.card,
          side: BorderSide(color: pal.line),
          onPressed: widget.onIndex,
        ),
      ),
      Expanded(
        child: ListView.builder(
          controller: _c,
          scrollDirection: Axis.horizontal,
          itemCount: back + ahead + 1,
          itemExtent: itemW,
          itemBuilder: (context, i) {
            final d = today.add(Duration(days: i - back));
            final k = dayKey(d);
            final cur = dayKey(widget.day) == k;
            final isToday = k == dayKey(today);
            final strokes = (store.inks['${widget.pagePrefix}:$k:L']?.strokes.length ?? 0) + (store.inks['${widget.pagePrefix}:$k:R']?.strokes.length ?? 0);
            final lines = min(5, (strokes / 6).ceil() + (widget.pagePrefix == 'day' ? store.dayEntries(k).length : 0));
            return GestureDetector(
              onTap: () => widget.onPick(d),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: pal.paper,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: cur ? pal.acc : pal.line, width: cur ? 2.4 : 1),
                        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      padding: const EdgeInsets.fromLTRB(7, 9, 7, 4),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        for (var j = 0; j < lines; j++)
                          Container(
                            height: 2,
                            width: [32.0, 26.0, 30.0, 20.0, 28.0][j],
                            margin: const EdgeInsets.only(bottom: 6),
                            color: pal.ink.withValues(alpha: .28),
                          ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isToday ? 'auj.' : '${dayShort[d.weekday - 1].substring(0, 1).toUpperCase()} ${d.day}',
                    style: body(10, cur ? pal.acc : pal.soft, w: FontWeight.w900),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// =====================================================================
// L'index : tout ce qui est gardé, et la recherche
// =====================================================================
Future<void> showIndex(BuildContext context, {required void Function(String day) onOpenDay, required void Function(String pageId) onOpenPage}) async {
  final store = StoreScope.read(context);
  final pal = Pal.byId(store.settings.theme);
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: pal.paper,
    builder: (ctx) => StoreScope(store: store, child: _IndexSheet(onOpenDay: onOpenDay, onOpenPage: onOpenPage)),
  );
}

class _IndexSheet extends StatefulWidget {
  final void Function(String day) onOpenDay;
  final void Function(String pageId) onOpenPage;
  const _IndexSheet({required this.onOpenDay, required this.onOpenPage});
  @override
  State<_IndexSheet> createState() => _IndexSheetState();
}

class _IndexSheetState extends State<_IndexSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = Pal.byId(store.settings.theme);
    final q = _q.trim().toLowerCase();

    // jours qui ont quelque chose (encre, lignes, suivis)
    final days = <String>{};
    for (final k in store.inks.keys) {
      final p = k.split(':');
      if (p.length == 3 && p[0] == 'day' && (store.inks[k]?.strokes.isNotEmpty ?? false)) days.add(p[1]);
    }
    for (final e in store.entries.values) {
      if (!e.del && e.when.length == 10) days.add(e.when);
    }
    final today = dayKey(DateTime.now());
    final sorted = days.where((d) => d.compareTo(today) <= 0).toList()..sort((a, b) => b.compareTo(a));

    String dayText(String k) {
      final b = StringBuffer();
      for (final e in store.dayEntries(k)) {
        b.write('${e.text} ');
      }
      for (final side in ['L', 'R']) {
        b.write('${(store.inkText['day:$k:$side'] ?? '').replaceAll(RegExp(r'^\w+\|', multiLine: true), '')} ');
      }
      return b.toString();
    }

    final hits = <(String, String, VoidCallback)>[]; // (titre, extrait, ouvrir)
    if (q.isNotEmpty) {
      for (final k in sorted) {
        final t = dayText(k);
        final i = t.toLowerCase().indexOf(q);
        if (i >= 0) hits.add((niceDay(parseDay(k)), _around(t, i, q.length), () => widget.onOpenDay(k)));
      }
      for (final p in store.activeFree) {
        var t = p.title;
        for (var n = 1; n <= p.sheets; n++) {
          final key = n == 1 ? 'free:${p.id}' : 'free:${p.id}:$n';
          t += ' ${(store.inkText[key] ?? '').replaceAll(RegExp(r'^\w+\|', multiLine: true), '')}';
          for (final d in store.pageDecos(key).where((d) => d.type == 'text')) {
            t += ' ${d.style['text'] ?? ''}';
          }
        }
        final i = t.toLowerCase().indexOf(q);
        if (i >= 0) hits.add((p.title.isEmpty ? 'Sans titre' : p.title, _around(t, i, q.length), () => widget.onOpenPage(p.id)));
      }
    }

    // regroupés par mois
    final byMonth = <String, List<String>>{};
    for (final k in sorted) {
      byMonth.putIfAbsent(k.substring(0, 7), () => []).add(k);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .85,
      builder: (ctx, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(22, 16, 22, 30), children: [
        Text('Index', style: titleFont(34, pal.ink)),
        Text('Tout est gardé. Touche un jour ou une page pour y aller.', style: body(12, pal.soft, w: FontWeight.w700)),
        const SizedBox(height: 10),
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: kIsWeb ? 'chercher (ce qui est tapé, et l’écriture lue sur la tablette)' : 'chercher dans le carnet…',
            filled: true,
            fillColor: pal.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: pal.line)),
          ),
          onChanged: (v) => setState(() => _q = v),
        ),
        const SizedBox(height: 14),
        if (q.isNotEmpty) ...[
          if (hits.isEmpty) Text('Rien trouvé.', style: hand(22, pal.soft)),
          for (final (t, ex, go) in hits)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t, style: hand(21, pal.ink)),
              subtitle: Text(ex, style: body(12, pal.soft)),
              onTap: () {
                Navigator.pop(context);
                go();
              },
            ),
        ] else ...[
          Text('Mes pages', style: titleFont(24, pal.acc)),
          for (final p in store.activeFree) _row(pal, p.title.isEmpty ? 'Sans titre' : p.title, 'page${p.sheets > 1 ? ' · ${p.sheets} feuilles' : ''}', () => widget.onOpenPage(p.id)),
          const SizedBox(height: 14),
          for (final m in byMonth.entries) ...[
            Text(niceMonth(m.key), style: titleFont(24, pal.acc)),
            for (final k in m.value)
              _row(
                pal,
                niceDay(parseDay(k)),
                store.weekGoal(parseDay(k)).isNotEmpty && parseDay(k).weekday == 1 ? 'objectif : ${store.weekGoal(parseDay(k))}' : '',
                () => widget.onOpenDay(k),
              ),
            const SizedBox(height: 10),
          ],
        ],
      ]),
    );
  }

  Widget _row(Pal pal, String t, String sub, VoidCallback go) => InkWell(
        onTap: () {
          Navigator.pop(context);
          go();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(t, style: hand(20, pal.ink)),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, margin: const EdgeInsets.only(bottom: 6), color: pal.dot)),
            if (sub.isNotEmpty) ...[const SizedBox(width: 8), Flexible(child: Text(sub, overflow: TextOverflow.ellipsis, style: body(11, pal.soft, w: FontWeight.w700)))],
          ]),
        ),
      );

  static String _around(String t, int i, int n) {
    final a = max(0, i - 30), b = min(t.length, i + n + 50);
    return '${a > 0 ? '…' : ''}${t.substring(a, b).replaceAll('\n', ' ')}${b < t.length ? '…' : ''}';
  }
}

// =====================================================================
// Lire l'écriture à la main : les signes du bullet journal et le texte
// =====================================================================
class _Box {
  double x0 = double.infinity, y0 = double.infinity, x1 = -double.infinity, y1 = -double.infinity;
  void add(Stroke s) {
    for (var i = 0; i + 1 < s.pts.length; i += 3) {
      x0 = min(x0, s.pts[i]);
      x1 = max(x1, s.pts[i]);
      y0 = min(y0, s.pts[i + 1]);
      y1 = max(y1, s.pts[i + 1]);
    }
  }

  double get w => x1 - x0;
  double get h => y1 - y0;
}

/// Reconnaît le signe en tête de ligne : task, done, moved, event, note (ou null si la ligne commence par du texte).
(String?, int) _sign(List<Stroke> line) {
  if (line.isEmpty) return (null, 0);
  // les traits du début qui forment un petit groupe séparé du reste
  final first = _Box()..add(line.first);
  var n = 1;
  if (line.length > 1) {
    final b2 = _Box()..add(line[1]);
    final overlap = b2.x0 < first.x1 + 4 && b2.x1 < first.x0 + 34;
    if (overlap && first.w < 30 && b2.w < 30) {
      first.add(line[1]);
      n = 2;
    }
  }
  final size = max(first.w, first.h);
  if (size > 34) return (null, 0);
  final restStart = line.length > n ? (_Box()..add(line[n])).x0 : double.infinity;
  if (restStart - first.x1 < 4) return (null, 0); // collé au mot : c'est une lettre
  if (n == 2) return ('done', 2); // deux traits croisés : ×
  final s = line.first;
  if (size < 9) return ('task', 1); // un point
  if (first.h < first.w * .38) return ('note', 1); // un tiret
  final sx = s.pts[0], sy = s.pts[1], ex = s.pts[s.pts.length - 3], ey = s.pts[s.pts.length - 2];
  final closed = sqrt(pow(ex - sx, 2) + pow(ey - sy, 2)) < size * .45;
  if (closed) return ('event', 1); // un rond
  // un chevron > : départ et arrivée à gauche, pointe à droite
  if (first.x1 - max(sx, ex) > first.w * .5) return ('moved', 1);
  return ('task', 1);
}

/// Lit une page : chaque ligne devient (signe, texte). Android seulement (null sinon).
Future<List<(String, String)>?> readPage(Store store, String page) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  final ink = store.inks[page];
  if (ink == null || ink.strokes.isEmpty) {
    store.inkText.remove(page);
    return [];
  }
  final lines = groupLines(ink.strokes.where((s) => !s.hl && s.pts.length >= 3).toList(), gap: 20);
  final signs = <String>[];
  final rest = <List<Stroke>>[];
  for (final l in lines) {
    final (k, n) = _sign(l);
    signs.add(k ?? 'text');
    rest.add(l.sublist(min(n, l.length)));
  }
  final idx = [for (var i = 0; i < rest.length; i++) if (rest[i].isNotEmpty) i];
  final got = await recognizeLines([for (final i in idx) rest[i]]);
  if (got == null) return null;
  final texts = List.filled(rest.length, '');
  for (var j = 0; j < idx.length && j < got.length; j++) {
    texts[idx[j]] = got[j];
  }
  final out = <(String, String)>[];
  for (var i = 0; i < signs.length; i++) {
    final t = texts[i].trim();
    if (t.isEmpty && signs[i] == 'text') continue;
    out.add((signs[i], t));
  }
  store.inkText[page] = out.map((e) => '${e.$1}|${e.$2}').join('\n');
  return out;
}

/// Lecture en arrière-plan, quelques secondes après la dernière écriture (jamais le journal).
class InkReader {
  static final Map<String, Timer> _t = {};
  static void install() {
    Store.onInk = (store, page) {
      if (page.startsWith('jrn:') || !(page.startsWith('day:') || page.startsWith('free:') || page.startsWith('week:'))) return;
      _t[page]?.cancel();
      _t[page] = Timer(const Duration(seconds: 6), () async {
        _t.remove(page);
        try {
          await readPage(store, page);
        } catch (e) {
          debugPrint('Lecture : $e');
        }
      });
    };
  }

  /// Ce que Micky peut savoir de la page du jour, écrite à la main.
  static Future<String> todayForMicky(Store store) async {
    final k = dayKey(DateTime.now());
    final b = StringBuffer();
    for (final side in ['L', 'R']) {
      final page = 'day:$k:$side';
      try {
        await readPage(store, page).timeout(const Duration(seconds: 8));
      } catch (_) {}
      final t = store.inkText[page];
      if (t == null || t.trim().isEmpty) continue;
      for (final l in t.split('\n')) {
        final i = l.indexOf('|');
        if (i < 0) continue;
        final kind = l.substring(0, i), text = l.substring(i + 1);
        final label = const {'task': '• à faire', 'done': '× fait', 'moved': '> reporté', 'event': '○ rendez-vous', 'note': '– note'}[kind] ?? 'texte';
        b.writeln('- [$label] $text');
      }
    }
    return b.toString();
  }
}
