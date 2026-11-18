import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../datos/base_datos.dart';
import '../main.dart';
import '../modelos/reserva.dart';
import 'avatar_mascota.dart';
import 'inicio.dart' show unirNombres;

/// Lista de reservas del dueno, separada en proximos paseos e historial.
///
/// Todo sale de SQLite: el dueno puede ver sus reservas aunque no tenga senal,
/// que es justo cuando suele necesitarlas (en la calle, esperando al paseador).
class PantallaMisReservas extends StatefulWidget {
  const PantallaMisReservas({super.key});

  @override
  State<PantallaMisReservas> createState() => _PantallaMisReservasState();
}

class _PantallaMisReservasState extends State<PantallaMisReservas> {
  late Future<List<ReservaCompleta>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = BaseDatos.instancia.listarReservas();
  }

  Future<void> _abrirDetalle(ReservaCompleta r) async {
    await Navigator.pushNamed(context, Rutas.detalleReserva, arguments: r);
    // Al volver se recarga: pudo haberla cancelado en el detalle.
    if (!mounted) return;
    setState(() {
      _futuro = BaseDatos.instancia.listarReservas();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis reservas')),
      body: FutureBuilder<List<ReservaCompleta>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          final todas = snapshot.data!;
          if (todas.isEmpty) return const _SinReservas();

          // Proximas: la mas cercana primero. Historial: la mas reciente
          // primero. La base las entrega de la mas nueva a la mas vieja, asi
          // que las proximas se invierten.
          final proximas = todas
              .where((r) => r.reserva.esProxima)
              .toList()
              .reversed
              .toList();
          final historial = todas.where((r) => !r.reserva.esProxima).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (proximas.isNotEmpty) ...[
                const _Encabezado('Próximos paseos'),
                for (final r in proximas)
                  _TarjetaReserva(r: r, alTocar: () => _abrirDetalle(r)),
              ],
              if (historial.isNotEmpty) ...[
                const _Encabezado('Historial'),
                for (final r in historial)
                  _TarjetaReserva(r: r, alTocar: () => _abrirDetalle(r)),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Etiqueta de color con el estado de la reserva. La usan la lista y el
/// detalle, por eso es publica.
class EtiquetaEstado extends StatelessWidget {
  const EtiquetaEstado({super.key, required this.estado});

  final EstadoReserva estado;

  @override
  Widget build(BuildContext context) {
    // Solo colores de la paleta de DogTrips, mas gris para lo cancelado.
    final (fondo, texto) = switch (estado) {
      EstadoReserva.confirmada => (ColoresDogTrips.coral, Colors.white),
      EstadoReserva.completada => (ColoresDogTrips.navy, Colors.white),
      EstadoReserva.pendiente => (ColoresDogTrips.arena, ColoresDogTrips.navy),
      EstadoReserva.cancelada => (Colors.black12, Colors.black54),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado.etiqueta,
        style: TextStyle(
          color: texto,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: ColoresDogTrips.navy,
        ),
      ),
    );
  }
}

class _TarjetaReserva extends StatelessWidget {
  const _TarjetaReserva({required this.r, required this.alTocar});

  final ReservaCompleta r;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final reserva = r.reserva;
    final cancelada = reserva.estado == EstadoReserva.cancelada;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: alTocar,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            // Las canceladas se ven tenues: siguen ahi como registro, pero ya
            // no piden atencion.
            child: Opacity(
              opacity: cancelada ? 0.55 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat(
                            "EEEE d 'de' MMMM · HH:mm",
                            'es',
                          ).format(reserva.fechaHora),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      EtiquetaEstado(estado: reserva.estadoActual),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Las fotos de los perros, encimadas un poco.
                      SizedBox(
                        width: 28.0 + 18 * (r.mascotas.length - 1).clamp(0, 3),
                        height: 30,
                        child: Stack(
                          children: [
                            for (var i = 0; i < r.mascotas.length && i < 4; i++)
                              Positioned(
                                left: 18.0 * i,
                                child: CircleAvatar(
                                  radius: 15,
                                  backgroundColor: Colors.white,
                                  child: AvatarMascota(
                                    mascota: r.mascotas[i],
                                    radio: 13,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          r.mascotas.isEmpty
                              ? 'Sin perros'
                              : '${unirNombres([for (final m in r.mascotas) m.nombre])} '
                                    'con ${r.paseador.nombre}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${reserva.duracionMin} min · '
                    '\$${reserva.costoEstimado.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SinReservas extends StatelessWidget {
  const _SinReservas();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note, size: 56, color: ColoresDogTrips.coral),
            SizedBox(height: 14),
            Text(
              'Aún no tienes paseos reservados.\n'
              'Busca un paseador desde el Inicio.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
