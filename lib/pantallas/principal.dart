import 'package:firebase_messaging/firebase_messaging.dart'; // RemoteMessage (una notificación recibida)
import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../servicios/api.dart'; // Llamadas a la API (se pasa a cada pestaña)
import '../servicios/notificaciones.dart'; // Notificaciones (Firebase)
import '../servicios/registro.dart'; // Registro del teléfono en el panel
import 'biblia.dart'; // Pestaña Biblia (YouVersion, Reina-Valera 1960)
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
  int _pestana = 0; // Pestaña elegida (0 = Inicio, 1 = Prédicas, 2 = Biblia, 3 = Horario, 4 = Más)

  @override // Reemplaza initState
  void initState() { // Se ejecuta una vez, al abrir la app
    super.initState(); // Lo de Flutter por defecto
    widget.registro.iniciar().then((_) => ServicioNotificaciones.iniciar( // Registra el teléfono en segundo plano y, al terminar, activa las notificaciones
          api: widget.api, // API
          registro: widget.registro, // Registro
          alRecibir: _mostrarNotificacion, // Llega con la app abierta: aviso abajo
          alTocar: (_) => _irAInicio(), // La tocó: abre Inicio
        )).catchError((_) {}); // Si falla el registro, Más lo muestra y deja reintentar (las notificaciones se activarán la próxima vez)
  } // Fin de initState

  void _irAInicio() { // Cambia a la pestaña Inicio (ahí se ven el en vivo, el aviso urgente y los anuncios)
    if (mounted) setState(() => _pestana = 0); // Pestaña 0 = Inicio
  } // Fin de _irAInicio

  void _mostrarNotificacion(RemoteMessage mensaje) { // Con la app abierta, el teléfono NO muestra la notificación: la mostramos nosotros
    if (!mounted) return; // Si la pantalla ya no existe, nada
    final titulo = mensaje.notification?.title ?? 'Canaán'; // Título (o el nombre de la app)
    final texto = mensaje.notification?.body ?? ''; // Texto
    ScaffoldMessenger.of(context).showSnackBar(SnackBar( // Barra de aviso abajo
      content: Text(texto.isEmpty ? titulo : '$titulo\n$texto'), // Título y texto en dos líneas
      duration: const Duration(seconds: 8), // Visible 8 segundos
      action: SnackBarAction(label: 'Ver', onPressed: _irAInicio), // Botón "Ver" → Inicio
    )); // Fin del aviso
  } // Fin de _mostrarNotificacion

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Scaffold( // Estructura de la pantalla
      body: IndexedStack( // Muestra solo la pestaña elegida, pero MANTIENE las otras vivas (no se recargan al volver)
        index: _pestana, // Cuál mostrar
        children: [ // Las 5 pestañas, en el mismo orden que el menú
          PantallaInicio(api: widget.api, registro: widget.registro), // 0: Inicio
          PantallaPredicas(api: widget.api, registro: widget.registro), // 1: Prédicas
          const PantallaBiblia(), // 2: Biblia
          PantallaHorario(api: widget.api), // 3: Horario
          PantallaMas(api: widget.api, registro: widget.registro), // 4: Más (peticiones de oración y estado del teléfono)
        ], // Fin de las pestañas
      ), // Fin de IndexedStack
      bottomNavigationBar: NavigationBar( // Menú de abajo (estilo Material 3)
        selectedIndex: _pestana, // Opción resaltada
        onDestinationSelected: (i) => setState(() => _pestana = i), // Al tocar una opción, cambia de pestaña y redibuja
        destinations: const [ // Opciones del menú
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'), // Casa (rellena si está elegida)
          NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library), label: 'Prédicas'), // Videos
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Biblia'), // Libro abierto
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Horario'), // Calendario
          NavigationDestination(icon: Icon(Icons.menu), label: 'Más'), // Tres rayas
        ], // Fin de las opciones
      ), // Fin del menú
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de _PantallaPrincipalState
