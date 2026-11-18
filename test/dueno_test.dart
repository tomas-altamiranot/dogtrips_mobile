import 'package:dogtrips_mobile/datos/seguridad.dart';
import 'package:dogtrips_mobile/modelos/dueno.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dueno', () {
    test('ida y vuelta a SQLite conserva el nombre', () {
      const original = Dueno(nombre: 'Tomás Altamirano');
      final copia = Dueno.desdeMapa(original.aMapa());
      expect(copia.nombre, 'Tomás Altamirano');
      expect(copia.id, 1);
    });

    test('para saludar usa solo el primer nombre', () {
      const d = Dueno(nombre: '  Tomás Altamirano ');
      expect(d.primerNombre, 'Tomás');
      expect(d.inicial, 'T');
    });

    test('cambiar el nombre no borra el PIN', () {
      const conPin = Dueno(nombre: 'Tomás', pinHash: 'abc', pinSal: 'xyz');
      final renombrado = conPin.copiarCon(nombre: 'Tomás A.');
      expect(renombrado.pinHash, 'abc');
      expect(renombrado.tienePin, isTrue);
    });

    test('la preferencia de huella sobrevive el viaje a SQLite', () {
      const d = Dueno(
        nombre: 'T',
        pinHash: 'h',
        pinSal: 's',
        usaBiometria: true,
      );
      expect(Dueno.desdeMapa(d.aMapa()).usaBiometria, isTrue);
    });
  });

  group('PIN', () {
    Dueno conPin(String pin) {
      final p = Seguridad.protegerPin(pin);
      return Dueno(nombre: 'T', pinHash: p.hash, pinSal: p.sal);
    }

    test('el PIN correcto entra y uno incorrecto no', () {
      final d = conPin('1234');
      expect(Seguridad.pinCorrecto('1234', d), isTrue);
      expect(Seguridad.pinCorrecto('4321', d), isFalse);
    });

    test('nunca se guarda el PIN tal cual', () {
      final d = conPin('1234');
      expect(d.pinHash, isNot(contains('1234')));
    });

    test('el mismo PIN da hashes distintos gracias a la sal', () {
      // Si dos personas eligen 1234, sus hashes no se parecen en nada.
      expect(conPin('1234').pinHash, isNot(conPin('1234').pinHash));
    });

    test('sin PIN configurado nada entra', () {
      expect(Seguridad.pinCorrecto('1234', const Dueno(nombre: 'T')), isFalse);
    });
  });
}
