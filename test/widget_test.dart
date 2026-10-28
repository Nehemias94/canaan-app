import 'package:flutter_test/flutter_test.dart'; // Herramientas de pruebas automáticas de Flutter

import 'package:canaan_app/main.dart'; // Nuestra app

void main() { // Punto de arranque de las pruebas
  testWidgets('La pantalla de inicio muestra el nombre Canaán', (WidgetTester tester) async { // Una prueba
    await tester.pumpWidget(const CanaanApp()); // Dibuja la app en una pantalla de prueba (invisible)

    expect(find.text('Canaán'), findsOneWidget); // Debe aparecer el título "Canaán" una vez
    expect(find.text('Ministerio Cristiano Canaán'), findsOneWidget); // Y el subtítulo
  }); // Fin de la prueba
} // Fin de main
