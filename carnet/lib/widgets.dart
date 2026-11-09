import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'canvas.dart';
import 'model.dart';
import 'store.dart';
import 'theme.dart';

Pal palOf(BuildContext c) => Pal.byId(StoreScope.of(c).settings.theme);

/// Remplace {jour} {n} {mois} {annee} {semaine}… par leur valeur.
String fillVars(String t, Map<String, String> vars) => t.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => vars[m[1]] ?? m[0]!);

Map<String, String> dayVars(DateTime d) => {
      'jour': cap(dayNames[d.weekday - 1]),
      'n': '${d.day}',
      'mois': monthNames[d.month - 1],
      'Mois': cap(monthNames[d.month - 1]),
      'annee': '${d.year}',
    };

bool _editable(BuildContext context) => DeskScope.of(context).mode == Mode.use;

/// Modifier un ou plusieurs textes de la page ; vide = caché. Possibilité de masquer toute la partie.
Future<void> editTexts(BuildContext context, List<(String id, String name, String def)> items, {String? part, Map<String, String> vars = const {}}) async {
  final store = StoreScope.read(context);
  final ctrls = [for (final it in items) TextEditingController(text: store.text(it.$1, it.$3))];
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Personnaliser'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(controller: ctrls[i], autofocus: i == 0, decoration: InputDecoration(labelText: items[i].$2, helperText: i == items.length - 1 ? 'Laisse vide pour cacher le texte.' : null)),
            ),
          if (vars.isNotEmpty)
            Text('À glisser dans le texte : ${vars.keys.map((k) => '{$k}').join('  ')}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, 'reset'), child: const Text('Par défaut')),
        if (part != null) TextButton(onPressed: () => Navigator.pop(ctx, 'hide'), child: const Text('Masquer cette partie')),
        FilledButton(onPressed: () => Navigator.pop(ctx, 'ok'), child: const Text('OK')),
      ],
    ),
  );
  if (r == null) return;
  for (var i = 0; i < items.length; i++) {
    final id = items[i].$1;
    if (r == 'reset' || ctrls[i].text == items[i].$3) {
      store.settings.labels.remove(id);
    } else if (r == 'ok') {
      store.settings.labels[id] = ctrls[i].text;
    }
  }
  if (r == 'hide' && part != null && !store.settings.hidden.contains(part)) store.settings.hidden.add(part);
  await store.touchSettings();
}

/// Une partie de page qu'on peut masquer (et retrouver dans « Mon style »).
class Part extends StatelessWidget {
  final String id;
  final Widget child;
  const Part(this.id, this.child, {super.key});
  @override
  Widget build(BuildContext context) => StoreScope.of(context).isHidden(id) ? const SizedBox.shrink() : child;
}

/// Petit titre de rubrique, modifiable d'un toucher.
class ELabel extends StatelessWidget {
  final String id, def;
  final String? part;
  final Map<String, String> vars;
  const ELabel(this.id, this.def, {super.key, this.part, this.vars = const {}});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = fillVars(store.text(id, def), vars);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _editable(context) ? () => editTexts(context, [(id, 'Texte', def)], part: part, vars: vars) : null,
      child: t.isEmpty ? const SizedBox(height: 14) : Label(t, palOf(context).soft),
    );
  }
}

/// Titre de page. Avec un [id], le titre et le sous-titre se modifient d'un toucher.
class PageTitle extends StatelessWidget {
  final String over;
  final String title;
  final Widget? trailing;
  final String? id;
  final Map<String, String> vars;
  const PageTitle({super.key, this.over = '', required this.title, this.trailing, this.id, this.vars = const {}});
  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    final store = StoreScope.of(context);
    final o = id == null ? over : fillVars(store.text('$id.over', over), vars);
    final t = id == null ? title : fillVars(store.text('$id.title', title), vars);
    final w = Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (o.isNotEmpty) Text(o.toUpperCase(), style: body(11, pal.soft, w: FontWeight.w800).copyWith(letterSpacing: 2)),
          if (t.isNotEmpty) Text(t, style: titleFont(32, pal.ink)),
          if (t.isEmpty && o.isEmpty) const SizedBox(height: 20),
        ]),
      ),
      if (trailing != null) trailing!,
    ]);
    if (id == null) return w;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _editable(context) ? () => editTexts(context, [('$id.over', 'Petit titre', over), ('$id.title', 'Titre', title)], vars: vars) : null,
      child: w,
    );
  }
}

