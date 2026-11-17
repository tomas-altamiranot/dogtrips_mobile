import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'pantallas/inicio.dart';
import 'pantallas/mapa_paseadores.dart';

Future<void> main() async {
  // Hay que esperar a que Flutter enlace con la plataforma antes de hacer
  // cualquier trabajo asincrono previo a runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // DateFormat con locale 'es' lanza excepcion si los datos del idioma no se
  // cargaron antes. Sin esta linea la app truena al mostrar la primera fecha.
  await initializeDateFormatting('es');

  runApp(const AppDogTrips());
}

/// Paleta de DogTrips, heredada de la version web de 6.o semestre.
/// Se conserva para que la app y la web se lean como el mismo producto.
class ColoresDogTrips {
  static const navy = Color(0xFF1B2F49);
  static const coral = Color(0xFFE27D60);
  static const arena = Color(0xFFF6F3EB);
}

/// Nombres de rutas en constantes, no como texto suelto.
///
/// Un nombre mal escrito dentro de un pushNamed falla en tiempo de ejecucion, y
/// solo cuando alguien toca ese boton. Como constante, lo atrapa el compilador.
class Rutas {
  static const inicio = '/';
  static const mapa = '/mapa';
  static const perfilPaseador = '/paseador';
  static const nuevaReserva = '/reservar';
  static const misReservas = '/reservas';
  static const misMascotas = '/mascotas';
}

class AppDogTrips extends StatelessWidget {
  const AppDogTrips({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DogTrips',
      debugShowCheckedModeBanner: false,
      theme: _tema(),
      initialRoute: Rutas.inicio,
      routes: {
        Rutas.inicio: (_) => const PantallaInicio(),
        Rutas.mapa: (_) => const PantallaMapaPaseadores(),
      },
      // Red de seguridad: sin esto, navegar a una ruta no registrada lanza una
      // excepcion y tumba la app. Mientras el proyecto crece, es preferible una
      // pantalla que diga "en construccion" a un cierre inesperado.
      onUnknownRoute: (ajustes) => MaterialPageRoute(
        builder: (_) => _EnConstruccion(ruta: ajustes.name ?? '?'),
      ),
    );
  }

  ThemeData _tema() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ColoresDogTrips.navy,
        primary: ColoresDogTrips.navy,
        secondary: ColoresDogTrips.coral,
      ),
      scaffoldBackgroundColor: ColoresDogTrips.arena,
      appBarTheme: const AppBarTheme(
        backgroundColor: ColoresDogTrips.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ColoresDogTrips.coral,
        foregroundColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ColoresDogTrips.navy,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// Marcador temporal para las rutas que todavia no tienen pantalla.
class _EnConstruccion extends StatelessWidget {
  const _EnConstruccion({required this.ruta});

  final String ruta;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('En construccion')),
      drawer: const MenuLateral(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.construction, size: 56, color: ColoresDogTrips.coral),
              const SizedBox(height: 14),
              Text(
                'La pantalla "$ruta" todavia no esta lista.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Menu lateral compartido por todas las pantallas.
///
/// Vive aqui y no dentro de una pantalla porque lo usan varias: si estuviera en
/// el inicio, el mapa tendria que importar el inicio solo para reusar el menu.
class MenuLateral extends StatelessWidget {
  const MenuLateral({super.key});

  void _ir(BuildContext context, String ruta) {
    Navigator.pop(context); // cierra el menu antes de navegar
    if (ruta == Rutas.inicio) {
      // Volver al inicio limpia la pila: si no, el boton de atras acumularia
      // una cadena infinita de pantallas.
      Navigator.pushNamedAndRemoveUntil(context, ruta, (r) => false);
    } else {
      Navigator.pushNamed(context, ruta);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: ColoresDogTrips.navy),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Image.asset(
                  'assets/imagenes/logo-blanco.png',
                  height: 64,
                  // Si el asset faltara, Image.asset lanza y tumba el menu
                  // entero. Con errorBuilder cae al texto y la app sigue.
                  errorBuilder: (_, _, _) => const Text(
                    'DOGTRIPS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Safe Journeys, Happy Tails',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Inicio'),
            onTap: () => _ir(context, Rutas.inicio),
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('Encuentra tu paseador'),
            onTap: () => _ir(context, Rutas.mapa),
          ),
          ListTile(
            leading: const Icon(Icons.pets_outlined),
            title: const Text('Mis mascotas'),
            onTap: () => _ir(context, Rutas.misMascotas),
          ),
          ListTile(
            leading: const Icon(Icons.event_note_outlined),
            title: const Text('Mis reservas'),
            onTap: () => _ir(context, Rutas.misReservas),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Acerca de'),
            subtitle: Text('Proyecto academico\nUniversidad Anahuac Mayab'),
          ),
        ],
      ),
    );
  }
}
