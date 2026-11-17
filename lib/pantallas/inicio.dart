import 'package:material_ui/material_ui.dart';

import '../main.dart';

/// Pantalla de presentacion. Es lo primero que ve el usuario.
///
/// Deliberadamente NO abre el mapa: la app se presenta primero, y el usuario
/// decide a donde ir. Abrir directo en el mapa daria la sensacion de haber
/// entrado a mitad de algo.
class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DogTrips')),
      drawer: const MenuLateral(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          children: [
            // ── Presentacion ──────────────────────────────────────────────
            Center(
              child: Image.asset(
                'assets/imagenes/logo.png',
                height: 180,
                errorBuilder: (_, _, _) => const Column(
                  children: [
                    Icon(Icons.pets, size: 90, color: ColoresDogTrips.navy),
                    SizedBox(height: 10),
                    Text(
                      'DOGTRIPS',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 5,
                        color: ColoresDogTrips.navy,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Safe Journeys, Happy Tails',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ColoresDogTrips.coral,
                fontSize: 14,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 36),
            const Text(
              'Encuentra a alguien de confianza\npara pasear a tu perro',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: ColoresDogTrips.navy,
              ),
            ),
            const SizedBox(height: 28),

            // ── Accion principal ──────────────────────────────────────────
            _BotonPrincipal(
              icono: Icons.map_outlined,
              titulo: 'Encuentra tu paseador',
              detalle: 'Ve quien trabaja cerca de ti',
              alTocar: () => Navigator.pushNamed(context, Rutas.mapa),
            ),
            const SizedBox(height: 26),

            // ── Accesos secundarios ───────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _BotonSecundario(
                    icono: Icons.pets_outlined,
                    titulo: 'Mis mascotas',
                    alTocar: () =>
                        Navigator.pushNamed(context, Rutas.misMascotas),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BotonSecundario(
                    icono: Icons.event_note_outlined,
                    titulo: 'Mis reservas',
                    alTocar: () =>
                        Navigator.pushNamed(context, Rutas.misReservas),
                  ),
                ),
              ],
            ),
          ],
        ),
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
