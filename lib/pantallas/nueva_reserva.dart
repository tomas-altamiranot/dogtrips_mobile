import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../datos/base_datos.dart';
import '../main.dart';
import '../modelos/mascota.dart';
import '../modelos/reserva.dart';
import 'avatar_mascota.dart';
import 'perfil_paseador.dart';

/// Formulario para reservar un paseo con un paseador.
///
/// El dueno elige que perros van, el dia, la hora y la duracion, y ve el costo
/// calculado en vivo antes de confirmar.
class PantallaNuevaReserva extends StatefulWidget {
  const PantallaNuevaReserva({super.key, required this.args});

  final ArgsPaseador args;

  @override
  State<PantallaNuevaReserva> createState() => _PantallaNuevaReservaState();
}

class _PantallaNuevaReservaState extends State<PantallaNuevaReserva> {
  late Future<List<Mascota>> _futuro;

  /// Ids de los perros que van al paseo.
  late final Set<int> _seleccion = {
    for (final m in widget.args.elegidas) m.id!,
  };

  DateTime? _dia;
  TimeOfDay? _hora;
  int _duracion = 60;
  final _instrucciones = TextEditingController();
  bool _guardando = false;

  // ── Dictado ──────────────────────────────────────────────────────────────
  final _voz = SpeechToText();
  bool _escuchando = false;

  /// Lo que ya estaba escrito antes de empezar a dictar. El dictado se agrega
  /// despues de esto en vez de reemplazarlo.
  String _textoPrevio = '';

