import 'package:material_ui/material_ui.dart';

import '../datos/base_datos.dart';
import '../main.dart';
import '../modelos/dueno.dart';
import '../modelos/mascota.dart';
import 'avatar_mascota.dart';
import 'bienvenida.dart';

/// Lo que el Inicio necesita para dibujarse.
class _DatosInicio {
  final Dueno? dueno;
  final List<Mascota> mascotas;
  const _DatosInicio(this.dueno, this.mascotas);
}

/// Perfil del dueno. Es la pantalla principal de la app.
///
/// Esta centrada en la persona y en sus perros, no en el servicio: primero
/// "hola, Tomas, estos son tus perros"; despues "busquemos quien los pasee".
/// Si todavia no hay dueno registrado, muestra la bienvenida en su lugar.
class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  late Future<_DatosInicio> _futuro;

  /// Ids de los perros que van a salir a pasear. Por defecto, todos.
  Set<int> _seleccion = {};

  @override
  void initState() {
    super.initState();
    _futuro = _cargar();
  }

  Future<_DatosInicio> _cargar() async {
    final dueno = await BaseDatos.instancia.leerDueno();
    final mascotas = await BaseDatos.instancia.listarMascotas();
    _seleccion = {for (final m in mascotas) m.id!};
    return _DatosInicio(dueno, mascotas);
  }

  // Llaves y no flecha dentro de setState: con flecha, la asignacion devolveria
  // el Future y setState lanzaria un error en vez de redibujar.
  void _recargar() => setState(() {
        _futuro = _cargar();
      });

  /// Abre otra pantalla y, al volver, recarga: el usuario pudo haber agregado
  /// o borrado un perro mientras estaba alla.
  Future<void> _irYVolver(String ruta) async {
    await Navigator.pushNamed(context, ruta);
    if (mounted) _recargar();
  }

  void _buscarPaseador(List<Mascota> mascotas) {
    final elegidas = mascotas.where((m) => _seleccion.contains(m.id)).toList();
    if (elegidas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige al menos un perro para el paseo.')),
      );
      return;
    }
    // Los perros elegidos viajan al mapa y de ahi a la reserva.
    Navigator.pushNamed(context, Rutas.mapa, arguments: elegidas);
  }

  Future<void> _editarNombre(Dueno dueno) async {
    final nuevo = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoNombre(nombreActual: dueno.nombre),
    );
    if (nuevo == null || nuevo.isEmpty) return;

    try {
      await BaseDatos.instancia.guardarDueno(Dueno(nombre: nuevo));
      _recargar();
    } on ErrorDeDatos catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DatosInicio>(
      future: _futuro,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const LogoDogTrips()),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 52),
                  const SizedBox(height: 12),
                  Text('${snapshot.error}'),
                  TextButton.icon(
                    onPressed: _recargar,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        final datos = snapshot.data!;
        // Primera vez: todavia no sabemos quien es.
        if (datos.dueno == null) {
          return PantallaBienvenida(alTerminar: _recargar);
        }
        return _perfil(datos.dueno!, datos.mascotas);
      },
    );
  }

  Widget _perfil(Dueno dueno, List<Mascota> mascotas) {
    return Scaffold(
      appBar: AppBar(title: const LogoDogTrips()),
      drawer: const MenuLateral(),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Encabezado(
            dueno: dueno,
            mascotas: mascotas,
            alEditar: () => _editarNombre(dueno),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (mascotas.isEmpty)
                  // Directo al formulario: el usuario ya dijo que quiere
                  // registrar a su perro, no hay que pasar por la lista vacia.
                  _SinMascotas(alTocar: () => _irYVolver(Rutas.formMascota))
                else ...[
                  const Text(
                    '¿Quién sale a pasear hoy?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ColoresDogTrips.navy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in mascotas)
                        _ChipMascota(
                          mascota: m,
                          elegida: _seleccion.contains(m.id),
                          alCambiar: (si) => setState(() {
                            si ? _seleccion.add(m.id!) : _seleccion.remove(m.id);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _BotonPrincipal(
                    icono: Icons.map_outlined,
                    titulo: 'Buscar paseador',
                    detalle: _textoSeleccion(mascotas),
                    alTocar: () => _buscarPaseador(mascotas),
                  ),
                ],
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: _BotonSecundario(
                        icono: Icons.pets_outlined,
                        titulo: 'Mis mascotas',
                        alTocar: () => _irYVolver(Rutas.misMascotas),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BotonSecundario(
                        icono: Icons.event_note_outlined,
                        titulo: 'Mis reservas',
                        alTocar: () => _irYVolver(Rutas.misReservas),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Unico lugar del Inicio donde aparece el slogan.
                const Text(
                  'Safe Journeys, Happy Tails',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ColoresDogTrips.coral,
                    letterSpacing: 1.5,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "Para Max y Luna · cerca de ti"
  String _textoSeleccion(List<Mascota> mascotas) {
    final nombres = mascotas
        .where((m) => _seleccion.contains(m.id))
        .map((m) => m.nombre)
        .toList();
    if (nombres.isEmpty) return 'Elige quién va al paseo';
    return 'Para ${unirNombres(nombres)} · cerca de ti';
  }
}

/// ["Max"] -> "Max";  ["Max", "Luna", "Toby"] -> "Max, Luna y Toby".
String unirNombres(List<String> nombres) {
  if (nombres.length == 1) return nombres.first;
  return '${nombres.sublist(0, nombres.length - 1).join(', ')} y ${nombres.last}';
}

/// Saludo segun la hora: hace que la app se sienta como alguien, no algo.
String saludoPorHora(DateTime ahora) {
  if (ahora.hour < 12) return 'Buenos días';
  if (ahora.hour < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

/// Dialogo para editar el nombre del dueno.
///
/// Es un StatefulWidget propio para que el controlador del texto viva y muera
/// con el dialogo. Si lo liberara quien abre el dialogo, lo haria mientras el
/// dialogo aun se esta cerrando (la animacion de salida todavia lo usa) y la
/// app truena.
class _DialogoNombre extends StatefulWidget {
  const _DialogoNombre({required this.nombreActual});

  final String nombreActual;

  @override
  State<_DialogoNombre> createState() => _DialogoNombreState();
}

class _DialogoNombreState extends State<_DialogoNombre> {
  late final _control = TextEditingController(text: widget.nombreActual);

  @override
  void dispose() {
    // Aqui si es seguro: dispose() solo corre cuando el dialogo ya desaparecio.
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tu nombre'),
      content: TextField(
        controller: _control,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _control.text.trim()),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Franja navy que continua el AppBar, con el saludo y el avatar del dueno.
class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.dueno,
    required this.mascotas,
    required this.alEditar,
  });

  final Dueno dueno;
  final List<Mascota> mascotas;
  final VoidCallback alEditar;

  @override
  Widget build(BuildContext context) {
    final frase = mascotas.isEmpty
        ? 'Cuéntanos de tu perro para empezar.'
        : mascotas.length == 1
            ? '${mascotas.first.nombre} espera su próxima aventura.'
            : '${unirNombres(mascotas.map((m) => m.nombre).toList())} '
                'esperan su próxima aventura.';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      decoration: const BoxDecoration(
        color: ColoresDogTrips.navy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: ColoresDogTrips.coral,
            child: Text(
              dueno.inicial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${saludoPorHora(DateTime.now())},',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  dueno.primerNombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  frase,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar nombre',
            onPressed: alEditar,
            icon: const Icon(Icons.edit_outlined, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

/// Chip de un perro en "¿Quien sale a pasear hoy?".
///
/// Los dos estados deben distinguirse de un vistazo: elegido va relleno de
/// coral con palomita; no elegido, blanco con borde gris.
class _ChipMascota extends StatelessWidget {
  const _ChipMascota({
    required this.mascota,
    required this.elegida,
    required this.alCambiar,
  });

  final Mascota mascota;
  final bool elegida;
  final ValueChanged<bool> alCambiar;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      // Con palomita no cabe tambien el avatar: se muestra uno u otro.
      avatar: elegida ? null : AvatarMascota(mascota: mascota, radio: 12),
      label: Text(mascota.nombre),
      selected: elegida,
      onSelected: alCambiar,
      showCheckmark: true,
      checkmarkColor: Colors.white,
      selectedColor: ColoresDogTrips.coral,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: elegida ? Colors.white : ColoresDogTrips.navy,
        fontWeight: elegida ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: elegida ? ColoresDogTrips.coral : Colors.black26,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    );
  }
}

/// Tarjeta que aparece cuando el dueno aun no registra ningun perro.
class _SinMascotas extends StatelessWidget {
  const _SinMascotas({required this.alTocar});

  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColoresDogTrips.coral.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.pets, size: 44, color: ColoresDogTrips.coral),
          const SizedBox(height: 12),
          const Text(
            'Preséntanos a tu perro',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ColoresDogTrips.navy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Así el paseador sabrá a quién va a cuidar: '
            'su tamaño, su edad y lo que lo hace único.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: alTocar,
            icon: const Icon(Icons.add),
            label: const Text('Registrar a mi perro'),
          ),
        ],
      ),
    );
  }
}

class _BotonPrincipal extends StatelessWidget {
  const _BotonPrincipal({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.alTocar,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColoresDogTrips.navy,
      borderRadius: BorderRadius.circular(12),
      // InkWell sobre Material da el efecto de onda al tocar. Un GestureDetector
      // tambien detectaria el toque, pero sin respuesta visual el usuario no
      // sabe si la app lo registro.
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Row(
            children: [
              Icon(icono, color: ColoresDogTrips.coral, size: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detalle,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonSecundario extends StatelessWidget {
  const _BotonSecundario({
    required this.icono,
    required this.titulo,
    required this.alTocar,
  });

  final IconData icono;
  final String titulo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: ColoresDogTrips.navy.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            children: [
              Icon(icono, color: ColoresDogTrips.navy, size: 28),
              const SizedBox(height: 10),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: ColoresDogTrips.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
