import 'package:flutter/material.dart';

import 'canvas.dart';
import 'model.dart';
import 'store.dart';
import 'theme.dart';

Pal palOf(BuildContext c) => Pal.byId(StoreScope.of(c).settings.theme);

/// Titre de page.
class PageTitle extends StatelessWidget {
  final String over;
  final String title;
  final Widget? trailing;
  const PageTitle({super.key, this.over = '', required this.title, this.trailing});
  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (over.isNotEmpty) Text(over.toUpperCase(), style: body(11, pal.soft, w: FontWeight.w800).copyWith(letterSpacing: 1.5)),
          Text(title, style: titleFont(32, pal.ink)),
        ]),
      ),
      if (trailing != null) trailing!,
    ]);
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
    return TextField(
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
    );
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
    return InkWell(
      onTap: () => entryMenu(context, e),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
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
              child: Text.rich(TextSpan(children: [
                TextSpan(
                  text: e.text,
                  style: body(16, faded ? pal.soft : pal.ink, w: e.kind == 'note' ? FontWeight.w600 : FontWeight.w700).copyWith(
                    decoration: e.dropped ? TextDecoration.lineThrough : null,
                    fontStyle: e.kind == 'note' ? FontStyle.italic : null,
                  ),
                ),
                if (goal != null) TextSpan(text: '  ${goal.emoji}', style: body(13, pal.soft)),
                if (coll != null && showWhen) TextSpan(text: '  ${coll.emoji}', style: body(13, pal.soft)),
                if (showWhen && e.when.isNotEmpty) TextSpan(text: '  · ${whenLabel(e.when)}', style: body(12, pal.soft)),
              ])),
            ),
          ),
        ]),
      ),
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
            ReorderableDelayedDragStartListener(key: ValueKey(shown[i].id), index: i, child: BulletRow(e: shown[i], showWhen: showWhen)),
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
    return Row(children: [
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

/// Ligne de tracker : nom à gauche, contrôle à droite.
class TrackRow extends StatelessWidget {
  final String name;
  final Widget child;
  final String? note;
  const TrackRow(this.name, this.child, {super.key, this.note});
  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 128, child: Text(name, style: body(14, pal.ink, w: FontWeight.w800))),
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
