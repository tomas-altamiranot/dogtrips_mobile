import 'dart:math' as math;

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

/// Duraciones que se pueden reservar, en minutos.
const duracionesPermitidas = [30, 60, 90];

/// Descuento por cada perro adicional en el mismo paseo: el 2.o paga 90 %, el
/// 3.o 81 %, el 4.o 72.9 %... Es compuesto: cada uno paga el 90 % del anterior.
const factorPerroAdicional = 0.9;

/// Lo que paga cada perro de un paseo, en el orden en que se cobra.
///
/// La formula viene del documento de requerimientos de 5.o semestre:
///
///   "Se les calculara una tarifa basada en la duracion del paseo, la distancia
///    recorrida, el numero de mascotas paseadas, peso y complexion de la
///    mascota, entre otros a evaluar."
///
/// Esta version implementa duracion, complexion y numero de mascotas. La
/// distancia queda como trabajo futuro: solo se conoce cuando el paseo ya
/// ocurrio, y esta app reserva paseos que aun no pasan.
///
/// El perro mas grande paga completo y los demas reciben el descuento, de mayor
/// a menor. Asi el precio no depende del orden en que el dueno los eligio.
///
/// Es una funcion suelta y no un metodo porque necesita datos de dos entidades
/// distintas. Ponerla dentro de una obligaria a que esa conociera a la otra.
List<double> costoPorPerro({
  required double tarifaHora,
  required List<Tamano> tamanos,
  required int duracionMin,
}) {
  final horas = duracionMin / 60.0;
  // Se copia antes de ordenar para no desordenar la lista de quien llama.
  final ordenados = [...tamanos]
    ..sort((a, b) => b.factorTarifa.compareTo(a.factorTarifa));

  return [
    for (var i = 0; i < ordenados.length; i++)
      tarifaHora *
          horas *
          ordenados[i].factorTarifa *
          math.pow(factorPerroAdicional, i),
  ];
}

/// Costo total del paseo: la suma de lo que paga cada perro.
double calcularCosto({
  required double tarifaHora,
  required List<Tamano> tamanos,
  required int duracionMin,
}) {
  final total = costoPorPerro(
    tarifaHora: tarifaHora,
    tamanos: tamanos,
    duracionMin: duracionMin,
  ).fold(0.0, (suma, costo) => suma + costo);
  // Se redondea a pesos enteros: nadie cobra centavos por un paseo.
  return total.roundToDouble();
}

/// Una solicitud de paseo hecha por el dueno.
///
/// No guarda que perros van: una reserva puede llevar varios, y una columna de
/// SQLite solo guarda un valor. Esa relacion vive en la tabla intermedia
/// reserva_mascotas (ver BaseDatos).
class Reserva {
  final int? id;
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
    required this.paseadorId,
    required this.fechaHora,
    required this.duracionMin,
    this.instrucciones = '',
    this.estado = EstadoReserva.pendiente,
    required this.costoEstimado,
  });

  /// Arma una reserva calculando el costo a partir de los perros y el paseador.
  ///
  /// Nace confirmada: en esta entrega no existe la app del paseador que la
  /// aceptaria, asi que se da por aceptada al crearse.
  factory Reserva.nueva({
    required List<Mascota> mascotas,
    required Paseador paseador,
    required DateTime fechaHora,
    required int duracionMin,
    String instrucciones = '',
  }) {
    return Reserva(
      paseadorId: paseador.id!,
      fechaHora: fechaHora,
      duracionMin: duracionMin,
      instrucciones: instrucciones,
      estado: EstadoReserva.confirmada,
      costoEstimado: calcularCosto(
        tarifaHora: paseador.tarifaHora,
        tamanos: [for (final m in mascotas) m.tamano],
        duracionMin: duracionMin,
      ),
    );
  }

  /// Termino del paseo.
  DateTime get fin => fechaHora.add(Duration(minutes: duracionMin));

  /// El estado que se le muestra al dueno.
  ///
  /// Nadie marca un paseo como "completado": esa seria la app del paseador,
  /// que no existe en esta entrega. Por eso se deduce por la hora: un paseo
  /// confirmado que ya termino se muestra como completado. No se guarda en la
  /// base; se calcula cada vez.
  EstadoReserva get estadoActual {
    if (estado == EstadoReserva.confirmada && fin.isBefore(DateTime.now())) {
      return EstadoReserva.completada;
    }
    return estado;
  }

  /// Todavia no ocurre y no se cancelo: va en "Proximos paseos".
  bool get esProxima =>
      estado != EstadoReserva.cancelada && fin.isAfter(DateTime.now());

  /// Solo se puede cancelar lo que sigue activo y aun no empieza.
  bool get sePuedeCancelar =>
      (estado == EstadoReserva.pendiente ||
          estado == EstadoReserva.confirmada) &&
      fechaHora.isAfter(DateTime.now());

  Reserva copiarCon({int? id, EstadoReserva? estado}) => Reserva(
    id: id ?? this.id,
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
    'paseador_id': paseadorId,
    'fecha_hora': fechaHora.millisecondsSinceEpoch,
    'duracion_min': duracionMin,
    'instrucciones': instrucciones,
    'estado': estado.name,
    'costo_estimado': costoEstimado,
  };

  factory Reserva.desdeMapa(Map<String, Object?> m) => Reserva(
    id: m['id'] as int?,
    paseadorId: m['paseador_id'] as int,
    fechaHora: DateTime.fromMillisecondsSinceEpoch(m['fecha_hora'] as int),
    duracionMin: m['duracion_min'] as int,
    instrucciones: (m['instrucciones'] as String?) ?? '',
    estado: EstadoReserva.desdeTexto(m['estado'] as String?),
    costoEstimado: (m['costo_estimado'] as num).toDouble(),
  );
}

/// Una reserva junto con los perros y el paseador a los que apunta.
///
/// La tabla guarda solo ids. Para mostrar "Max y Luna con Ana Sosa" hay que
/// unir varias tablas, y esta clase es el resultado de esa union: existe para
/// que las pantallas reciban un objeto completo en vez de piezas sueltas.
class ReservaCompleta {
  final Reserva reserva;
  final List<Mascota> mascotas;
  final Paseador paseador;

  const ReservaCompleta({
    required this.reserva,
    required this.mascotas,
    required this.paseador,
  });
}
