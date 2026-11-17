import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../datos/base_datos.dart';
import '../main.dart';
import '../modelos/paseador.dart';

/// Centro de Merida. Se usa cuando no hay permiso de ubicacion o el GPS falla.
///
/// Es mejor mostrar el mapa en un lugar razonable que no mostrarlo: el usuario
/// puede moverlo con el dedo, y la app sigue siendo util sin GPS.
const _meridaCentro = LatLng(20.9671, -89.6237); // Plaza Grande

/// Radio del area "cerca de ti". Los paseadores dentro se resaltan; los de
/// fuera se muestran tenues, por si el dueno prefiere a alguien mas lejos.
const _radioZonaKm = 5.0;

/// Mas alla de esta distancia de Merida, DogTrips no opera. Pasa, por ejemplo,
/// en el emulador, cuya ubicacion de fabrica esta en Estados Unidos.
const _radioCoberturaKm = 40.0;

/// Lo que la pantalla necesita para dibujarse: donde esta el usuario y quienes
/// son los paseadores, separados por si caen o no dentro de su area.
class _DatosMapa {
  final LatLng centro;
  final bool ubicacionReal;
  final String? avisoUbicacion;
  final List<Paseador> enZona;
  final List<Paseador> fueraDeZona;

  const _DatosMapa({
    required this.centro,
    required this.ubicacionReal,
    this.avisoUbicacion,
    required this.enZona,
    required this.fueraDeZona,
  });
}

class PantallaMapaPaseadores extends StatefulWidget {
  const PantallaMapaPaseadores({super.key});

  @override
  State<PantallaMapaPaseadores> createState() => _PantallaMapaPaseadoresState();
}

class _PantallaMapaPaseadoresState extends State<PantallaMapaPaseadores> {
  /// El Future se guarda aqui y NO se crea en build(). build() se ejecuta en
  /// cada repintado: si el Future naciera ahi, el GPS se consultaria una y otra
  /// vez y el mapa parpadearia sin parar.
  late Future<_DatosMapa> _futuro;

  final _controlMapa = MapController();

  @override
  void initState() {
    super.initState();
    _futuro = _cargar();
  }

  Future<_DatosMapa> _cargar() async {
    final ubicacion = await _ubicacionActual();
    var punto = ubicacion.punto;
    var aviso = ubicacion.aviso;

    // Tener la ubicacion no basta: si el usuario esta lejos de Merida, centrar
    // el mapa en el mostraria un mapa vacio. Mejor decirlo y mostrar Merida.
    if (punto != null && _kmEntre(punto, _meridaCentro) > _radioCoberturaKm) {
      punto = null;
      aviso = 'DogTrips aun no opera en tu zona.';
    }

    final centro = punto ?? _meridaCentro;
    final paseadores = await BaseDatos.instancia.paseadoresCercaDe(
      centro.latitude,
      centro.longitude,
    );

    // La lista ya viene ordenada por cercania; aqui solo se parte en dos.
    bool dentro(Paseador pas) =>
        _kmEntre(centro, LatLng(pas.latitud, pas.longitud)) <= _radioZonaKm;

    return _DatosMapa(
      centro: centro,
      ubicacionReal: punto != null,
      avisoUbicacion: aviso,
      enZona: paseadores.where(dentro).toList(),
      fueraDeZona: paseadores.where((pas) => !dentro(pas)).toList(),
    );
  }

  double _kmEntre(LatLng a, LatLng b) =>
      BaseDatos.distanciaKm(a.latitude, a.longitude, b.latitude, b.longitude);

