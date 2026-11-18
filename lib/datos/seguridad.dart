import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';

import '../modelos/dueno.dart';

/// Lo que puede pasar al pedir la huella.
enum ResultadoBiometria { exito, cancelado, noDisponible, bloqueado, error }

/// PIN y huella del dueno.
///
/// El PIN nunca se guarda tal cual. Se guarda su hash: una "huella digital" del
/// numero que se puede comparar, pero de la que no se puede sacar el numero de
/// vuelta. Es lo mismo que hace un banco con tu contrasena: si alguien copiara
/// la base, no sabria tu PIN.
class Seguridad {
  Seguridad._();

  /// Si la cuenta ya se desbloqueo en esta ejecucion de la app.
  ///
  /// Es static y no se guarda en la base a proposito: vive solo mientras la
  /// app esta abierta. Al cerrarla y volver a abrirla empieza en false, y por
  /// eso se vuelve a pedir el PIN o la huella cada vez que se abre.
  static bool sesionAbierta = false;

  static final _auth = LocalAuthentication();

  // ─────────────────────────────────────────────────────────────────────────
  // PIN
  // ─────────────────────────────────────────────────────────────────────────

  /// Convierte el PIN en algo seguro de guardar.
  ///
  /// La sal es texto al azar que se mezcla con el PIN antes del hash. Sin
  /// ella, todos los "1234" del mundo darian el mismo hash, y bastaria una
  /// tabla precalculada de los 10,000 PINes posibles para adivinarlo.
  static ({String hash, String sal}) protegerPin(String pin) {
    final aleatorio = Random.secure();
    final bytes = List<int>.generate(16, (_) => aleatorio.nextInt(256));
    final sal = base64Encode(bytes);
    return (hash: _hash(pin, sal), sal: sal);
  }

  /// Compara sin conocer el PIN guardado: se repite la receta con el PIN
  /// escrito y la misma sal, y se ve si da el mismo hash.
  static bool pinCorrecto(String pin, Dueno dueno) {
    if (!dueno.tienePin || dueno.pinSal == null) return false;
    return _hash(pin, dueno.pinSal!) == dueno.pinHash;
  }

  static String _hash(String pin, String sal) =>
      sha256.convert(utf8.encode('$sal$pin')).toString();

  // ─────────────────────────────────────────────────────────────────────────
  // Huella / rostro
  // ─────────────────────────────────────────────────────────────────────────

  /// Si el telefono tiene sensor y el usuario ya registro al menos una huella
  /// o su rostro en los ajustes de Android.
  static Future<bool> biometriaDisponible() async {
    try {
      if (!await _auth.canCheckBiometrics) return false;
      final registradas = await _auth.getAvailableBiometrics();
      return registradas.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Muestra el dialogo de huella de Android.
  ///
  /// Nunca lanza: cada forma de fallar se traduce a un [ResultadoBiometria]
  /// para que la pantalla decida que decir.
  static Future<ResultadoBiometria> pedirBiometria(String motivo) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: motivo,
        // Solo huella o rostro: el respaldo es el PIN de DogTrips, no el
        // bloqueo de pantalla del telefono.
        biometricOnly: true,
      );
      return ok ? ResultadoBiometria.exito : ResultadoBiometria.cancelado;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled => ResultadoBiometria.cancelado,
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.noBiometricsEnrolled =>
          ResultadoBiometria.noDisponible,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout => ResultadoBiometria.bloqueado,
        _ => ResultadoBiometria.error,
      };
    } catch (_) {
      return ResultadoBiometria.error;
    }
  }
}
