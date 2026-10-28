import 'package:flutter/material.dart'; // Componentes visuales (para buscar íconos y textos)
import 'package:flutter_test/flutter_test.dart'; // Herramientas de pruebas automáticas de Flutter

import 'package:canaan_app/main.dart'; // Nuestra app
import 'package:canaan_app/modelos/actividad.dart'; // Molde de una actividad
import 'package:canaan_app/modelos/iglesia.dart'; // Molde de los datos de la iglesia
import 'package:canaan_app/modelos/predica.dart'; // Molde de una prédica
import 'package:canaan_app/servicios/api.dart'; // La API real (de ella se hereda la falsa)

class ApiFalsa extends Api { // API de mentira: responde datos fijos sin usar internet
  const ApiFalsa({this.falla = false}); // Constructor; falla = true simula que no hay conexión

  final bool falla; // ¿Simular error?

  @override // Reemplaza el método real
  Future<Iglesia> obtenerIglesia() async { // Datos falsos de la iglesia
    if (falla) throw Exception('sin internet'); // Simula el error
    return Iglesia.desdeJson({ // JSON igual al de la API
      'nombre': 'Ministerio Cristiano Canaán', // Nombre
      'en_vivo': {'activo': true, 'titulo': 'Culto dominical'}, // Transmisión activa
    }); // Fin de los datos
  } // Fin de obtenerIglesia

  @override // Reemplaza el método real
  Future<List<Predica>> obtenerPredicas({String buscar = ''}) async { // Prédicas falsas
    if (falla) throw Exception('sin internet'); // Simula el error
    return [Predica.desdeJson({'id': 1, 'titulo': 'La fe que mueve montañas', 'predicador': 'Pastor Juan', 'fecha': '2026-10-05', 'destacada': true})]; // Una prédica destacada
  } // Fin de obtenerPredicas

  @override // Reemplaza el método real
  Future<List<Actividad>> obtenerActividades() async { // Horario falso
    if (falla) throw Exception('sin internet'); // Simula el error
    return [Actividad.desdeJson({'id': 1, 'nombre': 'Culto general', 'dia_semana': 0, 'dia': 'Domingo', 'horario': '10:00 am – 12:00 pm', 'se_transmite': true, 'en_curso': true})]; // Un culto el domingo, en curso
  } // Fin de obtenerActividades
} // Fin de ApiFalsa

void main() { // Punto de arranque de las pruebas
  testWidgets('Inicio muestra el nombre y EN VIVO', (WidgetTester tester) async { // Prueba 1
    await tester.pumpWidget(const CanaanApp(api: ApiFalsa())); // Dibuja la app con la API falsa
    expect(find.text('Conectando…'), findsWidgets); // Primero sale "Conectando…" (en las pestañas que cargan)
    await tester.pumpAndSettle(); // Espera a que lleguen los datos y se redibuje
    expect(find.text('Ministerio Cristiano Canaán'), findsOneWidget); // Sale el nombre
    expect(find.text('● EN VIVO · Culto dominical'), findsOneWidget); // Sale la etiqueta EN VIVO
  }); // Fin de la prueba 1

  testWidgets('El menú cambia a Prédicas y a Horario', (WidgetTester tester) async { // Prueba 2
    await tester.pumpWidget(const CanaanApp(api: ApiFalsa())); // Dibuja la app
    await tester.pumpAndSettle(); // Espera los datos
    await tester.tap(find.text('Prédicas')); // Toca "Prédicas" en el menú de abajo
    await tester.pumpAndSettle(); // Espera el cambio
    expect(find.text('La fe que mueve montañas'), findsOneWidget); // Sale la prédica
    expect(find.text('★ DESTACADA'), findsOneWidget); // Con la etiqueta de destacada
    expect(find.text('Pastor Juan · 5 oct 2026'), findsOneWidget); // Predicador y fecha en español
    await tester.tap(find.text('Horario')); // Toca "Horario"
    await tester.pumpAndSettle(); // Espera el cambio
    expect(find.text('DOMINGO'), findsOneWidget); // Encabezado del día
    expect(find.text('Culto general'), findsOneWidget); // La actividad
    expect(find.text('Ahora'), findsOneWidget); // Marcada como en curso
    expect(find.byIcon(Icons.live_tv), findsOneWidget); // Con el ícono de transmisión
  }); // Fin de la prueba 2

  testWidgets('Muestra Reintentar si no hay conexión', (WidgetTester tester) async { // Prueba 3
    await tester.pumpWidget(const CanaanApp(api: ApiFalsa(falla: true))); // Dibuja la app con una API que falla
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Reintentar'), findsWidgets); // Sale el botón Reintentar
  }); // Fin de la prueba 3
} // Fin de main
