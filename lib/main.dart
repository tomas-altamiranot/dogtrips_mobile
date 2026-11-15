import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'modelos/paseo.dart';
import 'pantallas/detalle_paseo.dart';
import 'pantallas/lista_paseos.dart';
import 'pantallas/nuevo_paseo.dart';

Future<void> main() async {
  // Hay que esperar a que Flutter inicialice su enlace con la plataforma antes
  // de hacer cualquier trabajo asincrono previo a runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // DateFormat con locale 'es' lanza una excepcion si los datos del idioma no
  // se cargaron antes. Sin esta linea la app truena al abrir la lista.
  await initializeDateFormatting('es');

  runApp(const AppDogTrips());
}

/// Paleta de DogTrips, heredada de la version web del proyecto.
/// Se conserva para que la app y la web se lean como el mismo producto.
class ColoresDogTrips {
  static const navy = Color(0xFF1B2F49);
  static const coral = Color(0xFFE27D60);
  static const arena = Color(0xFFF6F3EB);
}

/// Nombres de rutas en constantes, no como texto suelto.
///
/// Si una ruta se escribe mal dentro de un pushNamed, el fallo aparece en
/// tiempo de ejecucion y solo cuando alguien toca ese boton. Con constantes lo
/// atrapa el compilador.
class Rutas {
  static const lista = '/';
  static const detalle = '/detalle';
  static const nuevo = '/nuevo';
}

class AppDogTrips extends StatelessWidget {
  const AppDogTrips({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DogTrips',
      debugShowCheckedModeBanner: false,
      theme: _tema(),
      initialRoute: Rutas.lista,
      // Rutas con nombre: cada pantalla se declara una vez aqui. La alternativa
      // seria construir un MaterialPageRoute a mano en cada boton que navega,
      // repitiendo el mismo codigo por toda la app.
      routes: {
        Rutas.lista: (_) => const PantallaListaPaseos(),
        Rutas.nuevo: (_) => const PantallaNuevoPaseo(),
      },
      // El detalle necesita el paseo que se va a mostrar, asi que se construye
      // aparte para poder leer los argumentos de la navegacion.
      onGenerateRoute: (ajustes) {
        if (ajustes.name == Rutas.detalle) {
          final paseo = ajustes.arguments as Paseo;
          return MaterialPageRoute(
            builder: (_) => PantallaDetallePaseo(paseo: paseo),
          );
        }
        return null;
      },
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

/// Menu lateral compartido por las pantallas.
///
/// Vive aqui y no dentro de una pantalla porque lo usan varias: si estuviera en
/// la lista, el detalle tendria que importar la lista solo para reusar el menu.
class MenuLateral extends StatelessWidget {
  const MenuLateral({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: ColoresDogTrips.navy),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'DOGTRIPS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Safe Journeys, Happy Tails',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.pets),
            title: const Text('Mis paseos'),
            onTap: () {
              Navigator.pop(context); // cierra el menu antes de navegar
              Navigator.pushNamedAndRemoveUntil(
                context,
                Rutas.lista,
                (ruta) => false,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_a_photo_outlined),
            title: const Text('Registrar paseo'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, Rutas.nuevo);
            },
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
