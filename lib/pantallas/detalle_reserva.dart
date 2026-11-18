import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../datos/base_datos.dart';
import '../main.dart';
import '../modelos/reserva.dart';
import 'avatar_mascota.dart';
import 'mis_reservas.dart' show EtiquetaEstado;
import 'perfil_paseador.dart';

/// Todo sobre una reserva, con la opcion de cancelarla.
class PantallaDetalleReserva extends StatefulWidget {
  const PantallaDetalleReserva({super.key, required this.inicial});

  final ReservaCompleta inicial;

  @override
  State<PantallaDetalleReserva> createState() => _PantallaDetalleReservaState();
}

class _PantallaDetalleReservaState extends State<PantallaDetalleReserva> {
  /// Copia local de la reserva. Si el dueno la cancela, se actualiza aqui y la
  /// pantalla cambia al instante, sin volver a leer la base.
  late Reserva _reserva = widget.inicial.reserva;
  bool _cancelando = false;

  Future<void> _cancelar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('¿Cancelar este paseo?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('No, conservarlo'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(dialogo, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    setState(() => _cancelando = true);
    try {
      await BaseDatos.instancia.cambiarEstadoReserva(
        _reserva.id!,
        EstadoReserva.cancelada,
      );
      if (!mounted) return;
      setState(() {
        _reserva = _reserva.copiarCon(estado: EstadoReserva.cancelada);
        _cancelando = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Paseo cancelado.')));
    } on ErrorDeDatos catch (e) {
      if (!mounted) return;
      setState(() => _cancelando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.inicial;
    final dia = DateFormat("EEEE d 'de' MMMM", 'es').format(_reserva.fechaHora);
    final horas =
        '${DateFormat('HH:mm').format(_reserva.fechaHora)} a '
        '${DateFormat('HH:mm').format(_reserva.fin)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del paseo')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  // Primera letra en mayuscula: DateFormat da "lunes", no "Lunes".
                  dia[0].toUpperCase() + dia.substring(1),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: ColoresDogTrips.navy,
                  ),
                ),
              ),
              EtiquetaEstado(estado: _reserva.estadoActual),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$horas · ${_reserva.duracionMin} min',
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 20),

          _Seccion(
            titulo: 'Paseador',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: ColoresDogTrips.navy,
                child: Text(
                  r.paseador.nombre.characters.first,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(r.paseador.nombre),
              subtitle: Text(r.paseador.zona),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(
                context,
                Rutas.perfilPaseador,
                arguments: ArgsPaseador(paseador: r.paseador),
              ),
            ),
          ),

          _Seccion(
            titulo: r.mascotas.length == 1 ? 'Perro' : 'Perros',
            child: Column(
              children: [
                for (final m in r.mascotas)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AvatarMascota(mascota: m, radio: 20),
                    title: Text(m.nombre),
                    subtitle: Text('${m.raza} · ${m.tamano.etiqueta}'),
                  ),
              ],
            ),
          ),

          if (_reserva.instrucciones.isNotEmpty)
            _Seccion(
              titulo: 'Instrucciones',
              child: Text(_reserva.instrucciones),
            ),

          _Seccion(
            titulo: 'Costo',
            child: Row(
              children: [
                const Text('Total acordado'),
                const Spacer(),
                Text(
                  '\$${_reserva.costoEstimado.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ColoresDogTrips.navy,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          if (_reserva.sePuedeCancelar)
            OutlinedButton.icon(
              onPressed: _cancelando ? null : _cancelar,
              icon: const Icon(Icons.event_busy),
              label: const Text('Cancelar paseo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade700),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
