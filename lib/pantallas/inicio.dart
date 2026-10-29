import 'dart:async'; // Timer (actualizar cada 90 s)

import 'package:flutter/material.dart'; // Componentes visuales de Flutter
import 'package:flutter/services.dart'; // SystemUiOverlayStyle (colores de la barra de arriba del teléfono)

import '../componentes/estados.dart'; // Vistas compartidas: Cargando, ErrorConexion
import '../config.dart'; // intervaloActualizacion
import '../modelos/anuncio.dart'; // Molde de un anuncio
import '../modelos/iglesia.dart'; // Molde de los datos de la iglesia
import '../servicios/api.dart'; // Llamadas a la API
import '../servicios/geocerca.dart'; // Geocerca (anuncios "Solo área", Paso 10)
import '../servicios/geocerca_fondo.dart'; // Geocerca con la app cerrada (Paso 11): se actualiza si el panel cambió la ubicación
import '../servicios/recarga.dart'; // "Timbre" para recargar al instante (aviso urgente)
import '../servicios/registro.dart'; // Registro del teléfono (para las señales del en vivo)
import '../tema.dart'; // Colores de Canaán
import 'radio.dart'; // Pantalla de la radio
import 'video.dart'; // Pantalla del video (transmisión en vivo)

class PantallaInicio extends StatefulWidget { // Pestaña "Inicio"; "Stateful" porque cambia (cargando → datos o error)
  const PantallaInicio({super.key, required this.api, required this.registro}); // Constructor: recibe la API (en pruebas, una falsa) y el registro

  final Api api; // De dónde se sacan los datos
  final RegistroDispositivo registro; // Para las señales del en vivo

  @override // Reemplaza createState
  State<PantallaInicio> createState() => _PantallaInicioState(); // Crea el estado de la pantalla
} // Fin de PantallaInicio

class _PantallaInicioState extends State<PantallaInicio> with WidgetsBindingObserver { // Estado de Inicio; "WidgetsBindingObserver" = se entera cuando la app vuelve a primer plano
  Iglesia? _iglesia; // Últimos datos de la iglesia (null hasta la primera respuesta)
  List<Anuncio> _anuncios = []; // Últimos anuncios recibidos
  bool _fallo = false; // true si la PRIMERA carga falló (luego, si falla, se conservan los datos anteriores)
  Timer? _reloj; // Reloj que vuelve a preguntar al panel cada 90 s
  late final Geocerca _geocerca = Geocerca(); // Revisa si el teléfono está en la iglesia ("late": se crea la primera vez que se usa)
  bool _revisandoGeocerca = false; // true mientras revisa (para no encimar dos revisiones)

  @override // Reemplaza initState
  void initState() { // Se ejecuta una sola vez, al crear la pantalla
    super.initState(); // Lo que hace Flutter por defecto
    WidgetsBinding.instance.addObserver(this); // Empieza a escuchar si la app se minimiza o vuelve
    _cargar(); // Primera carga
    _reloj = Timer.periodic(intervaloActualizacion, (_) => _cargar()); // Luego, cada 90 s, en silencio
    recargarInicio.addListener(_cargar); // Y al instante cuando el panel cambia el aviso urgente (aviso silencioso de Firebase)
  } // Fin de initState

  @override // Reemplaza dispose
  void dispose() { // Al cerrar la pantalla
    recargarInicio.removeListener(_cargar); // Deja de escuchar el "timbre"
    _reloj?.cancel(); // Detiene el reloj
    WidgetsBinding.instance.removeObserver(this); // Deja de escuchar
    super.dispose(); // Lo de Flutter por defecto
  } // Fin de dispose

  @override // Reemplaza didChangeAppLifecycleState
  void didChangeAppLifecycleState(AppLifecycleState estado) { // Se llama cuando la app cambia de estado (minimizada, de vuelta…)
    if (estado == AppLifecycleState.resumed) _cargar(); // Al volver a la app, actualiza enseguida (pudo empezar un en vivo)
  } // Fin de didChangeAppLifecycleState