/// Champ libre au style manuscrit, sauvegardé à chaque frappe.
class HandField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String hint;
  final double size;
  final Color? color;
  final int maxLines;
  final bool handwriting;
  const HandField({super.key, required this.value, required this.onChanged, this.hint = '', this.size = 26, this.color, this.maxLines = 3, this.handwriting = true});
  @override
  State<HandField> createState() => _HandFieldState();
}

class _HandFieldState extends State<HandField> {
  late final TextEditingController _c = TextEditingController(text: widget.value);
  final _f = FocusNode();

  @override
  void didUpdateWidget(HandField old) {
    super.didUpdateWidget(old);
    if (!_f.hasFocus && _c.text != widget.value) _c.text = widget.value;
  }

  @override
  void dispose() {
    _c.dispose();
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    final st = widget.handwriting ? hand(widget.size, widget.color ?? pal.ink) : body(widget.size, widget.color ?? pal.ink, w: FontWeight.w600);
    if (DeskScope.of(context).textEraser && !_f.hasFocus) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: _c.text.isEmpty
            ? Text(widget.hint, style: st.copyWith(color: pal.soft.withValues(alpha: 0.6)))
            : ScrubText(
                text: _c.text,
                style: st,
                maxLines: widget.maxLines,
                onErased: (t) {
                  setState(() => _c.text = t);
                  widget.onChanged(t);
                },
              ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      TextField(
      controller: _c,
      focusNode: _f,
      minLines: 1,
      maxLines: widget.maxLines,
      style: st,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: widget.hint,
        hintStyle: st.copyWith(color: pal.soft.withValues(alpha: 0.6)),
        contentPadding: const EdgeInsets.symmetric(vertical: 2),
      ),
      onChanged: widget.onChanged,
      ),
      EditTools(c: _c, f: _f, onChanged: () => widget.onChanged(_c.text)),
    ]);
  }
}

/// Efface le mot juste avant le curseur.
void deleteWord(TextEditingController c) {
  final sel = c.selection;
  final end = sel.isValid ? sel.end : c.text.length;
  final start = sel.isValid && !sel.isCollapsed ? sel.start : null;
  if (start != null) {
    c.value = TextEditingValue(text: c.text.replaceRange(start, end, ''), selection: TextSelection.collapsed(offset: start));
    return;
  }
  final before = c.text.substring(0, end).trimRight();
  final i = before.lastIndexOf(RegExp(r'\s'));
  final cut = i < 0 ? 0 : i + 1;
  c.value = TextEditingValue(text: c.text.substring(0, cut) + c.text.substring(end), selection: TextSelection.collapsed(offset: cut));
}

/// Petits boutons sous un champ en cours d'écriture : effacer un mot, tout effacer, supprimer la ligne, OK.
class EditTools extends StatelessWidget {
  final TextEditingController c;
  final FocusNode f;
  final VoidCallback? onDeleteLine;
  final VoidCallback? onChanged;
  const EditTools({super.key, required this.c, required this.f, this.onDeleteLine, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    Widget b(IconData i, String label, VoidCallback onTap, {Color? color}) => Padding(
          padding: const EdgeInsets.only(right: 6, top: 2),
          child: Material(
            color: pal.tint,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              canRequestFocus: false,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(i, size: 16, color: color ?? pal.ink),
                  const SizedBox(width: 4),
                  Text(label, style: body(12, color ?? pal.ink, w: FontWeight.w800)),
                ]),
              ),
            ),
          ),
        );
    return ListenableBuilder(
      listenable: f,
      builder: (context, _) => !f.hasFocus
          ? const SizedBox.shrink()
          : TextFieldTapRegion(
              child: Wrap(children: [
                b(Icons.backspace_outlined, 'mot', () {
                  deleteWord(c);
                  onChanged?.call();
                }),
                b(Icons.clear_rounded, 'tout effacer', () {
                  c.clear();
                  onChanged?.call();
                }),
                if (onDeleteLine != null) b(Icons.delete_outline_rounded, 'supprimer la ligne', onDeleteLine!, color: pal.acc),
                b(Icons.check_rounded, 'OK', () => f.unfocus(), color: pal.acc2),
              ]),
            ),
    );
  }
}

/// Un texte qu'on gomme mot par mot en frottant dessus au stylet
/// (gomme à texte activée, ou bouton du S Pen appuyé).
class ScrubText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final List<InlineSpan> extra;
  final int? maxLines;
  final ValueChanged<String> onErased;
  final VoidCallback? onTap;
  const ScrubText({super.key, required this.text, required this.style, required this.onErased, this.extra = const [], this.maxLines, this.onTap});
  @override
  State<ScrubText> createState() => _ScrubTextState();
}

