import 'package:firebase_messaging/firebase_messaging.dart'; // RemoteMessage (una notificación recibida)
import 'package:flutter/material.dart'; // Componentes visuales de Flutter
import 'package:flutter/services.dart'; // SystemNavigator (salir de la app con el botón atrás)

import '../componentes/carga_animada.dart'; // presentacionEnCurso: ocultar el menú mientras se ve el logo animado
import '../servicios/api.dart'; // Llamadas a la API (se pasa a cada pestaña)
import '../servicios/conexion.dart'; // Franja "Sin conexión"
import '../servicios/notificaciones.dart'; // Notificaciones (Firebase)
import '../servicios/recarga.dart'; // Timbre para actualizar la pestaña Eventos
import '../servicios/servicios_app.dart'; // API y registro al alcance de todas las pantallas
import '../servicios/registro.dart'; // Registro del teléfono en el panel
import 'biblia.dart'; // Pestaña Biblia (YouVersion, Reina-Valera 1960)
import 'eventos.dart'; // Pestaña Eventos (eventos especiales)
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
  int _pestana = 0; // Pestaña elegida (0 = Inicio, 1 = Prédicas, 2 = Biblia, 3 = Eventos, 4 = Servicios)
  final _pilas = List.generate(5, (_) => GlobalKey<NavigatorState>()); // Una "pila" de pantallas por pestaña: lo que se abre desde una pestaña se queda dentro de ella y el menú de abajo SIEMPRE se ve

  @override // Reemplaza initState
  void initState() { // Se ejecuta una vez, al abrir la app
    super.initState(); // Lo de Flutter por defecto
    ServiciosApp.api = widget.api; // API al alcance de todas las pantallas (eventos: 🔔 e inscripciones)
    ServiciosApp.registro = widget.registro; // Llave del teléfono, igual
    widget.registro.iniciar().then((_) => ServicioNotificaciones.iniciar( // Registra el teléfono en segundo plano y, al terminar, activa las notificaciones
          api: widget.api, // API
          registro: widget.registro, // Registro
          alRecibir: _mostrarNotificacion, // Llega con la app abierta: aviso abajo
          alTocar: (_) => _irAInicio(), // La tocó: abre Inicio
        )).catchError((_) {}); // Si falla el registro, Más lo muestra y deja reintentar (las notificaciones se activarán la próxima vez)
  } // Fin de initState

  void _irAInicio() { // Cambia a la pestaña Inicio (ahí se ven el en vivo, el aviso urgente y los anuncios)
    if (!mounted) return; // Si la pantalla ya no existe, nada
    _alPrincipio(0); // Cierra lo que estuviera abierto dentro de Inicio (se ve Inicio desde arriba)
    setState(() => _pestana = 0); // Pestaña 0 = Inicio
  } // Fin de _irAInicio

  void _alPrincipio(int pestana) => _pilas[pestana].currentState?.popUntil((ruta) => ruta.isFirst); // Cierra todas las pantallas abiertas dentro de esa pestaña

  Widget _pila(int pestana, Widget raiz) => Navigator( // "Pila" de pantallas propia de una pestaña
        key: _pilas[pestana], // Su llave (para cerrar pantallas desde el menú y el botón atrás)
        onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => raiz), // La primera pantalla es la pestaña misma
      ); // Fin de la pila

  void _alTocarAtras() { // Botón "atrás" de Android
    final pila = _pilas[_pestana].currentState; // Pila de la pestaña visible
    if (pila != null && pila.canPop()) { // Si hay una pantalla abierta dentro de la pestaña...
      pila.pop(); // ...la cierra
    } else if (_pestana != 0) { // Si no, y no está en Inicio...
      setState(() => _pestana = 0); // ...vuelve a Inicio
    } else { // Si ya está en Inicio sin nada abierto...
      SystemNavigator.pop(); // ...sale de la app (como siempre)
    } // Fin del if
  } // Fin de _alTocarAtras

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
    return PopScope( // Controla el botón "atrás" de Android
      canPop: false, // No sale de la app directamente: primero decide _alTocarAtras
      onPopInvokedWithResult: (salio, _) { if (!salio) _alTocarAtras(); }, // Al tocar "atrás"
      child: Scaffold( // Estructura de la pantalla
      body: IndexedStack( // Muestra solo la pestaña elegida, pero MANTIENE las otras vivas (no se recargan al volver, y conservan lo que tenían abierto)
        index: _pestana, // Cuál mostrar
        children: [ // Las 5 pestañas (cada una con su pila de pantallas), en el mismo orden que el menú
          _pila(0, PantallaInicio(api: widget.api, registro: widget.registro, alIrAPestana: (i) { if (i == 3) recargarEventos.value++; setState(() => _pestana = i); })), // 0: Inicio ("Ver todos" de eventos cambia de pestaña y la actualiza)
          _pila(1, PantallaPredicas(api: widget.api, registro: widget.registro)), // 1: Prédicas
          _pila(2, const PantallaBiblia()), // 2: Biblia
          _pila(3, PantallaEventos(api: widget.api)), // 3: Eventos (el Horario se abre desde Inicio)
          _pila(4, PantallaMas(api: widget.api, registro: widget.registro)), // 4: Servicios (radio, peticiones de oración, aviso al llegar)
        ], // Fin de las pestañas
      ), // Fin de IndexedStack
      bottomNavigationBar: ValueListenableBuilder<bool>( // Escucha si se está viendo la presentación del logo
        valueListenable: presentacionEnCurso, // Aviso que cambia Inicio
        builder: (context, enPresentacion, menu) => enPresentacion ? const SizedBox.shrink() : Column( // Durante la presentación: sin menú (pantalla completa)
          mainAxisSize: MainAxisSize.min, // Solo lo necesario
          children: [ // Franja "sin conexión" (si aplica) y el menú
            ValueListenableBuilder<bool>( // Escucha si lo que se ve es la copia guardada
              valueListenable: sinConexion, // true = sin internet
              builder: (context, sinRed, _) => !sinRed ? const SizedBox.shrink() : Container( // Con conexión: nada
                width: double.infinity, // Todo el ancho
                color: const Color(0xFF374151), // Gris oscuro (se nota en claro y en oscuro)
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Relleno
                child: const Text('📴 Sin conexión · mostrando lo último guardado', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 14)), // Aviso
              ), // Fin de la franja
            ), // Fin de la escucha
            MediaQuery.withClampedTextScaling( // Con "letra grande" las etiquetas del menú NO crecen (si no, "Eventos" y "Servicios" se juntaban y llegaban a la orilla; probado en el Pixel con 110 % y seguía justo)
              maxScaleFactor: 1.0, // Tamaño normal (los íconos ayudan a reconocer cada opción)
              child: menu!, // Menú de abajo
            ), // Fin del límite
          ], // Fin de los elementos
        ), // Fin de la columna
        child: NavigationBar( // Menú de abajo (estilo Material 3)
        selectedIndex: _pestana, // Opción resaltada
        onDestinationSelected: (i) { // Al tocar una opción...
          if (i == _pestana) _alPrincipio(i); // ...si ya estaba en esa pestaña, vuelve a su principio (cierra lo abierto)
          if (i == 1) recargarPredicas.value++; // ...si es Prédicas, que se actualice (por si el panel cambió algo)
          if (i == 3) recargarEventos.value++; // ...si es Eventos, igual
          setState(() => _pestana = i); // ...cambia de pestaña y redibuja
        }, // Fin de onDestinationSelected
        destinations: const [ // Opciones del menú
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'), // Casa (rellena si está elegida)
          NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library), label: 'Prédicas'), // Videos
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Biblia'), // Libro abierto
          NavigationDestination(icon: Icon(Icons.celebration_outlined), selectedIcon: Icon(Icons.celebration), label: 'Eventos'), // Celebración: eventos especiales
          NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'Servicios'), // Cuadritos: radio, oración, avisos
        ], // Fin de las opciones
      ), // Fin del menú
      ), // Fin de ValueListenableBuilder
      ), // Fin del Scaffold
    ); // Fin de PopScope
  } // Fin de build
} // Fin de _PantallaPrincipalState