  Future<void> _cargar() async { // Pide iglesia y anuncios al mismo tiempo y actualiza la pantalla
    try { // Intenta
      final iglesia = widget.api.obtenerIglesia(); // Arranca la petición de la iglesia...
      final anuncios = widget.api.obtenerAnuncios().catchError((_) => <Anuncio>[]); // ...y la de anuncios a la vez (si esta falla, sin anuncios: no tumba Inicio)
      final datos = await iglesia; // Espera la iglesia
      final lista = await anuncios; // Espera los anuncios
      if (!mounted) return; // Si la pantalla ya se cerró, no hace nada
      setState(() { // Redibuja con lo nuevo
        _iglesia = datos; // Datos de la iglesia
        _anuncios = lista.where((a) => a.esParaTodos && a.vigente(DateTime.now())).toList(); // Solo los de "Todos" que siguen vigentes
        _fallo = false; // Sin error
      }); // Fin de setState
      await _revisarGeocerca(datos, lista); // Revisa si está en la iglesia (solo pide la ubicación si hay anuncios de área en su ventana)
      unawaited(GeocercaFondo.actualizar(datos)); // Si la persona activó el aviso con la app cerrada y el panel cambió la ubicación, la vuelve a registrar
    } catch (_) { // Falló (sin internet, servidor dormido)
      if (mounted && _iglesia == null) setState(() => _fallo = true); // Solo muestra el error si no había nada en pantalla
    } // Fin del try
  } // Fin de _cargar

  Future<void> _revisarGeocerca(Iglesia iglesia, List<Anuncio> anuncios) async { // Geocerca: anuncios "Solo área"
    if (_revisandoGeocerca) return; // Ya hay una revisión en curso
    _revisandoGeocerca = true; // Marca que empezó
    try { // Intenta
      await _geocerca.guardarCopia(anuncios); // Guarda los anuncios "Solo área" en el teléfono: el aviso con la app cerrada los usa sin esperar al panel
      final nuevos = await _geocerca.revisar(iglesia, anuncios, DateTime.now()); // Anuncios nuevos por estar en la iglesia (vacío si no, o si ya se mostraron como notificación)
      if (!mounted) return; // Pantalla cerrada: nada
      if (nuevos.isNotEmpty) await _mostrarBienvenida(nuevos); // Recién llegó: ventana de bienvenida UNA sola vez (luego ya no aparece en ningún lado)
    } catch (_) { // Cualquier falla de ubicación: se ignora (la app sigue igual)
    } finally { // Pase lo que pase...
      _revisandoGeocerca = false; // ...termina la revisión
    } // Fin del try
  } // Fin de _revisarGeocerca

  Future<void> _mostrarBienvenida(List<Anuncio> anuncios) { // Ventana "¡Qué bueno que estás aquí!" con los anuncios del templo
    return showDialog<void>( // Ventana
      context: context, // Dónde mostrarla
      builder: (context) => AlertDialog( // Contenido
        icon: const Icon(Icons.place, color: doradoCanaan, size: 40), // Pin de ubicación dorado
        title: const Text('¡Qué bueno que estás aquí!'), // Título
        content: SingleChildScrollView( // Desplazable si son varios
          child: Column( // Uno debajo del otro
            mainAxisSize: MainAxisSize.min, // Solo lo necesario
            crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
            children: [ // Elementos
              for (final a in anuncios) ...[ // Por cada anuncio:
                Text(a.titulo, style: const TextStyle(fontWeight: FontWeight.bold)), // Título en negrita
                const SizedBox(height: 4), // Espacio
                Text(a.mensaje), // Mensaje
                const SizedBox(height: 12), // Espacio
              ], // Fin del anuncio
            ], // Fin de los elementos
          ), // Fin de la columna
        ), // Fin del desplazable
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))], // Botón para cerrar
      ), // Fin de la ventana
    ); // Fin de showDialog
  } // Fin de _mostrarBienvenida

  Future<void> _reintentar() async { // Botón "Reintentar"
    setState(() => _fallo = false); // Vuelve a mostrar "Conectando…"
    await _cargar(); // Intenta otra vez
  } // Fin de _reintentar

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return AnnotatedRegion<SystemUiOverlayStyle>( // Estilo de la barra de arriba del teléfono (hora, batería) mientras se ve Inicio
      value: barraSuperiorClara, // Íconos en blanco: se leen sobre el fondo azul oscuro (no hay barra de título aquí)
      child: Container( // Caja que ocupa toda la pestaña
      decoration: const BoxDecoration( // Fondo
        gradient: LinearGradient( // Degradado
          begin: Alignment.topCenter, // De arriba...
          end: Alignment.bottomCenter, // ...hacia abajo
          colors: [marinoCanaan, azulCanaan], // Marino → azul (igual que el login del panel)
        ), // Fin del degradado
      ), // Fin del fondo
      child: SafeArea( // Evita la cámara y la barra del teléfono
        child: _fallo // ¿Falló la primera carga?
            ? ErrorConexion(alReintentar: _reintentar, claro: true) // Sí: mensaje y Reintentar
            : _iglesia == null // ¿Todavía no hay datos?
                ? const Cargando(claro: true) // Sí: "Conectando…"
                : RefreshIndicator( // Hay datos: permite "jalar hacia abajo" para actualizar
                    onRefresh: _cargar, // Qué hacer al jalar
                    child: _DatosIglesia(iglesia: _iglesia!, anuncios: _anuncios, api: widget.api, registro: widget.registro), // Los datos
                  ), // Fin de RefreshIndicator
      ), // Fin de SafeArea
      ), // Fin del Container
    ); // Fin de AnnotatedRegion
  } // Fin de build
} // Fin de _PantallaInicioState