class _ScrubTextState extends State<ScrubText> {
  final Set<int> _gone = {}; // débuts des mots gommés
  final List<TextRange> _ranges = [];
  bool _active = false;

  bool _wants(PointerEvent e) {
    final desk = DeskScope.of(context);
    final stylusButton = (e.kind == PointerDeviceKind.stylus || e.kind == PointerDeviceKind.invertedStylus) && (e.buttons & kPrimaryStylusButton) != 0;
    return desk.textEraser || stylusButton || e.kind == PointerDeviceKind.invertedStylus;
  }

  void _hit(Offset p, double width) {
    if (widget.text.isEmpty) return;
    final tp = TextPainter(text: TextSpan(text: widget.text, style: widget.style), textDirection: TextDirection.ltr, maxLines: widget.maxLines)..layout(maxWidth: width);
    if (p.dy > tp.height + 6 || p.dx > tp.width + 6) return;
    final pos = tp.getPositionForOffset(p);
    final r = tp.getWordBoundary(pos);
    if (r.isCollapsed || r.start < 0 || r.end > widget.text.length) return;
    if (widget.text.substring(r.start, r.end).trim().isEmpty) return;
    if (_gone.add(r.start)) setState(() => _ranges.add(r));
  }

  void _finish() {
    if (!_active) return;
    _active = false;
    if (_ranges.isEmpty) return;
    var t = widget.text;
    final l = [..._ranges]..sort((a, b) => b.start.compareTo(a.start));
    for (final r in l) {
      t = t.replaceRange(r.start, r.end, '');
    }
    t = t.replaceAll(RegExp(r'[ \t]{2,}'), ' ').replaceAll(RegExp(r' +([,.;:!?])'), r'$1').trim();
    setState(() {
      _gone.clear();
      _ranges.clear();
    });
    widget.onErased(t);
  }

  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    final spans = <InlineSpan>[];
    if (_ranges.isEmpty) {
      spans.add(TextSpan(text: widget.text, style: widget.style));
    } else {
      final l = [..._ranges]..sort((a, b) => a.start.compareTo(b.start));
      var i = 0;
      for (final r in l) {
        if (r.start > i) spans.add(TextSpan(text: widget.text.substring(i, r.start), style: widget.style));
        spans.add(TextSpan(
            text: widget.text.substring(r.start, r.end),
            style: widget.style.copyWith(color: pal.acc.withValues(alpha: 0.45), decoration: TextDecoration.lineThrough, decorationColor: pal.acc)));
        i = r.end;
      }
      if (i < widget.text.length) spans.add(TextSpan(text: widget.text.substring(i), style: widget.style));
    }
    return LayoutBuilder(builder: (context, box) {
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          if (!_wants(e)) return;
          _active = true;
          _hit(e.localPosition, box.maxWidth);
        },
        onPointerMove: (e) {
          if (_active) _hit(e.localPosition, box.maxWidth);
        },
        onPointerUp: (_) => _finish(),
        onPointerCancel: (_) => _finish(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: DeskScope.of(context).textEraser ? null : widget.onTap,
          child: Text.rich(TextSpan(children: [...spans, ...widget.extra]), maxLines: widget.maxLines),
        ),
      );
    });
  }
}

/// Supprimer une ligne, avec « Annuler ».
Future<void> deleteWithUndo(BuildContext context, Entry e) async {
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  await store.deleteEntry(e);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(SnackBar(
    content: Text('« ${e.text} » supprimée'),
    action: SnackBarAction(
      label: 'Annuler',
      onPressed: () {
        e.del = false;
        store.updateEntry(e);
      },
    ),
  ));
}

/// Le texte d'une ligne : un toucher et on l'écrit / le corrige sur place.
class EntryText extends StatefulWidget {
  final Entry e;
  final TextStyle style;
  final List<InlineSpan> extra;
  const EntryText({super.key, required this.e, required this.style, this.extra = const []});
  @override
  State<EntryText> createState() => _EntryTextState();
}

class _EntryTextState extends State<EntryText> {
  bool _edit = false;
  late final TextEditingController _c = TextEditingController(text: widget.e.text);
  final _f = FocusNode();

