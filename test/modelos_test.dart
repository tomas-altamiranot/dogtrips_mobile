// Pruebas de los modelos y de la regla de negocio.
//
// Se prueban los modelos y no las pantallas porque aqui esta la logica que
// puede romperse en silencio: si aMapa() y desdeMapa() dejan de ser inversos,
// la app sigue compilando y los datos se corrompen al guardarse.

import 'package:dogtrips_mobile/modelos/mascota.dart';
import 'package:dogtrips_mobile/modelos/paseador.dart';
import 'package:dogtrips_mobile/modelos/reserva.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Mascota', () {
    test('ida y vuelta a SQLite conserva todos los campos', () {
      const original = Mascota(
        id: 3,
        nombre: 'Max',
        raza: 'Labrador',
        tamano: Tamano.grande,
        edadMeses: 27,
        fotoPath: '/data/fotos/max.jpg',
        notas: 'Jala mucho la correa',
      );

      final copia = Mascota.desdeMapa(original.aMapa());

      expect(copia.id, 3);
      expect(copia.nombre, 'Max');
      expect(copia.tamano, Tamano.grande);
      expect(copia.edadMeses, 27);
      expect(copia.fotoPath, '/data/fotos/max.jpg');
      expect(copia.notas, 'Jala mucho la correa');
    });

    test('un tamano desconocido no tumba la app', () {
      // Puede pasar con datos viejos o corruptos: debe caer a mediano, no
      // lanzar una excepcion que impida abrir la lista.
      expect(Tamano.desdeTexto('gigantesco'), Tamano.mediano);
      expect(Tamano.desdeTexto(null), Tamano.mediano);
    });

    test('la edad se muestra en lenguaje natural', () {
      Mascota conEdad(int m) => Mascota(
            nombre: 'x',
            raza: 'y',
            tamano: Tamano.mediano,
            edadMeses: m,
          );

      expect(conEdad(8).edadLegible, '8 meses');
      expect(conEdad(12).edadLegible, '1 ano');
      expect(conEdad(27).edadLegible, '2 anos y 3 meses');
    });
  });

  group('Paseador', () {
    test('la lista de habilidades y el booleano sobreviven el viaje', () {
      // SQLite no guarda listas ni booleanos: las habilidades van como texto
      // separado por "|" y verificado como 1 o 0. Esta prueba existe para
      // atrapar que esa conversion deje de ser reversible.
      const original = Paseador(
        id: 1,
        nombre: 'Ana Sosa',
        zona: 'Centro',
        latitud: 20.9674,
        longitud: -89.5926,
        calificacion: 4.8,
        paseosHechos: 142,
        tarifaHora: 120,
        experienciaMeses: 36,
        verificado: true,
        habilidades: ['Primeros auxilios', 'Maneja grupos'],
      );

      final copia = Paseador.desdeMapa(original.aMapa());

      expect(copia.verificado, isTrue);
      expect(copia.habilidades, ['Primeros auxilios', 'Maneja grupos']);
      expect(copia.latitud, closeTo(20.9674, 0.00001));
    });

    test('sin habilidades devuelve lista vacia, no una lista con texto vacio', () {
      const sinHabilidades = Paseador(
        nombre: 'Javier Ancona',
        zona: 'Temozon Norte',
        latitud: 21.064,
        longitud: -89.6,
        calificacion: 4.2,
        paseosHechos: 34,
        tarifaHora: 85,
        experienciaMeses: 8,
        verificado: false,
      );

      final copia = Paseador.desdeMapa(sinHabilidades.aMapa());

      expect(copia.habilidades, isEmpty);
      expect(copia.verificado, isFalse);
    });
  });

  group('Tarifa', () {
    // La formula viene del documento de requerimientos de 5.o semestre:
    // la tarifa depende de la duracion y de la complexion de la mascota.

    test('una hora con un perro pequeno cuesta la tarifa base', () {
      final costo = calcularCosto(
        tarifaHora: 100,
        tamano: Tamano.pequeno,
        duracionMin: 60,
      );
      expect(costo, 100);
    });

    test('media hora cuesta la mitad', () {
      final costo = calcularCosto(
        tarifaHora: 100,
        tamano: Tamano.pequeno,
        duracionMin: 30,
      );
      expect(costo, 50);
    });

    test('un perro grande encarece el paseo un 30%', () {
      final costo = calcularCosto(
        tarifaHora: 100,
        tamano: Tamano.grande,
        duracionMin: 60,
      );
      expect(costo, 130);
    });

    test('un perro mediano encarece un 15%', () {
      final costo = calcularCosto(
        tarifaHora: 120,
        tamano: Tamano.mediano,
        duracionMin: 60,
      );
      expect(costo, 138); // 120 * 1.15
    });

    test('el resultado no tiene centavos', () {
      final costo = calcularCosto(
        tarifaHora: 95,
        tamano: Tamano.mediano,
        duracionMin: 45,
      );
      // 95 * 0.75 * 1.15 = 81.9375  ->  82
      expect(costo, 82);
      expect(costo, costo.roundToDouble());
    });
  });

  group('Reserva', () {
    test('Reserva.nueva calcula el costo a partir de mascota y paseador', () {
      const mascota = Mascota(
        id: 1,
        nombre: 'Max',
        raza: 'Labrador',
        tamano: Tamano.grande,
        edadMeses: 24,
      );
      const paseador = Paseador(
        id: 2,
        nombre: 'Ana Sosa',
        zona: 'Centro',
        latitud: 20.9674,
        longitud: -89.5926,
        calificacion: 4.8,
        paseosHechos: 142,
        tarifaHora: 100,
        experienciaMeses: 36,
        verificado: true,
      );

      final reserva = Reserva.nueva(
        mascota: mascota,
        paseador: paseador,
        fechaHora: DateTime(2026, 11, 20, 9),
        duracionMin: 60,
      );

      expect(reserva.costoEstimado, 130); // 100 * 1h * 1.30
      expect(reserva.mascotaId, 1);
      expect(reserva.paseadorId, 2);
      expect(reserva.estado, EstadoReserva.pendiente);
    });

    test('ida y vuelta a SQLite conserva la fecha y el estado', () {
      final original = Reserva(
        id: 9,
        mascotaId: 1,
        paseadorId: 2,
        fechaHora: DateTime(2026, 11, 20, 9, 30),
        duracionMin: 45,
        instrucciones: 'Tiene miedo a las motos',
        estado: EstadoReserva.confirmada,
        costoEstimado: 86,
      );

      final copia = Reserva.desdeMapa(original.aMapa());

      expect(copia.fechaHora, DateTime(2026, 11, 20, 9, 30));
      expect(copia.estado, EstadoReserva.confirmada);
      expect(copia.instrucciones, 'Tiene miedo a las motos');
      expect(copia.costoEstimado, 86);
    });
  });
}