  Future<void> _alternarDictado() async {
    if (_escuchando) {
      await _voz.stop();
      if (mounted) setState(() => _escuchando = false);
      return;
    }

    // initialize() pide el permiso del microfono la primera vez. Devuelve
    // false si el usuario lo nego o si el telefono no tiene reconocedor.
    final disponible = await _voz.initialize(
      onStatus: (estado) {
        // "done" / "notListening": el usuario dejo de hablar y el
        // reconocedor se apago solo.
        if (estado != 'listening' && mounted) {
          setState(() => _escuchando = false);
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _escuchando = false);
        // error_no_match: hablo pero no se entendio nada. No es grave.
        if (error.errorMsg != 'error_no_match') {
          _avisar('No se pudo reconocer la voz. Intenta de nuevo.');
        }
      },
    );
    if (!mounted) return;

    if (!disponible) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('DogTrips no tiene permiso para usar el micrófono.'),
          action: SnackBarAction(
            label: 'Ajustes',
            // Ya negado, la app no puede volver a preguntar: solo el usuario
            // puede activarlo desde los ajustes del telefono.
            onPressed: Geolocator.openAppSettings,
          ),
        ),
      );
      return;
    }

    _textoPrevio = _instrucciones.text.trim();
    setState(() => _escuchando = true);
    await _voz.listen(
      // Resultados parciales: el texto aparece mientras el usuario habla, no
      // hasta que termina. es_MX: espanol de Mexico.
      listenOptions: SpeechListenOptions(
        partialResults: true,
        localeId: 'es_MX',
      ),
      onResult: (resultado) {
        final dictado = resultado.recognizedWords;
        _instrucciones.text = _textoPrevio.isEmpty
            ? dictado
            : '$_textoPrevio $dictado';
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _futuro = BaseDatos.instancia.listarMascotas();
  }

  @override
  void dispose() {
    // Si el usuario sale mientras dicta, se apaga el microfono.
    _voz.cancel();
    _instrucciones.dispose();
    super.dispose();
  }

  /// Dia y hora juntos. Null mientras falte alguno de los dos.
  DateTime? get _fechaHora {
    if (_dia == null || _hora == null) return null;
    return DateTime(
      _dia!.year,
      _dia!.month,
      _dia!.day,
      _hora!.hour,
      _hora!.minute,
    );
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _elegirDia() async {
    final hoy = DateTime.now();
    final dia = await showDatePicker(
      context: context,
      // firstDate = hoy: el calendario ni siquiera deja tocar dias pasados.
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: hoy.add(const Duration(days: 60)),
      initialDate: _dia ?? hoy,
    );
    if (dia != null) setState(() => _dia = dia);
  }

  Future<void> _elegirHora() async {
    final hora = await showTimePicker(
      context: context,
      initialTime:
          _hora ?? TimeOfDay(hour: (TimeOfDay.now().hour + 1) % 24, minute: 0),
    );
    if (hora != null) setState(() => _hora = hora);
  }

  Future<void> _confirmar(List<Mascota> todas) async {
    final perros = todas.where((m) => _seleccion.contains(m.id)).toList();
    final fecha = _fechaHora;

    // Validaciones, de la mas basica a la mas especifica.
    if (perros.isEmpty) return _avisar('Elige al menos un perro.');
    if (fecha == null) return _avisar('Elige el día y la hora del paseo.');
    // El calendario ya impide dias pasados, pero hoy a una hora que ya paso
    // si se puede elegir: por eso se revisa la fecha completa.
    if (!fecha.isAfter(DateTime.now())) {
      return _avisar('Esa hora ya pasó. Elige una hora futura.');
    }

    setState(() => _guardando = true);
    try {
      final reserva = Reserva.nueva(
        mascotas: perros,
        paseador: widget.args.paseador,
        fechaHora: fecha,
        duracionMin: _duracion,
        instrucciones: _instrucciones.text.trim(),
      );
      await BaseDatos.instancia.insertarReserva(reserva, perros);
      if (!mounted) return;

      _avisar('¡Listo! Tu paseo quedó confirmado.');
      // Se regresa al Inicio y desde ahi se abre Mis reservas: asi el boton de
      // atras no vuelve a un formulario que ya se envio.
      Navigator.pushNamedAndRemoveUntil(
        context,
        Rutas.misReservas,
        ModalRoute.withName(Rutas.inicio),
      );
    } on ErrorDeDatos catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _avisar(e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.args.paseador;
    return Scaffold(
      appBar: AppBar(title: Text('Reservar con ${p.nombre.split(' ').first}')),
      body: FutureBuilder<List<Mascota>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final todas = snapshot.data!;
          if (todas.isEmpty) return const _SinPerros();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const _Titulo('¿Quién va al paseo?'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in todas)
                    ChipMascota(
                      mascota: m,
                      elegida: _seleccion.contains(m.id),
                      alCambiar: (si) => setState(() {
                        si ? _seleccion.add(m.id!) : _seleccion.remove(m.id);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const _Titulo('¿Cuándo?'),
              Row(
                children: [
                  Expanded(
                    child: _Selector(
                      icono: Icons.calendar_today_outlined,
                      texto: _dia == null
                          ? 'Elegir día'
                          : DateFormat("EEE d 'de' MMM", 'es').format(_dia!),
                      alTocar: _elegirDia,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Selector(
                      icono: Icons.schedule,
                      texto: _hora == null
                          ? 'Elegir hora'
                          : _hora!.format(context),
                      alTocar: _elegirHora,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _Titulo('¿Cuánto tiempo?'),
              SegmentedButton<int>(
                segments: [
                  for (final d in duracionesPermitidas)
                    ButtonSegment(value: d, label: Text('$d min')),
                ],
                selected: {_duracion},
                onSelectionChanged: (s) => setState(() => _duracion = s.first),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _instrucciones,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Instrucciones para el paseador (opcional)',
                  hintText: _escuchando
                      ? 'Te escucho...'
                      : 'Escribe o toca el micrófono para dictar',
                  alignLabelWithHint: true,
                  suffixIcon: IconButton(
                    tooltip: _escuchando ? 'Dejar de dictar' : 'Dictar',
                    onPressed: _alternarDictado,
                    icon: Icon(
                      _escuchando ? Icons.stop_circle : Icons.mic_none,
                      color: _escuchando ? Colors.red.shade700 : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _Desglose(
                perros: todas.where((m) => _seleccion.contains(m.id)).toList(),
                tarifaHora: p.tarifaHora,
                duracionMin: _duracion,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _guardando ? null : () => _confirmar(todas),
                child: _guardando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirmar paseo'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Cuanto paga cada perro y el total. Se recalcula en cada cambio del
/// formulario, asi el dueno ve el precio antes de confirmar.
class _Desglose extends StatelessWidget {
  const _Desglose({
    required this.perros,
    required this.tarifaHora,
    required this.duracionMin,
  });

  final List<Mascota> perros;
  final double tarifaHora;
  final int duracionMin;

  @override
  Widget build(BuildContext context) {
    if (perros.isEmpty) return const SizedBox.shrink();

    // Mismo orden que usa costoPorPerro (del mas grande al mas chico), para
    // que cada nombre quede junto a su precio.
    final ordenados = [...perros]
      ..sort((a, b) => b.tamano.factorTarifa.compareTo(a.tamano.factorTarifa));
    final costos = costoPorPerro(
      tarifaHora: tarifaHora,
      tamanos: [for (final m in ordenados) m.tamano],
      duracionMin: duracionMin,
    );
    final total = calcularCosto(
      tarifaHora: tarifaHora,
      tamanos: [for (final m in ordenados) m.tamano],
      duracionMin: duracionMin,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < ordenados.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text('${ordenados[i].nombre} '),
                  Text(
                    '(${ordenados[i].tamano.etiqueta})',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  if (i > 0) ...[
                    const SizedBox(width: 6),
                    // Descuento compuesto: 1 - 0.9^i. El 2.o perro (i = 1)
                    // tiene 10 %, el 3.o (i = 2) 19 %, el 4.o 27 %...
                    Text(
                      '−${(100 * (1 - math.pow(factorPerroAdicional, i))).round()} %',
                      style: const TextStyle(
                        color: ColoresDogTrips.coral,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text('\$${costos[i].toStringAsFixed(2)}'),
                ],
              ),
            ),
          const Divider(),
          Row(
            children: [
              Text(
                'Total · $duracionMin min',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '\$${total.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: ColoresDogTrips.navy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: ColoresDogTrips.navy,
        ),
      ),
    );
  }
}

class _Selector extends StatelessWidget {
  const _Selector({
    required this.icono,
    required this.texto,
    required this.alTocar,
  });

  final IconData icono;
  final String texto;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: alTocar,
      icon: Icon(icono, size: 18),
      label: Text(texto),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}

/// Si el dueno llega aqui sin perros registrados (por ejemplo, entrando al
/// mapa desde el menu), se le manda a registrar uno.
class _SinPerros extends StatelessWidget {
  const _SinPerros();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pets, size: 52, color: ColoresDogTrips.coral),
            const SizedBox(height: 12),
            const Text(
              'Para reservar, primero registra a tu perro.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, Rutas.formMascota),
              child: const Text('Registrar a mi perro'),
            ),
          ],
        ),
      ),
    );
  }
}
