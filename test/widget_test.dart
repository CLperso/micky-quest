import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micky_quest/main.dart';
import 'package:micky_quest/screens/discoveries.dart';
import 'package:micky_quest/screens/evening.dart';
import 'package:micky_quest/screens/home.dart';
import 'package:micky_quest/screens/matrix.dart';
import 'package:micky_quest/store.dart';
import 'package:micky_quest/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final s = AppStore();
  await s.load();
  return s;
}

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> check(WidgetTester tester, Widget page, String name) async {
  final store = await freshStore();
  await tester.pumpWidget(AppScope(
    store: store,
    child: MaterialApp(theme: K.theme(), home: Scaffold(body: page)),
  ));
  await tester.pump(const Duration(milliseconds: 100));
  final e = tester.takeException();
  expect(e, isNull, reason: '$name a planté : $e');
}

void main() {
  testWidgets('QG', (t) async {
    phone(t);
    await check(t, HomeScreen(onGoTo: (_) {}), 'QG');
    expect(find.text('Quêtes du jour'), findsOneWidget);
  });
  testWidgets('Matrice', (t) async {
    phone(t);
    await check(t, const MatrixScreen(), 'Matrice');
  });
  testWidgets('Découvertes', (t) async {
    phone(t);
    await check(t, const DiscoveriesScreen(), 'Découvertes');
  });
  testWidgets('Soir', (t) async {
    phone(t);
    await check(t, const EveningTab(), 'Soir');
  });
  testWidgets('Application complète', (t) async {
    phone(t);
    final store = await freshStore();
    await t.pumpWidget(AppScope(store: store, child: const MickyQuestApp()));
    await t.pump(const Duration(milliseconds: 300));
    final e = t.takeException();
    expect(e, isNull, reason: 'Shell a planté : $e');
    expect(find.text('Quêtes du jour'), findsOneWidget);
    for (final tab in ['Quêtes', 'Découvertes', 'Soir', 'QG']) {
      await t.tap(find.text(tab));
      await t.pump(const Duration(milliseconds: 300));
      final e2 = t.takeException();
      expect(e2, isNull, reason: 'Onglet $tab a planté : $e2');
    }
  });
}