  @override
  void initState() {
    super.initState();
    _f.addListener(() {
      if (!_f.hasFocus && _edit) _save();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _f.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = StoreScope.read(context);
    final t = _c.text.trim();
    setState(() => _edit = false);
    if (t.isEmpty) {
      await deleteWithUndo(context, widget.e);
    } else if (t != widget.e.text) {
      widget.e.text = t;
      await store.updateEntry(widget.e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_edit) {
      return ScrubText(
        text: widget.e.text,
        style: widget.style,
        extra: widget.extra,
        onTap: () {
          _c.text = widget.e.text;
          _c.selection = TextSelection.collapsed(offset: _c.text.length);
          setState(() => _edit = true);
          WidgetsBinding.instance.addPostFrameCallback((_) => _f.requestFocus());
        },
        onErased: (t) async {
          if (t.isEmpty) {
            await deleteWithUndo(context, widget.e);
          } else {
            widget.e.text = t;
            await StoreScope.read(context).updateEntry(widget.e);
          }
        },
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _c,
        focusNode: _f,
        style: widget.style.copyWith(decoration: TextDecoration.none),
        minLines: 1,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 2)),
        onSubmitted: (_) => _f.unfocus(),
      ),
      EditTools(
        c: _c,
        f: _f,
        onDeleteLine: () {
          _c.clear();
          _f.unfocus();
        },
      ),
    ]);
  }
}

/// Une ligne de bullet journal.
class BulletRow extends StatelessWidget {
  final Entry e;
  final bool showWhen;
  const BulletRow({super.key, required this.e, this.showWhen = false});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final goal = e.goal.isEmpty ? null : store.goals[e.goal];
    final coll = e.coll.isEmpty ? null : store.colls[e.coll];
    final faded = e.done || e.dropped;
    final symCol = e.kind == 'event' ? pal.acc2 : (e.kind == 'note' ? pal.soft : pal.acc);
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: e.kind == 'task' ? () => store.toggleDone(e) : null,
            child: SizedBox(
              width: 30,
              height: 26,
              child: Center(
                child: e.kind == 'task'
                    ? Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: e.done ? symCol : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: symCol, width: 2),
                        ),
                        child: e.done ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                      )
                    : Text(e.symbol, style: body(18, symCol, w: FontWeight.w900)),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: EntryText(
                key: ValueKey('t${e.id}'),
                e: e,
                style: body(16, faded ? pal.soft : pal.ink, w: e.kind == 'note' ? FontWeight.w600 : FontWeight.w700).copyWith(
                  decoration: e.dropped ? TextDecoration.lineThrough : null,
                  fontStyle: e.kind == 'note' ? FontStyle.italic : null,
                ),
                extra: [
                  if (goal != null) TextSpan(text: '  ${goal.emoji}', style: body(13, pal.soft)),
                  if (coll != null && showWhen) TextSpan(text: '  ${coll.emoji}', style: body(13, pal.soft)),
                  if (showWhen && e.when.isNotEmpty) TextSpan(text: '  · ${whenLabel(e.when)}', style: body(12, pal.soft)),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => entryMenu(context, e),
            child: SizedBox(width: 28, height: 26, child: Icon(Icons.more_horiz_rounded, size: 18, color: pal.soft.withValues(alpha: .7))),
          ),
        ]),
      );
  }
}

String whenLabel(String w) {
  if (w == 'someday') return 'un jour';
  if (w.length == 7) return niceMonth(w).toLowerCase();
  if (w.length == 10) {
    final d = parseDay(w);
    final t = dateOnly(DateTime.now());
    final diff = d.difference(t).inDays;
    if (diff == 0) return 'aujourd’hui';
    if (diff == 1) return 'demain';
    if (diff == -1) return 'hier';
    return '${dayNames[d.weekday - 1].substring(0, 3)} ${d.day}/${d.month}';
  }
  return '';
}

/// Liste de lignes, réordonnable, avec une ligne d'ajout.
class BulletList extends StatelessWidget {
  final List<Entry> items;
  final Future<void> Function(String text, String kind) onAdd;
  final bool showWhen;
  final String hint;
  final bool hideDone;
  const BulletList({super.key, required this.items, required this.onAdd, this.showWhen = false, this.hint = 'écrire une ligne…', this.hideDone = false});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final shown = hideDone ? items.where((e) => !e.done && !e.dropped).toList() : items;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        proxyDecorator: (child, _, __) => Material(color: Colors.transparent, child: child),
        onReorder: (a, b) => store.reorder(shown, a, b > a ? b - 1 : b),
        children: [
          for (var i = 0; i < shown.length; i++)
            ReorderableDelayedDragStartListener(
              key: ValueKey(shown[i].id),
              index: i,
              child: Dismissible(
                key: ValueKey('d${shown[i].id}'),
                direction: DeskScope.of(context).textEraser ? DismissDirection.none : DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(Icons.delete_outline_rounded, color: palOf(context).acc),
                ),
                onDismissed: (_) => deleteWithUndo(context, shown[i]),
                child: BulletRow(e: shown[i], showWhen: showWhen),
              ),
            ),
        ],
      ),
      AddLine(onAdd: onAdd, hint: hint),
    ]);
  }
}

