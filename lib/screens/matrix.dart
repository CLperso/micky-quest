import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'session.dart';

class MatrixScreen extends StatefulWidget {
  final bool standalone;
  const MatrixScreen({super.key, this.standalone = false});

  @override
  State<MatrixScreen> createState() => _MatrixScreenState();
}

class _MatrixScreenState extends State<MatrixScreen> {
  final _ctrl = TextEditingController();
  String? _selected;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    await AppScope.read(context).addTask(t);
    _ctrl.clear();
  }

  Future<void> _move(String id, String quad) async {
    final store = AppScope.read(context);
    final t = store.taskById(id);
    if (t == null) return;
    HapticFeedback.selectionClick();
    setState(() => _selected = null);
    await store.moveTask(t, quad);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final inbox = store.tasksIn(Quad.inbox);

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.standalone) Text('Tri des quêtes', style: K.display(24)),
          Text(
            _selected == null
                ? 'Appui long puis glisse une tâche dans sa case. Touche-la pour plus d\'options.'
                : 'Touche le titre d\'une case pour y ranger la tâche choisie.',
            style: K.body(13, color: _selected == null ? K.muted : K.gold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _add(),
            decoration: InputDecoration(
              hintText: 'Nouvelle tâche à trier',
              suffixIcon: IconButton(onPressed: _add, icon: const Icon(Icons.add_circle_rounded, color: K.lime)),
            ),
          ),
          const SizedBox(height: 8),
          _target(
            Quad.inbox,
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64, maxHeight: 150),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(Quad.inbox, '${Quad.titles[Quad.inbox]!.toUpperCase()} · ${inbox.length}', K.muted),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [for (final t in inbox) _chip(t, Quad.inbox)],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            const SizedBox(width: 22),
            Expanded(child: Center(child: Text('URGENT', style: K.body(11, color: K.muted, w: FontWeight.w900)))),
            Expanded(child: Center(child: Text('PAS URGENT', style: K.body(11, color: K.muted, w: FontWeight.w900)))),
          ]),
          const SizedBox(height: 4),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _row('IMPORTANT', Quad.doNow, Quad.plan)),
                const SizedBox(height: 6),
                Expanded(child: _row('PAS IMPORTANT', Quad.light, Quad.drop)),
              ],
            ),
          ),
        ],
      ),
    );

    if (!widget.standalone) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Tri des quêtes')),
      body: SafeArea(top: false, child: content),
    );
  }

  Widget _row(String label, String a, String b) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Center(
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(label, style: K.body(11, color: K.muted, w: FontWeight.w900)),
              ),
            ),
          ),
          Expanded(child: _quad(a)),
          const SizedBox(width: 6),
          Expanded(child: _quad(b)),
        ],
      );

  Widget _quad(String q) {
    final store = AppScope.of(context);
    final items = store.tasksIn(q);
    final c = K.quadColors[q]!;
    return _target(
      q,
      Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(q, Quad.titles[q]!, c),
            Text(Quad.hints[q]!, style: K.body(11, color: K.muted, w: FontWeight.w600)),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) => _chip(items[i], q),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String q, String title, Color c) => InkWell(
        onTap: _selected == null ? null : () => _move(_selected!, q),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(title, style: K.display(14, color: c, w: FontWeight.w700)),
        ),
      );

  Widget _target(String q, Widget child) {
    final c = K.quadColors[q]!;
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => _move(d.data, q),
      builder: (context, candidates, _) {
        final hot = candidates.isNotEmpty || _selected != null;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: K.quadBg[q],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: candidates.isNotEmpty ? K.ink : c.withValues(alpha: hot ? 1 : 0.7), width: candidates.isNotEmpty ? 3 : 2),
          ),
          child: child,
        );
      },
    );
  }

  Widget _chip(Task t, String q) {
    final c = K.quadColors[q]!;
    final sel = _selected == t.id;
    Widget box({bool dragging = false}) => Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? c : K.raised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: dragging ? K.ink : c, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (t.isBoss) ...[
                  const Icon(Icons.pest_control_rounded, size: 14, color: K.coral),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(t.title,
                      style: K.body(12, color: sel ? K.bg : K.ink, w: FontWeight.w800),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ),
                if (t.deferred) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.history_rounded, size: 14, color: K.coral),
                ],
              ],
            ),
          ),
        );
    return LongPressDraggable<String>(
      data: t.id,
      delay: const Duration(milliseconds: 180),
      hapticFeedbackOnStart: true,
      feedback: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: Opacity(opacity: 0.9, child: box(dragging: true)),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: box()),
      child: GestureDetector(
        onTap: () => _options(t),
        child: box(),
      ),
    );
  }

  Future<void> _options(Task t) async {
    final store = AppScope.read(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.title, style: K.display(18)),
              const SizedBox(height: 8),
              _opt(ctx, 'start', Icons.play_arrow_rounded, 'Lancer une session', K.lime),
              _opt(ctx, 'done', Icons.check_rounded, 'C\'est fait', K.lime),
              _opt(ctx, 'select', Icons.open_with_rounded, 'Ranger dans une case', K.cyan),
              _opt(ctx, 'boss', Icons.pest_control_rounded, t.isBoss ? 'Déjà boss de la semaine' : 'En faire le boss de la semaine', K.coral),
              _opt(ctx, 'tomorrow', Icons.wb_twilight_rounded, 'Reporter à demain', K.gold),
              _opt(ctx, 'delete', Icons.delete_outline_rounded, 'Effacer', K.dim),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'start':
        final ok = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (_) => AppScope(store: store, child: StartSessionSheet(preselect: t.id)),
        );
        if (ok == true && mounted) await openScreen(context, const SessionScreen());
        break;
      case 'done':
        await store.completeTask(t);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bien joué ! XP gagnée')));
        }
        break;
      case 'select':
        setState(() => _selected = t.id);
        break;
      case 'boss':
        await store.setBoss(t);
        break;
      case 'tomorrow':
        await store.deferTask(t);
        break;
      case 'delete':
        await store.removeTask(t);
        break;
    }
  }

  Widget _opt(BuildContext ctx, String id, IconData icon, String label, Color c) => ListTile(
        leading: Icon(icon, color: c),
        title: Text(label, style: K.body(15)),
        onTap: () => Navigator.pop(ctx, id),
      );
}
