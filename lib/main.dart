import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import 'pantallas/principal.dart'; // Pantalla con el menú de abajo y las pestañas
import 'servicios/api.dart'; // Llamadas a la API del panel
import 'servicios/registro.dart'; // Registro del teléfono en el panel
import 'tema.dart'; // Colores y estilos de Canaán

void main() { // Punto de arranque: es lo primero que se ejecuta al abrir la app
  runApp(CanaanApp()); // Dibuja la app en la pantalla
} // Fin de main

class CanaanApp extends StatelessWidget { // La app completa
  CanaanApp({super.key, this.api = const Api(), RegistroDispositivo? registro}) // Constructor; por defecto la API real (en las pruebas, una falsa)
      : registro = registro ?? RegistroDispositivo(api: api); // Si no se pasa un registro, crea uno con esa API

  final Api api; // De dónde se sacan los datos
  final RegistroDispositivo registro; // Se encarga de registrar el teléfono

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve la app
    return MaterialApp( // Contenedor principal con el estilo Material de Google
      title: 'Canaán', // Nombre de la app (pestaña del navegador y lista de apps abiertas)
      debugShowCheckedModeBanner: false, // Quita la cinta roja "DEBUG"
      theme: temaCanaan(), // Colores y estilos de Canaán (lib/tema.dart)
      home: PantallaPrincipal(api: api, registro: registro), // Primera pantalla: la del menú de abajo
    ); // Fin de MaterialApp
  } // Fin de build
} // Fin de CanaanApp
