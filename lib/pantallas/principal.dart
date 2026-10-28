import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../servicios/api.dart'; // Llamadas a la API (se pasa a cada pestaña)
import '../servicios/registro.dart'; // Registro del teléfono en el panel
import 'horario.dart'; // Pestaña Horario
import 'inicio.dart'; // Pestaña Inicio
import 'mas.dart'; // Pestaña Más
import 'predicas.dart'; // Pestaña Prédicas

class PantallaPrincipal extends StatefulWidget { // Pantalla con el menú de abajo y las 4 pestañas
  const PantallaPrincipal({super.key, required this.api, required this.registro}); // Constructor: recibe la API y el registro

  final Api api; // De dónde sacan los datos las pestañas
  final RegistroDispositivo registro; // Registro del teléfono (se arranca al abrir la app)

  @override // Reemplaza createState
  State<PantallaPrincipal> createState() => _PantallaPrincipalState(); // Crea el estado
} // Fin de PantallaPrincipal

class _PantallaPrincipalState extends State<PantallaPrincipal> { // Estado: recuerda qué pestaña está abierta
  int _pestana = 0; // Pestaña elegida (0 = Inicio, 1 = Prédicas, 2 = Horario, 3 = Más)

  @override // Reemplaza initState
  void initState() { // Se ejecuta una vez, al abrir la app
    super.initState(); // Lo de Flutter por defecto
    widget.registro.iniciar().catchError((_) {}); // Registra el teléfono en segundo plano (si falla, Más lo muestra y deja reintentar)
  } // Fin de initState

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Scaffold( // Estructura de la pantalla
      body: IndexedStack( // Muestra solo la pestaña elegida, pero MANTIENE las otras vivas (no se recargan al volver)
        index: _pestana, // Cuál mostrar
        children: [ // Las 4 pestañas, en el mismo orden que el menú
          PantallaInicio(api: widget.api, registro: widget.registro), // 0: Inicio
          PantallaPredicas(api: widget.api, registro: widget.registro), // 1: Prédicas
          PantallaHorario(api: widget.api), // 2: Horario
          PantallaMas(api: widget.api, registro: widget.registro), // 3: Más (peticiones de oración y estado del teléfono)
        ], // Fin de las pestañas
      ), // Fin de IndexedStack
      bottomNavigationBar: NavigationBar( // Menú de abajo (estilo Material 3)
        selectedIndex: _pestana, // Opción resaltada
        onDestinationSelected: (i) => setState(() => _pestana = i), // Al tocar una opción, cambia de pestaña y redibuja
        destinations: const [ // Opciones del menú
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'), // Casa (rellena si está elegida)
          NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library), label: 'Prédicas'), // Videos
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Horario'), // Calendario
          NavigationDestination(icon: Icon(Icons.menu), label: 'Más'), // Tres rayas
        ], // Fin de las opciones
      ), // Fin del menú
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de _PantallaPrincipalState
