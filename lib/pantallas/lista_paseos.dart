import 'dart:io';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../datos/base_datos.dart';
import '../main.dart';
import '../modelos/paseo.dart';

/// Pantalla principal: los paseos guardados en el telefono.
///
/// Es Stateful porque tiene que poder recargar la lista cuando el usuario
/// vuelve de registrar un paseo nuevo. Un StatelessWidget no podria.
class PantallaListaPaseos extends StatefulWidget {
  const PantallaListaPaseos({super.key});

  @override
  State<PantallaListaPaseos> createState() => _PantallaListaPaseosState();
}

class _PantallaListaPaseosState extends State<PantallaListaPaseos> {
  /// El Future se guarda en una variable y NO se crea dentro de build().
  ///
  /// build() se ejecuta muchas veces; si el Future naciera ahi, cada repintado
  /// lanzaria una consulta nueva a la base y la pantalla parpadearia sin parar.
  late Future<List<Paseo>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = BaseDatos.instancia.listar();
  }

  void _recargar() {
    setState(() => _futuro = BaseDatos.instancia.listar());
  }

  Future<void> _irANuevo() async {
    final guardado = await Navigator.pushNamed(context, Rutas.nuevo);
    // Solo se recarga si de verdad se guardo algo: volver con el boton de atras
    // no deberia costar una consulta.
    if (guardado == true) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis paseos')),
      drawer: const MenuLateral(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _irANuevo,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo paseo'),
      ),
      // FutureBuilder conecta una operacion asincrona con la interfaz: dibuja
      // un estado distinto segun la consulta este cargando, haya fallado o
      // haya terminado. Sin el habria que manejar a mano banderas de carga.
      body: FutureBuilder<List<Paseo>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _Aviso(
              icono: Icons.error_outline,
              titulo: 'No se pudieron cargar los paseos',
              detalle: '${snapshot.error}',
              accion: TextButton.icon(
                onPressed: _recargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            );
          }

          final paseos = snapshot.data ?? const <Paseo>[];
          if (paseos.isEmpty) {
            return const _Aviso(
              icono: Icons.pets,
              titulo: 'Todavia no hay paseos',
              detalle: 'Registra el primero con el boton de abajo.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _recargar(),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 88),
              itemCount: paseos.length,
              itemBuilder: (context, i) => _TarjetaPaseo(
                paseo: paseos[i],
                alVolver: _recargar,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TarjetaPaseo extends StatelessWidget {
  const _TarjetaPaseo({required this.paseo, required this.alVolver});

  final Paseo paseo;
  final VoidCallback alVolver;

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat("d 'de' MMMM, HH:mm", 'es').format(paseo.fecha);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        // Hero empareja este widget con el de la pantalla de detalle usando la
        // misma etiqueta, y anima la transicion entre ambos. La etiqueta tiene
        // que ser unica en pantalla: por eso lleva el id del paseo.
        leading: Hero(
          tag: 'foto-paseo-${paseo.id}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _Miniatura(ruta: paseo.fotoPath),
          ),
        ),
        title: Text(
          paseo.nombrePerro,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text('$fecha  ·  ${paseo.duracionMin} min'),
            if (paseo.tieneUbicacion)
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Row(
                  children: [
                    Icon(Icons.place, size: 13, color: ColoresDogTrips.coral),
                    SizedBox(width: 3),
                    Text('Con ubicacion', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.pushNamed(
            context,
            Rutas.detalle,
            arguments: paseo,
          );
          // El detalle permite borrar, asi que al volver hay que releer.
          alVolver();
        },
      ),
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({this.ruta});

  final String? ruta;

  @override
  Widget build(BuildContext context) {
    const lado = 56.0;

    if (ruta == null || ruta!.isEmpty) {
      return Container(
        width: lado,
        height: lado,
        color: ColoresDogTrips.navy.withValues(alpha: 0.08),
        child: const Icon(Icons.pets, color: ColoresDogTrips.navy),
      );
    }

    return Image.file(
      File(ruta!),
      width: lado,
      height: lado,
      fit: BoxFit.cover,
      // La foto pudo haberse borrado de la galeria despues de guardarse. Sin
      // errorBuilder la app mostraria una excepcion roja en mitad de la lista.
      errorBuilder: (_, _, _) => Container(
        width: lado,
        height: lado,
        color: ColoresDogTrips.navy.withValues(alpha: 0.08),
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.icono,
    required this.titulo,
    required this.detalle,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 56, color: ColoresDogTrips.navy.withValues(alpha: 0.35)),
            const SizedBox(height: 14),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            if (accion != null) ...[const SizedBox(height: 16), accion!],
          ],
        ),
      ),
    );
  }
}
