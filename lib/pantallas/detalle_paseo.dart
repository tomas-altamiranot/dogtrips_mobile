import 'dart:io';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../datos/base_datos.dart';
import '../main.dart';
import '../modelos/paseo.dart';

/// Detalle de un paseo: la foto en grande, los datos y la ubicacion.
class PantallaDetallePaseo extends StatelessWidget {
  const PantallaDetallePaseo({super.key, required this.paseo});

  final Paseo paseo;

  /// Abre Google Maps con las coordenadas guardadas.
  ///
  /// Se eligio invocar la app de mapas en vez de incrustar google_maps_flutter:
  /// incrustar un mapa exige una API key de Google con facturacion activada, y
  /// para mostrar un punto el resultado para el usuario es el mismo.
  Future<void> _abrirEnMapas(BuildContext context) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=${paseo.latitud},${paseo.longitud}',
    );
    try {
      final abrio = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!abrio && context.mounted) {
        _avisar(context, 'No se encontro una app de mapas en este dispositivo.');
      }
    } catch (e) {
      if (context.mounted) _avisar(context, 'No se pudo abrir el mapa.');
    }
  }

  Future<void> _borrar(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Eliminar paseo'),
        content: Text('Se eliminara el paseo de ${paseo.nombrePerro}. '
            'Esta accion no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogo, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    try {
      await BaseDatos.instancia.borrar(paseo.id!);
      // context.mounted protege de usar el contexto despues de que la pantalla
      // haya desaparecido mientras se esperaba el await.
      if (context.mounted) Navigator.pop(context);
    } on ErrorDeDatos catch (e) {
      if (context.mounted) _avisar(context, e.mensaje);
    }
  }

  void _avisar(BuildContext context, String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat("EEEE d 'de' MMMM, HH:mm", 'es').format(paseo.fecha);

    return Scaffold(
      appBar: AppBar(
        title: Text(paseo.nombrePerro),
        actions: [
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _borrar(context),
          ),
        ],
      ),
      drawer: const MenuLateral(),
      body: ListView(
        children: [
          // La misma etiqueta Hero que en la lista: Flutter empareja ambos
          // widgets y anima la foto creciendo de la miniatura a esta vista.
          Hero(
            tag: 'foto-paseo-${paseo.id}',
            child: _FotoGrande(ruta: paseo.fotoPath),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Dato(icono: Icons.event, titulo: 'Fecha', valor: fecha),
                _Dato(
                  icono: Icons.timer_outlined,
                  titulo: 'Duracion',
                  valor: '${paseo.duracionMin} minutos',
                ),
                _Dato(
                  icono: Icons.place_outlined,
                  titulo: 'Ubicacion',
                  valor: paseo.tieneUbicacion
                      ? '${paseo.latitud!.toStringAsFixed(5)}, '
                          '${paseo.longitud!.toStringAsFixed(5)}'
                      : 'No se registro',
                ),
                if (paseo.notas.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Notas del paseo',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ColoresDogTrips.navy.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(paseo.notas),
                  ),
                ],
                const SizedBox(height: 22),
                if (paseo.tieneUbicacion)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _abrirEnMapas(context),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Ver recorrido en Google Maps'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FotoGrande extends StatelessWidget {
  const _FotoGrande({this.ruta});

  final String? ruta;

  @override
  Widget build(BuildContext context) {
    const alto = 260.0;

    if (ruta == null || ruta!.isEmpty) {
      return Container(
        height: alto,
        width: double.infinity,
        color: ColoresDogTrips.navy.withValues(alpha: 0.08),
        child: const Icon(Icons.pets, size: 72, color: ColoresDogTrips.navy),
      );
    }

    return Image.file(
      File(ruta!),
      height: alto,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        height: alto,
        color: ColoresDogTrips.navy.withValues(alpha: 0.08),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_outlined, size: 48),
            SizedBox(height: 8),
            Text('La foto ya no esta disponible'),
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.titulo, required this.valor});

  final IconData icono;
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 19, color: ColoresDogTrips.coral),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 1),
                Text(valor, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