/// « + écrire une ligne » : • tâche par défaut, « o » rendez-vous, « - » note.
class AddLine extends StatefulWidget {
  final Future<void> Function(String text, String kind) onAdd;
  final String hint;
  const AddLine({super.key, required this.onAdd, this.hint = 'écrire une ligne…'});
  @override
  State<AddLine> createState() => _AddLineState();
}

class _AddLineState extends State<AddLine> {
  final _c = TextEditingController();
  final _f = FocusNode();
  String _kind = 'task';

  @override
  void dispose() {
    _c.dispose();
    _f.dispose();
    super.dispose();
  }

  Future<void> _submit(String v) async {
    var t = v.trim();
    var k = _kind;
    if (t.startsWith('o ') || t.startsWith('○ ')) {
      k = 'event';
      t = t.substring(2).trim();
    } else if (t.startsWith('- ') || t.startsWith('– ')) {
      k = 'note';
      t = t.substring(2).trim();
    } else if (t.startsWith('* ') || t.startsWith('• ')) {
      k = 'task';
      t = t.substring(2).trim();
    }
    if (t.isEmpty) return;
    _c.clear();
    await widget.onAdd(t, k);
    _f.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    final sym = _kind == 'event' ? '○' : (_kind == 'note' ? '–' : '+');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
      GestureDetector(
        onTap: () => setState(() => _kind = _kind == 'task' ? 'event' : (_kind == 'event' ? 'note' : 'task')),
        child: SizedBox(width: 30, height: 30, child: Center(child: Text(sym, style: body(20, pal.acc, w: FontWeight.w900)))),
      ),
      Expanded(
        child: TextField(
          controller: _c,
          focusNode: _f,
          style: body(16, pal.ink),
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: _kind == 'event' ? 'un rendez-vous…' : (_kind == 'note' ? 'une note, une idée…' : widget.hint),
            hintStyle: body(16, pal.soft.withValues(alpha: 0.6), w: FontWeight.w600),
          ),
          onSubmitted: _submit,
        ),
      ),
      ]),
      Padding(padding: const EdgeInsets.only(left: 30), child: EditTools(c: _c, f: _f)),
    ]);
  }
}