class _DatosIglesia extends StatelessWidget { // Contenido de Inicio cuando llegaron los datos
  const _DatosIglesia({required this.iglesia, required this.anuncios, required this.api, required this.registro}); // Constructor

  final Iglesia iglesia; // Datos de la iglesia
  final List<Anuncio> anuncios; // Anuncios vigentes (solo "Todos")
  final Api api; // Se pasa a la pantalla del video
  final RegistroDispositivo registro; // Se pasa a la pantalla del video

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return ListView( // Lista desplazable (necesaria para "jalar hacia abajo")
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), // Margen (poco arriba: lo importante debe verse sin bajar)
      children: [ // Elementos
        Row( // Encabezado compacto: logo pequeño a la izquierda y saludo a la derecha
          children: [ // Elementos
            if (iglesia.logoUrl != null) // Si la iglesia subió un logo en el panel...
              Image.network(iglesia.logoUrl!, height: 52) // ...lo muestra (pequeño)
            else // Si no...
              Image.asset('assets/imagenes/canaan-icono.png', height: 52), // ...el ícono oficial dorado de Canaán (va dentro de la app)
            const SizedBox(width: 14), // Espacio
            Expanded( // El texto ocupa el resto del ancho
              child: Column( // Uno debajo del otro
                crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
                children: [ // Elementos
                  Text( // Saludo según la hora
                    saludoSegunHora(DateTime.now()), // "Buenos días", "Buenas tardes" o "Buenas noches"
                    style: const TextStyle(color: doradoCanaan, fontSize: 16, fontWeight: FontWeight.bold), // Dorado
                  ), // Fin del saludo
                  Text( // Nombre de la iglesia (viene del panel)
                    iglesia.nombre, // Texto
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.2), // Blanco en negrita
                  ), // Fin del nombre
                  Text( // Fecha de hoy
                    fechaLarga(DateTime.now()), // Ej: "Jueves, 29 de octubre"
                    style: const TextStyle(color: Colors.white70, fontSize: 15), // Blanco suave
                  ), // Fin de la fecha
                ], // Fin de los elementos
              ), // Fin de la columna
            ), // Fin del Expanded
          ], // Fin de los elementos
        ), // Fin del encabezado
        const SizedBox(height: 20), // Espacio
        if (iglesia.enVivo.activo) // Si hay transmisión en vivo...
          _Etiqueta( // ...etiqueta roja
            texto: '● EN VIVO${iglesia.enVivo.titulo != null ? ' · ${iglesia.enVivo.titulo}' : ''}', // "● EN VIVO · título"
            fondo: Colors.red, // Rojo
            letras: Colors.white, // Letras blancas
          ), // Fin de la etiqueta
        if (iglesia.enVivo.activo && iglesia.enVivo.youtubeId != null) // Si hay en vivo y tiene video de YouTube...
          Padding( // ...botón grande para verlo
            padding: const EdgeInsets.only(top: 4, bottom: 12), // Separación
            child: Center( // Centrado
              child: FilledButton.icon( // Botón relleno
                style: FilledButton.styleFrom(backgroundColor: doradoCanaan, foregroundColor: marinoCanaan, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)), // Dorado con letras marino, grande
                icon: const Icon(Icons.play_circle_fill), // Ícono de reproducir
                label: const Text('Ver transmisión', style: TextStyle(fontWeight: FontWeight.bold)), // Texto
                onPressed: () => Navigator.push( // Abre el video encima
                  context, // Desde aquí
                  MaterialPageRoute(builder: (context) => PantallaVideo( // Pantalla del video
                    api: api, // API
                    registro: registro, // Registro del teléfono
                    youtubeId: iglesia.enVivo.youtubeId!, // Video de la transmisión
                    titulo: iglesia.enVivo.titulo ?? 'Transmisión en vivo', // Título (o uno genérico)
                    subtitulo: iglesia.nombre, // Nombre de la iglesia
                    enVivo: true, // Es en vivo: manda señales y muestra cuántos ven
                  )), // Fin de la ruta
                ), // Fin de Navigator.push
              ), // Fin del botón
            ), // Fin del centrado
          ), // Fin del margen
        if (iglesia.radioDisponible) // Si la radio está al aire...
          GestureDetector( // ...etiqueta dorada que se puede tocar
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaRadio(api: api))), // Al tocar, abre la radio
            child: const _Etiqueta(texto: '🎧 Radio al aire · Escuchar', fondo: doradoCanaan, letras: marinoCanaan), // Etiqueta dorada
          ), // Fin de GestureDetector
        if (iglesia.avisoUrgente.activo) // Si hay un aviso urgente vigente...
          Card( // ...tarjeta blanca con el aviso
            margin: const EdgeInsets.only(top: 12), // Separación arriba
            child: ListTile( // Fila con ícono, título y texto
              leading: const Icon(Icons.campaign, color: Colors.red), // Megáfono rojo
              title: Text(iglesia.avisoUrgente.titulo ?? 'Aviso'), // Título
              subtitle: Text(iglesia.avisoUrgente.mensaje ?? ''), // Mensaje
            ), // Fin de la fila
          ), // Fin de la tarjeta
        if (!iglesia.enVivo.activo && !iglesia.radioDisponible && !iglesia.avisoUrgente.activo && anuncios.isEmpty) // Si no hay nada que mostrar...
          const Text( // ...confirma que la conexión funciona
            '✓ Conectado con el panel', // Texto
            textAlign: TextAlign.center, // Centrado
            style: TextStyle(color: Colors.white70), // Blanco suave
          ), // Fin del texto
        if (anuncios.isNotEmpty) // Si hay anuncios...
          const Padding( // ...encabezado de la sección
            padding: EdgeInsets.only(top: 24, bottom: 4), // Separación
            child: Text( // Texto
              'ANUNCIOS', // Título de la sección
              style: TextStyle(color: doradoCanaan, fontWeight: FontWeight.bold, letterSpacing: 1.5), // Dorado, negrita, letras separadas
            ), // Fin del texto
          ), // Fin del encabezado
        for (final anuncio in anuncios) _TarjetaAnuncio(anuncio: anuncio), // Luego una tarjeta por anuncio para todos
      ], // Fin de los elementos
    ); // Fin de la lista
  } // Fin de build
} // Fin de _DatosIglesia

