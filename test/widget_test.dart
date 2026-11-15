// Pruebas de la serializacion del modelo.
//
// Se prueba el modelo y no las pantallas porque es donde esta la logica que
// puede romperse en silencio: si aMapa() y desdeMapa() dejan de ser inversos,
// la app sigue compilando y los paseos se corrompen al guardarse.

import 'package:dogtrips_mobile/modelos/paseo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Paseo - ida y vuelta a SQLite', () {
    test('conserva todos los campos', () {
      final original = Paseo(
        id: 7,
        nombrePerro: 'Max',
        fecha: DateTime(2026, 11, 15, 9, 30),
        duracionMin: 45,
        notas: 'Se llevo bien con Nina',
        fotoPath: '/data/fotos/max.jpg',
        latitud: 20.9674,
        longitud: -89.5926,
      );

      final copia = Paseo.desdeMapa(original.aMapa());

      expect(copia.id, original.id);
      expect(copia.nombrePerro, original.nombrePerro);
      expect(copia.fecha, original.fecha);
      expect(copia.duracionMin, original.duracionMin);
      expect(copia.notas, original.notas);
      expect(copia.fotoPath, original.fotoPath);
      expect(copia.latitud, original.latitud);
      expect(copia.longitud, original.longitud);
    });

    test('un paseo sin foto ni ubicacion sobrevive el viaje', () {
      final sinExtras = Paseo(
        nombrePerro: 'Nina',
        fecha: DateTime(2026, 11, 14),
        duracionMin: 30,
      );

      final copia = Paseo.desdeMapa(sinExtras.aMapa());

      expect(copia.fotoPath, isNull);
      expect(copia.tieneFoto, isFalse);
      expect(copia.tieneUbicacion, isFalse);
      expect(copia.notas, '');
    });
  });

  group('Paseo - JSON', () {
    test('la fecha viaja en ISO-8601 y vuelve igual', () {
      final original = Paseo(
        nombrePerro: 'Toby',
        fecha: DateTime(2026, 11, 15, 18, 5),
        duracionMin: 60,
        latitud: 20.98,
        longitud: -89.62,
      );

      final copia = Paseo.desdeJson(original.aJson());

      expect(copia.fecha, original.fecha);
      expect(copia.latitud, original.latitud);
      expect(copia.nombrePerro, 'Toby');
    });

    test('sin ubicacion, el campo va nulo', () {
      final p = Paseo(
        nombrePerro: 'Luna',
        fecha: DateTime(2026, 11, 10),
        duracionMin: 20,
      );

      expect(p.aJson()['ubicacion'], isNull);
      expect(p.aJsonTexto(), contains('"perro": "Luna"'));
    });
  });
}