/// Le menu d'une ligne : la changer de place, de type, la relier.
Future<void> entryMenu(BuildContext context, Entry e) async {
  final store = StoreScope.read(context);
  final now = DateTime.now();
  final today = dayKey(now);
  final tomorrow = dayKey(now.add(const Duration(days: 1)));
  final pal = Pal.byId(store.settings.theme);
  final months = [for (var i = 0; i < 7; i++) monthKey(DateTime(now.year, now.month + i, 1))];
  final r = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      Widget chip(String label, String v, {bool on = false}) => Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 6),
            child: ChoiceChip(label: Text(label), selected: on, onSelected: (_) => Navigator.pop(ctx, v)),
          );
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 16, 20, 16), children: [
            Text(e.text, style: titleFont(20, pal.ink)),
            const SizedBox(height: 10),
            Wrap(children: [
              if (e.kind == 'task') chip(e.done ? 'Pas encore faite' : 'Faite ✓', 'done'),
              chip('Modifier', 'edit'),
              chip('• Tâche', 'k:task', on: e.kind == 'task'),
              chip('○ Rendez-vous', 'k:event', on: e.kind == 'event'),
              chip('– Note', 'k:note', on: e.kind == 'note'),
            ]),
            Label('Quand ?', pal.soft),
            Wrap(children: [
              chip('Aujourd’hui', 'w:$today', on: e.when == today),
              chip('Demain', 'w:$tomorrow', on: e.when == tomorrow),
              chip('Un jour précis…', 'pick'),
              for (final m in months) chip(niceMonth(m), 'w:$m', on: e.when == m),
              chip('Un jour / bientôt', 'w:someday', on: e.isSomeday),
              if (e.coll.isNotEmpty) chip('Seulement dans la collection', 'w:', on: e.when.isEmpty),
            ]),
            Label('Collection', pal.soft),
            Wrap(children: [
              for (final c in store.activeColls) chip('${c.emoji} ${c.title}', 'c:${c.id}', on: e.coll == c.id),
              if (e.coll.isNotEmpty) chip('Aucune', 'c:'),
            ]),
            Label('Vers un objectif', pal.soft),
            Wrap(children: [
              for (final g in store.activeGoals) chip('${g.emoji} ${g.title}', 'g:${g.id}', on: e.goal == g.id),
              if (e.goal.isNotEmpty) chip('Aucun', 'g:'),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              TextButton.icon(onPressed: () => Navigator.pop(ctx, 'drop'), icon: const Icon(Icons.do_not_disturb_alt_rounded), label: const Text('Laisser tomber')),
              const Spacer(),
              TextButton.icon(onPressed: () => Navigator.pop(ctx, 'del'), icon: const Icon(Icons.delete_outline_rounded), label: const Text('Supprimer')),
            ]),
          ]),
        ),
      );
    },
  );
  if (r == null || !context.mounted) return;
  if (r == 'done') return store.toggleDone(e);
  if (r == 'drop') return store.dropEntry(e);
  if (r == 'del') return store.deleteEntry(e);
  if (r == 'edit') {
    final t = await askText(context, 'Modifier', initial: e.text);
    if (t == null || t.isEmpty) return;
    e.text = t;
    return store.updateEntry(e);
  }
  if (r == 'pick') {
    final d = await showDatePicker(context: context, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 3), initialDate: now);
    if (d == null) return;
    return store.moveEntry(e, dayKey(d));
  }
  if (r.startsWith('w:')) return store.moveEntry(e, r.substring(2));
  if (r.startsWith('k:')) {
    e.kind = r.substring(2);
    return store.updateEntry(e);
  }
  if (r.startsWith('c:')) {
    e.coll = r.substring(2);
    return store.updateEntry(e);
  }
  if (r.startsWith('g:')) {
    e.goal = r.substring(2);
    return store.updateEntry(e);
  }
}

/// Ligne de tracker : nom à gauche, contrôle à droite. Avec un [id], le nom se renomme et la ligne se masque.
class TrackRow extends StatelessWidget {
  final String name;
  final Widget child;
  final String? note;
  final String? id;
  const TrackRow(this.name, this.child, {super.key, this.note, this.id});
  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    final store = StoreScope.of(context);
    if (id != null && store.isHidden(id!)) return const SizedBox.shrink();
    final n = id == null ? name : store.text(id!, name);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 128,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: id != null && _editable(context) ? () => editTexts(context, [(id!, 'Nom', name)], part: id) : null,
            child: Text(n, style: body(14, pal.ink, w: FontWeight.w800)),
          ),
        ),
        Expanded(child: child),
        if (note != null) Text(note!, style: hand(20, pal.soft)),
      ]),
    );
  }
}

class Faces extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const Faces({super.key, required this.value, required this.onChanged});
  static const faces = ['😣', '😕', '😐', '🙂', '😄'];
  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            onTap: () => onChanged(value == i ? 0 : i),
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Opacity(opacity: value == i ? 1 : 0.28, child: Text(faces[i - 1], style: const TextStyle(fontSize: 26))),
            ),
          ),
      ]);
}

class Dots extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final Color color;
  final int n;
  const Dots({super.key, required this.value, required this.onChanged, required this.color, this.n = 5});
  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 1; i <= n; i++)
          GestureDetector(
            onTap: () => onChanged(value == i ? i - 1 : i),
            child: Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(shape: BoxShape.circle, color: i <= value ? color : Colors.transparent, border: Border.all(color: color, width: 2)),
            ),
          ),
      ]);
}

class CheckBoxy extends StatelessWidget {
  final bool on;
  final VoidCallback onTap;
  final Color color;
  const CheckBoxy({super.key, required this.on, required this.onTap, required this.color});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: on ? color : Colors.transparent, borderRadius: BorderRadius.circular(7), border: Border.all(color: color, width: 2)),
          child: on ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
        ),
      );
}

/// Petite pastille de bilan.
class Tile extends StatelessWidget {
  final String value, label;
  final Color color;
  const Tile(this.value, this.label, this.color, {super.key});
  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.45), width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: titleFont(20, pal.ink)),
        Text(label, style: body(11, pal.soft, w: FontWeight.w800)),
      ]),
    );
  }
}
