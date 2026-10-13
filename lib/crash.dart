import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// Dernière erreur rencontrée, gardée pour pouvoir la lire dans l'appli.
String? lastCrash;
const _key = 'last_crash_v1';

Future<void> loadCrash() async {
  try {
    final p = await SharedPreferences.getInstance();
    lastCrash = p.getString(_key);
  } catch (_) {}
}

Future<void> recordCrash(Object error, StackTrace? stack) async {
  final text = '$error\n${stack ?? ''}';
  lastCrash = text.length > 2500 ? text.substring(0, 2500) : text;
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, lastCrash!);
  } catch (_) {}
}

Future<void> clearCrash() async {
  lastCrash = null;
  try {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  } catch (_) {}
}

/// Remplace un écran qui a planté par le message d'erreur, lisible et copiable.
Widget crashBox(FlutterErrorDetails d) {
  recordCrash(d.exception, d.stack);
  return Material(
    color: const Color(0xFF2A1630),
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Oups, cet écran a planté', style: K.display(20, color: K.coral)),
          const SizedBox(height: 8),
          Text('Fais une capture et envoie-la à Claude :', style: K.body(13, color: K.muted)),
          const SizedBox(height: 8),
          SelectableText(
            '${d.exceptionAsString()}\n\n${(d.stack ?? '').toString().split('\n').take(12).join('\n')}',
            style: const TextStyle(color: K.ink, fontSize: 12, fontFamily: 'monospace'),
          ),
        ],
      ),
    ),
  );
}

/// Bandeau sur le QG quand une erreur a été enregistrée.
class CrashBanner extends StatelessWidget {
  final VoidCallback onClear;
  const CrashBanner({super.key, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final c = lastCrash;
    if (c == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1630),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: K.coral, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Une erreur a été enregistrée', style: K.display(15, color: K.coral)),
          const SizedBox(height: 6),
          SelectableText(
            c.split('\n').take(14).join('\n'),
            style: const TextStyle(color: K.ink, fontSize: 11, fontFamily: 'monospace'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onClear, child: const Text('Effacer')),
          ),
        ],
      ),
    );
  }
}
