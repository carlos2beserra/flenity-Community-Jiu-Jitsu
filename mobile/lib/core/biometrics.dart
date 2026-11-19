import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Digital / Face ID do aparelho. Abstraída para que telas e sessão possam ser testadas.
abstract class BiometricAuth {
  /// O aparelho tem biometria cadastrada e disponível para o app.
  Future<bool> isAvailable();

  /// Pede a biometria. `false` quando o usuário cancela ou falha.
  Future<bool> authenticate(String reason);
}

class DeviceBiometricAuth implements BiometricAuth {
  DeviceBiometricAuth([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (error) {
      debugPrint('Biometria indisponível: $error');
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true, persistAcrossBackgrounding: true);
    } catch (error) {
      debugPrint('Falha na biometria: $error');
      return false;
    }
  }
}

/// Usada quando não há biometria (web, testes, aparelhos sem sensor).
class UnavailableBiometricAuth implements BiometricAuth {
  const UnavailableBiometricAuth();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;
}
