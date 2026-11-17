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
  });
}
