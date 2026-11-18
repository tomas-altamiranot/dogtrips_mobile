import 'package:material_ui/material_ui.dart';

import '../main.dart';
import '../modelos/mascota.dart';
import '../modelos/paseador.dart';

/// Lo que viaja del mapa al perfil, y del perfil a la reserva: el paseador y
/// los perros que el dueno ya habia elegido en el Inicio.
///
/// Una ruta solo recibe un argumento, asi que los dos datos van juntos en una
/// clase en vez de sueltos.
class ArgsPaseador {
  final Paseador paseador;
  final List<Mascota> elegidas;

  const ArgsPaseador({required this.paseador, this.elegidas = const []});
}

/// Perfil completo de un paseador. Responde la pregunta "¿puedo confiar en
/// esta persona?" antes de reservar.
class PantallaPerfilPaseador extends StatelessWidget {
  const PantallaPerfilPaseador({super.key, required this.args});

  final ArgsPaseador args;

  Paseador get _p => args.paseador;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_p.nombre)),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Encabezado ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            decoration: const BoxDecoration(
              color: ColoresDogTrips.navy,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Misma etiqueta que en la tarjeta del mapa: el circulo pequeno
                // "vuela" y crece hasta aqui.
                Hero(
                  tag: 'paseador-${_p.id}',
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: ColoresDogTrips.coral,
                    child: Text(
                      _p.nombre.characters.first,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _p.nombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_p.verificado) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, color: ColoresDogTrips.coral),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_p.zona} · ${_p.experienciaLegible}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          // ── Datos clave ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _Cifra(
                      valor: _p.calificacion.toStringAsFixed(1),
                      etiqueta: 'calificación',
                      icono: Icons.star,
                    ),
                    _Cifra(
                      valor: '${_p.paseosHechos}',
                      etiqueta: 'paseos',
                      icono: Icons.pets,
                    ),
                    _Cifra(
                      valor: '\$${_p.tarifaHora.toStringAsFixed(0)}',
                      etiqueta: 'por hora',
                      icono: Icons.payments_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Confianza ───────────────────────────────────────────────
                _Tarjeta(
                  icono: _p.verificado
                      ? Icons.verified_user_outlined
                      : Icons.hourglass_empty,
                  titulo: _p.verificado
                      ? 'Identidad verificada'
                      : 'Verificación en proceso',
                  texto: _p.verificado
                      ? 'DogTrips revisó sus documentos y sus antecedentes.'
                      : 'Todavía no termina la revisión de sus documentos.',
                ),
                const SizedBox(height: 20),

                const Text(
                  'Habilidades',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ColoresDogTrips.navy,
                  ),
                ),
                const SizedBox(height: 10),
                if (_p.habilidades.isEmpty)
                  const Text(
                    'Aún no registra habilidades especiales.',
                    style: TextStyle(color: Colors.black54),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final h in _p.habilidades)
                        Chip(
                          label: Text(h),
                          avatar: const Icon(
                            Icons.check,
                            size: 16,
                            color: ColoresDogTrips.coral,
                          ),
                          backgroundColor: Colors.white,
                        ),
                    ],
                  ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    Rutas.nuevaReserva,
                    arguments: args,
                  ),
                  icon: const Icon(Icons.event_available),
                  label: Text('Reservar con ${_p.nombre.split(' ').first}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.valor,
    required this.etiqueta,
    required this.icono,
  });

  final String valor;
  final String etiqueta;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icono, color: ColoresDogTrips.coral),
          const SizedBox(height: 4),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ColoresDogTrips.navy,
            ),
          ),
          Text(
            etiqueta,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.icono,
    required this.titulo,
    required this.texto,
  });

  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icono, color: ColoresDogTrips.navy, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(texto, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
