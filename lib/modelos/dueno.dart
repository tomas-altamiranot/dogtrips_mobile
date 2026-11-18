/// La persona que usa la app: el dueno de los perros.
///
/// Solo existe uno por telefono, porque la app no tiene cuentas ni servidor.
/// Por eso su id siempre es 1.
class Dueno {
  final int id;
  final String nombre;

  /// Huella digital del PIN, no el PIN. Ver Seguridad.protegerPin.
  final String? pinHash;

  /// Texto al azar que se mezcla con el PIN antes de sacarle el hash.
  final String? pinSal;

  /// Si el dueno eligio entrar con huella o rostro.
  final bool usaBiometria;

  const Dueno({
    this.id = 1,
    required this.nombre,
    this.pinHash,
    this.pinSal,
    this.usaBiometria = false,
  });

  /// "Tomas Altamirano" -> "Tomas". Para saludar no hace falta el apellido.
  String get primerNombre => nombre.trim().split(' ').first;

  /// Letra para el circulo del avatar.
  String get inicial =>
      primerNombre.isEmpty ? '?' : primerNombre[0].toUpperCase();

  /// Sin PIN la cuenta no esta protegida y la app abre directo.
  bool get tienePin => pinHash != null && pinHash!.isNotEmpty;

  /// Copia cambiando solo lo indicado. Los modelos son inmutables (todo es
  /// final): para "cambiar" un dato se crea un objeto nuevo.
  Dueno copiarCon({
    String? nombre,
    String? pinHash,
    String? pinSal,
    bool? usaBiometria,
  }) => Dueno(
    id: id,
    nombre: nombre ?? this.nombre,
    pinHash: pinHash ?? this.pinHash,
    pinSal: pinSal ?? this.pinSal,
    usaBiometria: usaBiometria ?? this.usaBiometria,
  );

  Map<String, Object?> aMapa() => {
    'id': id,
    'nombre': nombre,
    'pin_hash': pinHash,
    'pin_sal': pinSal,
    // SQLite no tiene booleanos: se guardan como 1 y 0.
    'usa_biometria': usaBiometria ? 1 : 0,
  };

  factory Dueno.desdeMapa(Map<String, Object?> m) => Dueno(
    id: m['id'] as int,
    nombre: m['nombre'] as String,
    pinHash: m['pin_hash'] as String?,
    pinSal: m['pin_sal'] as String?,
    usaBiometria: (m['usa_biometria'] as int? ?? 0) == 1,
  );
}
