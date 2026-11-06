import 'package:carnet_micky/ink.dart';
import 'package:carnet_micky/main.dart';
import 'package:carnet_micky/model.dart';
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
    await tester.tap(find.byTooltip('Écrire et dessiner'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PenBar), findsOneWidget);
    await tester.tap(find.text('Couverture').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Pages').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Mon style'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Mon style'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  test('chaque pointe donne un contour', () {
    for (final n in nibs) {
      final s = Stroke(color: 0xFF000000, width: n.width, tool: n.id, pts: [0, 0, 0.5, 10, 10, 0.5, 20, 15, 0.5, 40, 30, 0.5, 60, 32, 0.5]);
      final b = strokeOutline(s).getBounds();
      expect(b.width, greaterThan(40), reason: n.id);
    }
    final dot = Stroke(color: 0xFF000000, width: 4, pts: [5, 5, 0.5]);
    expect(strokeOutline(dot).getBounds().width, greaterThan(1));
  });

  test('les formes donnent des points', () {
    for (final f in ['ligne', 'rect', 'ovale', 'fleche']) {
      expect(shapePoints(f, const Offset(0, 0), const Offset(50, 40)).first.length, greaterThan(3), reason: f);
    }
  });
}
