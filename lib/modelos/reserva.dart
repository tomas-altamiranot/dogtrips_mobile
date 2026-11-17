import 'mascota.dart';
import 'paseador.dart';

enum EstadoReserva {
  pendiente('Pendiente'),
  confirmada('Confirmada'),
  completada('Completada'),
  cancelada('Cancelada');

  const EstadoReserva(this.etiqueta);
  final String etiqueta;

  static EstadoReserva desdeTexto(String? v) => EstadoReserva.values.firstWhere(
        (e) => e.name == v,
        orElse: () => EstadoReserva.pendiente,
      );
}

/// Calcula el costo de un paseo.
///
/// La formula viene del documento de requerimientos de 5.o semestre:
///
///   "Se les calculara una tarifa basada en la duracion del paseo, la distancia
///    recorrida, el numero de mascotas paseadas, peso y complexion de la
///    mascota, entre otros a evaluar."
///
/// De esos factores, esta version implementa duracion y complexion. Distancia y
/// numero de mascotas quedan como trabajo futuro: ambos dependen de datos que
/// solo existen una vez el paseo ocurrio, y esta app reserva paseos que aun no
/// han pasado.
///
/// Es una funcion suelta y no un metodo porque necesita datos de dos entidades
/// distintas. Ponerla dentro de una obligaria a que esa conociera a la otra.
double calcularCosto({
  required double tarifaHora,
  required Tamano tamano,
  required int duracionMin,
}) {
  final horas = duracionMin / 60.0;
  final bruto = tarifaHora * horas * tamano.factorTarifa;
  // Se redondea a pesos enteros: nadie cobra centavos por un paseo.
  return bruto.roundToDouble();
}

/// Una solicitud de paseo hecha por el dueno.
class Reserva {
  final int? id;
  final int mascotaId;
  final int paseadorId;
  final DateTime fechaHora;
  final int duracionMin;

  /// Indicaciones para el paseador. Es el campo que se llena por dictado de
  /// voz: el dueno suele escribirlo con prisa.
  final String instrucciones;

  final EstadoReserva estado;

  /// Se guarda calculado y no se recalcula al leer: si manana cambia la tarifa
  /// del paseador, las reservas viejas deben conservar el precio pactado.
  final double costoEstimado;

  const Reserva({
    this.id,
    required this.mascotaId,
    required this.paseadorId,
    required this.fechaHora,
    required this.duracionMin,
    this.instrucciones = '',
    this.estado = EstadoReserva.pendiente,
    required this.costoEstimado,
  });

  /// Arma una reserva calculando el costo a partir de la mascota y el paseador.
  factory Reserva.nueva({
    required Mascota mascota,
    required Paseador paseador,
    required DateTime fechaHora,
    required int duracionMin,
    String instrucciones = '',
  }) {
    return Reserva(
      mascotaId: mascota.id!,
      paseadorId: paseador.id!,
      fechaHora: fechaHora,
      duracionMin: duracionMin,
      instrucciones: instrucciones,
      costoEstimado: calcularCosto(
        tarifaHora: paseador.tarifaHora,
        tamano: mascota.tamano,
        duracionMin: duracionMin,
      ),
    );
  }

  Reserva copiarCon({int? id, EstadoReserva? estado}) => Reserva(
        id: id ?? this.id,
        mascotaId: mascotaId,
        paseadorId: paseadorId,
        fechaHora: fechaHora,
        duracionMin: duracionMin,
        instrucciones: instrucciones,
        estado: estado ?? this.estado,
        costoEstimado: costoEstimado,
      );

  // La fecha viaja como milisegundos desde 1970: es un entero, es exacto, y se
  // ordena correctamente sin convertir nada.
  Map<String, Object?> aMapa() => {
        'id': id,
        'mascota_id': mascotaId,
        'paseador_id': paseadorId,
        'fecha_hora': fechaHora.millisecondsSinceEpoch,
        'duracion_min': duracionMin,
        'instrucciones': instrucciones,
        'estado': estado.name,
        'costo_estimado': costoEstimado,
      };

  factory Reserva.desdeMapa(Map<String, Object?> m) => Reserva(
        id: m['id'] as int?,
        mascotaId: m['mascota_id'] as int,
        paseadorId: m['paseador_id'] as int,
        fechaHora: DateTime.fromMillisecondsSinceEpoch(m['fecha_hora'] as int),
        duracionMin: m['duracion_min'] as int,
        instrucciones: (m['instrucciones'] as String?) ?? '',
        estado: EstadoReserva.desdeTexto(m['estado'] as String?),
        costoEstimado: (m['costo_estimado'] as num).toDouble(),
      );
}

/// Una reserva junto con la mascota y el paseador a los que apunta.
///
/// La tabla guarda solo los ids. Para mostrar "Max con Ana Sosa" hay que unir
/// las tres tablas, y esta clase es el resultado de esa union: existe para que
/// las pantallas reciban un objeto completo en vez de tres sueltos.
class ReservaCompleta {
  final Reserva reserva;
  final Mascota mascota;
  final Paseador paseador;

  const ReservaCompleta({
    required this.reserva,
    required this.mascota,
    required this.paseador,
  });
}
