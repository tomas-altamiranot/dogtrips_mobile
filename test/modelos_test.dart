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
      Mascota conEdad(int m) =>
          Mascota(nombre: 'x', raza: 'y', tamano: Tamano.mediano, edadMeses: m);

      expect(conEdad(8).edadLegible, '8 meses');
      expect(conEdad(12).edadLegible, '1 año');
      expect(conEdad(27).edadLegible, '2 años y 3 meses');
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

    test('las habilidades se guardan como JSON', () {
      const p = Paseador(
        nombre: 'Ana',
        zona: 'Centro',
        latitud: 0,
        longitud: 0,
        calificacion: 5,
        paseosHechos: 1,
        tarifaHora: 100,
        experienciaMeses: 1,
        verificado: true,
        habilidades: ['Primeros auxilios', 'Maneja grupos'],
      );
      expect(p.aMapa()['habilidades'], '["Primeros auxilios","Maneja grupos"]');
    });

    test('un JSON danado no tumba la app: devuelve lista vacia', () {
      final mapa = {
        'id': 1,
        'nombre': 'Ana',
        'zona': 'Centro',
        'latitud': 0.0,
        'longitud': 0.0,
        'calificacion': 5.0,
        'paseos_hechos': 1,
        'tarifa_hora': 100.0,
        'experiencia_meses': 1,
        'verificado': 1,
        'habilidades': '["sin cerrar',
      };
      expect(Paseador.desdeMapa(mapa).habilidades, isEmpty);
    });

    test(
      'sin habilidades devuelve lista vacia, no una lista con texto vacio',
      () {
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
      },
    );
  });

  group('Tarifa', () {
    // La formula viene del documento de requerimientos de 5.o semestre:
    // la tarifa depende de la duracion, la complexion y el numero de mascotas.

    double costo(List<Tamano> tamanos, {double tarifa = 100, int min = 60}) =>
        calcularCosto(tarifaHora: tarifa, tamanos: tamanos, duracionMin: min);

    test('una hora con un perro pequeno cuesta la tarifa base', () {
      expect(costo([Tamano.pequeno]), 100);
    });

    test('media hora cuesta la mitad', () {
      expect(costo([Tamano.pequeno], min: 30), 50);
    });

    test('un perro grande encarece el paseo un 30%', () {
      expect(costo([Tamano.grande]), 130);
    });

    test('un perro mediano encarece un 15%', () {
      expect(costo([Tamano.mediano], tarifa: 120), 138); // 120 * 1.15
    });

    test('el resultado no tiene centavos', () {
      // 95 * 0.75 * 1.15 = 81.9375  ->  82
      final c = costo([Tamano.mediano], tarifa: 95, min: 45);
      expect(c, 82);
      expect(c, c.roundToDouble());
    });

    test('el descuento por perro adicional es compuesto', () {
      // 100 + 90 + 81: cada perro paga el 90 % del anterior.
      expect(costo([Tamano.pequeno, Tamano.pequeno]), 190);
      expect(costo([Tamano.pequeno, Tamano.pequeno, Tamano.pequeno]), 271);
    });

    test('el mas grande paga completo, sin importar el orden', () {
      // Grande completo (130) + pequeno con 10 % menos (90) = 220.
      expect(costo([Tamano.grande, Tamano.pequeno]), 220);
      expect(costo([Tamano.pequeno, Tamano.grande]), 220);
    });
  });

  group('Reserva', () {
    test('Reserva.nueva calcula el costo con todos los perros', () {
      const max = Mascota(
        id: 1,
        nombre: 'Max',
        raza: 'Labrador',
        tamano: Tamano.grande,
        edadMeses: 24,
      );
      const luna = Mascota(
        id: 2,
        nombre: 'Luna',
        raza: 'Pug',
        tamano: Tamano.pequeno,
        edadMeses: 30,
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
        mascotas: [max, luna],
        paseador: paseador,
        fechaHora: DateTime(2026, 11, 20, 9),
        duracionMin: 60,
      );

      expect(reserva.costoEstimado, 220); // 130 + 100 * 0.9
      expect(reserva.paseadorId, 2);
      // Sin app del paseador, la reserva nace confirmada.
      expect(reserva.estado, EstadoReserva.confirmada);
    });

    test('solo se cancela lo activo que aun no empieza', () {
      Reserva con(EstadoReserva e, DateTime f) => Reserva(
        paseadorId: 1,
        fechaHora: f,
        duracionMin: 60,
        estado: e,
        costoEstimado: 100,
      );
      final manana = DateTime.now().add(const Duration(days: 1));
      final ayer = DateTime.now().subtract(const Duration(days: 1));

      expect(con(EstadoReserva.confirmada, manana).sePuedeCancelar, isTrue);
      expect(con(EstadoReserva.confirmada, ayer).sePuedeCancelar, isFalse);
      expect(con(EstadoReserva.cancelada, manana).sePuedeCancelar, isFalse);
    });

    test('ida y vuelta a SQLite conserva la fecha y el estado', () {
      final original = Reserva(
        id: 9,
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
