import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Déverrouiller avec l'empreinte (Android). null = indisponible ici.
Future<bool?> biometricUnlock() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    final auth = LocalAuthentication();
    if (!await auth.isDeviceSupported()) return null;
    if (!await auth.canCheckBiometrics) return null;
    return await auth.authenticate(localizedReason: 'Ouvrir mon journal', options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true));
  } catch (e) {
    debugPrint('Empreinte : $e');
    return null;
  }
}
