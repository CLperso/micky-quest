import 'package:carnet_micky/main.dart';
import 'package:carnet_micky/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('le carnet s’ouvre et on peut noter une ligne', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    final store = Store();
    await tester.runAsync(() => store.load());
    final a = await store.addEntry('Faire mes vaccins', when: '2026-11');
    expect(store.monthEntries('2026-11').any((e) => e.id == a.id), isTrue);
    await tester.pumpWidget(StoreScope(store: store, child: const CarnetApp()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Shell), findsOneWidget);
    expect(find.text('Semaine'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