  /// Obtiene la ubicacion del telefono.
  ///
  /// Devuelve siempre, nunca lanza: los tres modos de fallo se traducen a un
  /// aviso legible. Es la diferencia entre una app que explica que paso y una
  /// que se queda cargando para siempre.
  Future<({LatLng? punto, String? aviso})> _ubicacionActual() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return (punto: null, aviso: 'La ubicacion del telefono esta apagada.');
      }

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.deniedForever) {
        return (
          punto: null,
          aviso: 'Permiso de ubicacion bloqueado. Actívalo en los ajustes.'
        );
      }
      if (permiso == LocationPermission.denied) {
        return (punto: null, aviso: 'Sin permiso de ubicacion.');
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          // Sin limite, un GPS sin senal deja la pantalla colgada para siempre.
          timeLimit: Duration(seconds: 15),
        ),
      );
      return (punto: LatLng(pos.latitude, pos.longitude), aviso: null);
    } catch (_) {
      return (punto: null, aviso: 'No se pudo obtener tu ubicacion.');
    }
  }

  void _recargar() => setState(() => _futuro = _cargar());

  void _mostrarPaseador(Paseador pas, LatLng centro) {
    final km = BaseDatos.distanciaKm(
      centro.latitude,
      centro.longitude,
      pas.latitud,
      pas.longitud,
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (hoja) => _ResumenPaseador(paseador: pas, distanciaKm: km),
    );
  }

  Marker _marcador(Paseador pas, LatLng centro, {required bool enZona}) {
    return Marker(
      point: LatLng(pas.latitud, pas.longitud),
      width: 46,
      height: 52,
      // El pin apunta hacia abajo: su punta debe caer en la coordenada, no
      // su centro.
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => _mostrarPaseador(pas, centro),
        child: Opacity(
          opacity: enZona ? 1.0 : 0.45,
          child: _PinPaseador(paseador: pas),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paseadores cerca de ti'),
        actions: [
          IconButton(
            tooltip: 'Actualizar ubicacion',
            icon: const Icon(Icons.my_location),
            onPressed: _recargar,
          ),
        ],
      ),
      drawer: const MenuLateral(),
      body: FutureBuilder<_DatosMapa>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text('Buscando tu ubicacion...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 52),
                    const SizedBox(height: 12),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 14),
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
          return Column(
            children: [
              if (datos.avisoUbicacion != null)
                _BarraAviso(texto: datos.avisoUbicacion!),
              Expanded(
                child: FlutterMap(
                  mapController: _controlMapa,
                  options: MapOptions(
                    initialCenter: datos.centro,
                    // A este zoom el circulo de 5 km cabe completo en pantalla.
                    initialZoom: 12.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      // OpenStreetMap pide identificarse. Sin esto, su politica
                      // de uso permite bloquear las peticiones.
                      userAgentPackageName: 'com.dogtrips.dogtrips_mobile',
                      maxNativeZoom: 19,
                    ),
                    // El area "cerca de ti", en metros reales: crece y se
                    // encoge con el zoom igual que las calles.
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: datos.centro,
                          radius: _radioZonaKm * 1000,
                          useRadiusInMeter: true,
                          color: ColoresDogTrips.coral.withValues(alpha: 0.10),
                          borderColor: ColoresDogTrips.coral,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        // El usuario, solo si la ubicacion es real.
                        if (datos.ubicacionReal)
                          Marker(
                            point: datos.centro,
                            width: 26,
                            height: 26,
                            child: const _PuntoUsuario(),
                          ),
                        // Un pin por paseador. Los de fuera van primero para
                        // que, si se enciman, los de dentro queden encima.
                        for (final pas in datos.fueraDeZona)
                          _marcador(pas, datos.centro, enZona: false),
                        for (final pas in datos.enZona)
                          _marcador(pas, datos.centro, enZona: true),
                      ],
                    ),
                  ],
                ),
              ),
              _BarraResumen(
                enZona: datos.enZona.length,
                fueraDeZona: datos.fueraDeZona.length,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PuntoUsuario extends StatelessWidget {
  const _PuntoUsuario();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
        ],
      ),
    );
  }
}

class _PinPaseador extends StatelessWidget {
  const _PinPaseador({required this.paseador});

  final Paseador paseador;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: ColoresDogTrips.navy,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            paseador.calificacion.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Icon(
          Icons.place,
          size: 32,
          color: paseador.verificado
              ? ColoresDogTrips.coral
              : ColoresDogTrips.navy.withValues(alpha: 0.45),
        ),
      ],
    );
  }
}

class _BarraAviso extends StatelessWidget {
  const _BarraAviso({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: ColoresDogTrips.coral.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: ColoresDogTrips.coral),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$texto Mostrando el centro de Merida.',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraResumen extends StatelessWidget {
  const _BarraResumen({required this.enZona, required this.fueraDeZona});

  final int enZona;
  final int fueraDeZona;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.place, size: 18, color: ColoresDogTrips.coral),
          const SizedBox(width: 8),
          Text(
            '$enZona en tu zona',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            '  ·  $fueraDeZona mas lejos',
            style: const TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
          const Spacer(),
          const Text(
            'Toca un pin',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta que aparece al tocar un pin.
class _ResumenPaseador extends StatelessWidget {
  const _ResumenPaseador({required this.paseador, required this.distanciaKm});

  final Paseador paseador;
  final double distanciaKm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                // Misma etiqueta Hero que en el perfil: la foto crece al abrir.
                Hero(
                  tag: 'paseador-${paseador.id}',
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: ColoresDogTrips.navy,
                    child: Text(
                      paseador.nombre.characters.first,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              paseador.nombre,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (paseador.verificado) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified,
                                size: 16, color: ColoresDogTrips.coral),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${paseador.zona}  ·  a ${distanciaKm.toStringAsFixed(1)} km',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Dato(
                  icono: Icons.star,
                  valor: paseador.calificacion.toStringAsFixed(1),
                  etiqueta: '${paseador.paseosHechos} paseos',
                ),
                _Dato(
                  icono: Icons.payments_outlined,
                  valor: '\$${paseador.tarifaHora.toStringAsFixed(0)}',
                  etiqueta: 'por hora',
                ),
                _Dato(
                  icono: Icons.workspace_premium_outlined,
                  valor: '${paseador.experienciaMeses ~/ 12}',
                  etiqueta: 'anos de exp.',
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context); // cierra la hoja
                  Navigator.pushNamed(
                    context,
                    Rutas.perfilPaseador,
                    arguments: paseador,
                  );
                },
                icon: const Icon(Icons.person_outline),
                label: const Text('Ver perfil completo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.icono,
    required this.valor,
    required this.etiqueta,
  });

  final IconData icono;
  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icono, size: 19, color: ColoresDogTrips.coral),
          const SizedBox(height: 5),
          Text(valor,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(etiqueta,
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }
}