class _TarjetaAnuncio extends StatelessWidget { // Tarjeta blanca de un anuncio
  const _TarjetaAnuncio({required this.anuncio}); // Constructor

  final Anuncio anuncio; // Datos del anuncio

  String _fechas() { // "5 oct 2026" o "5 oct 2026 – 12 oct 2026" (según el rango del panel)
    final inicio = fechaCorta(anuncio.fechaInicio); // Primer día
    final fin = fechaCorta(anuncio.fechaFin); // Último día
    if (inicio.isEmpty) return fin; // Sin inicio: solo el fin (o nada)
    if (fin.isEmpty || fin == inicio) return inicio; // Un solo día
    return '$inicio – $fin'; // Rango
  } // Fin de _fechas

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    final fechas = _fechas(); // Texto de las fechas
    return Card( // Tarjeta blanca
      margin: const EdgeInsets.only(top: 8), // Separación
      child: Padding( // Margen interno
        padding: const EdgeInsets.all(14), // 14 por lado
        child: Column( // Elementos uno debajo del otro
          crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
          children: [ // Elementos
            Row( // Ícono y título en fila
              children: [ // Elementos
                const Icon(Icons.campaign_outlined, color: azulCanaan), // Megáfono azul
                const SizedBox(width: 8), // Espacio
                Expanded(child: Text(anuncio.titulo, style: Theme.of(context).textTheme.titleMedium)), // Título (ocupa el resto)
              ], // Fin de los elementos
            ), // Fin de la fila
            const SizedBox(height: 6), // Espacio
            Text(anuncio.mensaje), // Texto del anuncio
            if (fechas.isNotEmpty) // Si hay fechas...
              Padding( // ...las muestra en gris
                padding: const EdgeInsets.only(top: 6), // Separación
                child: Text(fechas, style: const TextStyle(color: Colors.black54, fontSize: 12)), // Gris pequeño
              ), // Fin de las fechas
          ], // Fin de los elementos
        ), // Fin de la columna
      ), // Fin del margen
    ); // Fin de la tarjeta
  } // Fin de build
} // Fin de _TarjetaAnuncio

class _Etiqueta extends StatelessWidget { // Etiqueta redondeada de color (EN VIVO, Radio)
  const _Etiqueta({required this.texto, required this.fondo, required this.letras}); // Constructor

  final String texto; // Texto
  final Color fondo; // Color de fondo
  final Color letras; // Color de las letras

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Center( // Centrada (dentro de la lista ocuparía todo el ancho)
      child: Container( // Caja
        margin: const EdgeInsets.only(bottom: 8), // Separación abajo
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), // Relleno interno
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)), // Fondo y bordes redondos
        child: Text(texto, style: TextStyle(color: letras, fontWeight: FontWeight.bold)), // Texto en negrita
      ), // Fin de la caja
    ); // Fin del centrado
  } // Fin de build
} // Fin de _Etiqueta
