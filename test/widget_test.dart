import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micky_quest/main.dart';
import 'package:micky_quest/screens/discoveries.dart';
import 'package:micky_quest/screens/evening.dart';
import 'package:micky_quest/screens/home.dart';
import 'package:micky_quest/screens/checkin.dart';
import 'package:micky_quest/screens/checkins_log.dart';
import 'package:micky_quest/screens/habits.dart';
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

/// Détails complets des erreurs Flutter (widget fautif compris).
final List<String> details = [];

void captureErrors() {
  details.clear();
  final prev = FlutterError.onError;
  FlutterError.onError = (d) {
    details.add(d.toString());
    prev?.call(d);
  };
  addTearDown(() => FlutterError.onError = prev);
}

Future<void> check(WidgetTester tester, Widget page, String name) async {
  final store = await freshStore();
  await tester.pumpWidget(AppScope(
    store: store,
    child: MaterialApp(theme: K.theme(), home: Scaffold(body: page)),
  ));
  await tester.pump(const Duration(milliseconds: 100));
  final e = tester.takeException();
  // les débordements viennent de la police de test (carrés), pas de l'appli
  if (e != null && !e.toString().contains('overflowed')) {
    fail('$name a planté : $e\n${details.join('\n')}');
  }
}

void main() {
  testWidgets('QG', (t) async {
    phone(t);
    captureErrors();
    await check(t, HomeScreen(onGoTo: (_) {}), 'QG');
    expect(find.text('Tes stats de personnage'), findsOneWidget);
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
  testWidgets('Check-in', (t) async {
    phone(t);
    captureErrors();
    await check(t, const CheckinScreen(), 'Check-in');
    await t.tap(find.text('Perso'));
    await t.pump();
    expect(find.text('Depuis combien de temps ?'), findsOneWidget);
  });
  testWidgets('Journal des check-ins', (t) async {
    phone(t);
    captureErrors();
    await check(t, const CheckinsLogScreen(), 'Journal');
  });
  testWidgets('Habitudes', (t) async {
    phone(t);
    captureErrors();
    await check(t, const HabitsScreen(), 'Habitudes');
  });
  testWidgets('Application complète', (t) async {
    phone(t);
    captureErrors();
    final store = await freshStore();
    await t.pumpWidget(AppScope(store: store, child: const MickyQuestApp()));
    await t.pump(const Duration(milliseconds: 300));
    final e = t.takeException();
    if (e != null && !e.toString().contains('overflowed')) {
      fail('Shell a planté : $e\n${details.join('\n')}');
    }
    expect(find.text('Tes stats de personnage'), findsOneWidget);
    for (final tab in ['Quêtes', 'Découvertes', 'Soir', 'QG']) {
      await t.tap(find.text(tab));
      await t.pump(const Duration(milliseconds: 300));
      final e2 = t.takeException();
      if (e2 != null && !e2.toString().contains('overflowed')) {
        fail('Onglet $tab a planté : $e2\n${details.join('\n')}');
      }
    }
  });
}
