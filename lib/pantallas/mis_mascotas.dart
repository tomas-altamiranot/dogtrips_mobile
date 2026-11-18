import 'package:material_ui/material_ui.dart';

import '../datos/base_datos.dart';
import '../main.dart';
import '../modelos/mascota.dart';
import 'avatar_mascota.dart';

/// Lista de los perros del dueno.
///
/// Tocar uno abre el formulario para editarlo; el boton flotante abre el mismo
/// formulario vacio para agregar uno nuevo.
class PantallaMisMascotas extends StatefulWidget {
  const PantallaMisMascotas({super.key});

  @override
  State<PantallaMisMascotas> createState() => _PantallaMisMascotasState();
}

class _PantallaMisMascotasState extends State<PantallaMisMascotas> {
  late Future<List<Mascota>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = BaseDatos.instancia.listarMascotas();
  }

  /// Abre el formulario (con o sin mascota) y recarga la lista al volver.
  Future<void> _abrirFormulario([Mascota? mascota]) async {
    await Navigator.pushNamed(context, Rutas.formMascota, arguments: mascota);
    if (!mounted) return;
    // Llaves y no flecha: con flecha, setState recibiria el Future de vuelta
    // y lanzaria un error en vez de redibujar la lista.
    setState(() {
      _futuro = BaseDatos.instancia.listarMascotas();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Sin drawer: asi el AppBar muestra la flecha de regresar.
      appBar: AppBar(title: const Text('Mis mascotas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: FutureBuilder<List<Mascota>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          final mascotas = snapshot.data!;
          if (mascotas.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pets, size: 56, color: ColoresDogTrips.coral),
                    SizedBox(height: 14),
                    Text(
                      'Aún no registras a ningún perro.\n'
                      'Toca "Agregar" para empezar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
            );
          }

          // ListView.separated construye solo las filas visibles y pone un
          // espacio entre cada una.
          return ListView.separated(
            // Espacio abajo para que el boton flotante no tape la ultima fila.
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: mascotas.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final m = mascotas[i];
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  // Misma etiqueta Hero que en el formulario: la foto "vuela"
                  // de la lista a la pantalla de edicion.
                  leading: Hero(
                    tag: 'mascota-${m.id}',
                    child: AvatarMascota(mascota: m, radio: 28),
                  ),
                  title: Text(
                    m.nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  subtitle: Text(
                    '${m.raza} · ${m.tamano.etiqueta} · ${m.edadLegible}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _abrirFormulario(m),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
