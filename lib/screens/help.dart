import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'block.dart';
import 'cabin.dart';
import 'problems.dart';
import 'timetable.dart' show askText;

/// « Un coup de main ? » : une seule porte d'entrée, trois situations. Chaque écran suivant fait une seule chose.
class HelpScreen extends StatelessWidget {
  final Task? task;
  const HelpScreen({super.key, this.task});

  static const _lav = Color(0xFFB9A7FF);

  Widget _tile(BuildContext context, String icon, String title, String sub, Color c, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: K.card,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: c, width: 2)),
              child: Row(children: [
                Text(icon, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: K.display(17)),
                    Text(sub, style: K.body(12, color: K.muted)),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: c),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final open = store.openProblems;
    return Scaffold(
      appBar: AppBar(title: const Text('Un coup de main ?')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            MickySays('Qu\'est-ce qui se passe, là ?', pose: 'window', ring: _lav),
            const SizedBox(height: 12),
            _tile(context, '🧱', 'Je n\'arrive pas à m\'y mettre', 'découper · relancer la machine · en parler', K.coral,
                () => openScreen(context, BlockScreen(task: task))),
            _tile(context, '🫧', 'Je me sens mal', 'souffler · regarder ce qui pèse · un geste', _lav, () => openScreen(context, const CabinScreen())),
            _tile(context, '🧩', 'J\'ai un problème concret', 'le poser, le résoudre, le suivre', K.lime, () async {
              final v = await askText(context, 'Le problème, concrètement', hint: 'un fait, pas un jugement sur toi');
              if (v == null || v.trim().isEmpty || !context.mounted) return;
              final p = await store.addProblem(v.trim());
              if (context.mounted) openScreen(context, ProblemScreen(problem: p, guided: true));
            }),
            if (open.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('EN COURS', style: K.body(11, color: K.muted, w: FontWeight.w900).copyWith(letterSpacing: 1)),
              const SizedBox(height: 6),
              for (final p in open.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: K.card,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => openScreen(context, ProblemScreen(problem: p)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(children: [
                          Container(width: 4, height: 24, decoration: BoxDecoration(color: problemColor(p), borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 10),
                          Expanded(child: Text(p.title, style: K.body(14, w: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          if (p.current != null)
                            Text(
                              '${p.current}/10${p.first != null && p.current! < p.first! ? ' ↓' : (p.first != null && p.current! > p.first! ? ' ↑' : '')}',
                              style: K.body(12, color: K.muted, w: FontWeight.w800),
                            ),
                        ]),
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => openScreen(context, const ProblemsScreen()),
                child: Text('Tous mes problèmes ›', style: K.body(13, color: K.lime, w: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La carte du QG : une question, une porte.
class HelpCard extends StatelessWidget {
  const HelpCard({super.key});

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF241E48),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => openScreen(context, const HelpScreen()),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: HelpScreen._lav, width: 2)),
            child: Row(children: [
              const Text('🤝', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Un coup de main ?', style: K.display(16)),
                  Text('je n\'y arrive pas · je me sens mal · un problème', style: K.body(11, color: K.muted)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: HelpScreen._lav),
            ]),
          ),
        ),
      );
}
