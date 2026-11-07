import 'package:flutter/material.dart';

import '../model.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Le futur : les mois à venir, et « un jour / bientôt ».
class FuturePage extends StatelessWidget {
  final int fromOffset; // 1 = le mois prochain
  final int count;
  final bool withSomeday;
  const FuturePage({super.key, required this.fromOffset, required this.count, this.withSomeday = false});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pal = palOf(context);
    final now = DateTime.now();
    final months = [for (var i = 0; i < count; i++) monthKey(DateTime(now.year, now.month + fromOffset + i, 1))];
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (fromOffset == 1) ...[
          const PageTitle(id: 'future', title: 'Futur'),
        ],
        for (final m in months) ...[
          const SizedBox(height: 10),
          Text(cap(niceMonth(m)), style: titleFont(26, pal.acc)),
          BulletList(items: store.monthEntries(m), onAdd: (t, k) async => store.addEntry(t, when: m, kind: k), hint: '+'),
        ],
        if (withSomeday) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => editTexts(context, [('future.someday', 'Titre', 'Un jour')]),
            child: Text(store.text('future.someday', 'Un jour'), style: hand(32, pal.acc2)),
          ),
          BulletList(items: store.somedayEntries(), onAdd: (t, k) async => store.addEntry(t, when: 'someday', kind: k), hint: '+'),
        ],
      ]),
    );
  }
}
