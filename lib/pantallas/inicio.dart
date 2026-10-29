import 'dart:async'; // Timer (actualizar cada 90 s)

import 'package:flutter/material.dart'; // Componentes visuales de Flutter
import 'package:flutter/services.dart'; // SystemUiOverlayStyle (colores de la barra de arriba del teléfono)

import '../componentes/estados.dart'; // Vistas compartidas: Cargando, ErrorConexion
import '../componentes/carga_animada.dart'; // Pantalla de carga con el logo animado
import '../componentes/tarjeta.dart'; // Tarjeta con franja de color (diseño común)
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
  Timer? _esperaAnimacion; // Espera para que la animación del logo se vea completa al abrir la app
  bool _animacionVista = false; // true cuando ya pasó el tiempo mínimo de la animación del logo
  late final Geocerca _geocerca = Geocerca(); // Revisa si el teléfono está en la iglesia ("late": se crea la primera vez que se usa)
  bool _revisandoGeocerca = false; // true mientras revisa (para no encimar dos revisiones)

  @override // Reemplaza initState
  void initState() { // Se ejecuta una sola vez, al crear la pantalla
    super.initState(); // Lo que hace Flutter por defecto
    WidgetsBinding.instance.addObserver(this); // Empieza a escuchar si la app se minimiza o vuelve
    _cargar(); // Primera carga
    _reloj = Timer.periodic(intervaloActualizacion, (_) => _cargar()); // Luego, cada 90 s, en silencio
    _esperaAnimacion = Timer(const Duration(milliseconds: 2600), () { // Al abrir la app, el logo animado se ve al menos 2.6 s (hasta que se forma "Canaán")...
      if (mounted) setState(() => _animacionVista = true); // ...aunque el panel responda antes
    }); // Fin de la espera
    recargarInicio.addListener(_cargar); // Y al instante cuando el panel cambia el aviso urgente (aviso silencioso de Firebase)
  } // Fin de initState

  @override // Reemplaza dispose
  void dispose() { // Al cerrar la pantalla
    recargarInicio.removeListener(_cargar); // Deja de escuchar el "timbre"
    _reloj?.cancel(); // Detiene el reloj
    _esperaAnimacion?.cancel(); // Y la espera de la animación
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
      value: barraSuperiorClara, // Íconos en blanco: arriba siempre hay marino
      child: _fallo || _iglesia == null || !_animacionVista // ¿Falló la primera carga, todavía no hay datos o la animación del logo no ha terminado?
          ? Container( // Pantalla completa en degradado mientras carga (o si falló)
              decoration: const BoxDecoration( // Fondo
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [marinoCanaan, azulCanaan]), // Marino → azul
              ), // Fin del fondo
              child: SafeArea( // Evita la cámara y la barra del teléfono
                child: _fallo // ¿Falló?
                    ? ErrorConexion(alReintentar: _reintentar, claro: true) // Sí: mensaje y Reintentar
                    : const CargaAnimada(), // No: logo animado (arca + "Canaán" letra por letra)
              ), // Fin de SafeArea
            ) // Fin de la pantalla de carga
          : RefreshIndicator( // Hay datos: permite "jalar hacia abajo" para actualizar
              onRefresh: _cargar, // Qué hacer al jalar
              child: _DatosIglesia(iglesia: _iglesia!, anuncios: _anuncios, api: widget.api, registro: widget.registro), // Los datos
            ), // Fin de RefreshIndicator
    ); // Fin de AnnotatedRegion
  } // Fin de build
} // Fin de _PantallaInicioState

class _DatosIglesia extends StatelessWidget { // Contenido de Inicio cuando llegaron los datos
  const _DatosIglesia({required this.iglesia, required this.anuncios, required this.api, required this.registro}); // Constructor

  final Iglesia iglesia; // Datos de la iglesia
  final List<Anuncio> anuncios; // Anuncios vigentes (solo "Todos")
  final Api api; // Se pasa a la pantalla del video
  final RegistroDispositivo registro; // Se pasa a la pantalla del video

  void _abrirEnVivo(BuildContext context) { // Abre la transmisión en vivo
    Navigator.push( // Abre el video encima
      context, // Desde aquí
      MaterialPageRoute(builder: (context) => PantallaVideo( // Pantalla del video
        api: api, // API
        registro: registro, // Registro del teléfono
        youtubeId: iglesia.enVivo.youtubeId!, // Video de la transmisión
        titulo: iglesia.enVivo.titulo ?? 'Transmisión en vivo', // Título (o uno genérico)
        subtitulo: iglesia.nombre, // Nombre de la iglesia
        enVivo: true, // Es en vivo: manda señales y muestra cuántos ven
      )), // Fin de la ruta
    ); // Fin de Navigator.push
  } // Fin de _abrirEnVivo

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    final aviso = iglesia.avisoUrgente; // Atajo
    final hayVideo = iglesia.enVivo.activo && iglesia.enVivo.youtubeId != null; // ¿Hay en vivo con video?
    return ListView( // Lista desplazable (necesaria para "jalar hacia abajo")
      padding: EdgeInsets.zero, // Sin margen: el encabezado llega hasta arriba (detrás de la hora)
      children: [ // Elementos
        _Encabezado(iglesia: iglesia), // Franja marino con logo, saludo, nombre y fecha
        Padding( // Contenido sobre el fondo claro
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), // Márgenes
          child: Column( // Uno debajo del otro
            crossAxisAlignment: CrossAxisAlignment.stretch, // Todo el ancho
            children: [ // Elementos
              if (iglesia.enVivo.activo) // Si hay transmisión en vivo...
                TarjetaCanaan( // ...tarjeta con franja ROJA
                  franja: Colors.red.shade700, // Rojo
                  alTocar: hayVideo ? () => _abrirEnVivo(context) : null, // Al tocar, abre el video
                  child: Column( // Uno debajo del otro
                    crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
                    children: [ // Elementos
                      Row( // Etiqueta "EN VIVO" y título
                        children: [ // Elementos
                          Container( // Etiqueta roja
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // Relleno
                            decoration: BoxDecoration(color: Colors.red.shade700, borderRadius: BorderRadius.circular(20)), // Roja redondeada
                            child: const Text('● EN VIVO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), // Texto
                          ), // Fin de la etiqueta
                          const SizedBox(width: 10), // Espacio
                          Expanded(child: Text(iglesia.enVivo.titulo ?? 'Transmisión en vivo', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: marinoCanaan))), // Título
                        ], // Fin de los elementos
                      ), // Fin de la fila
                      if (hayVideo) // Si tiene video...
                        Padding( // ...botón grande dorado
                          padding: const EdgeInsets.only(top: 12), // Separación
                          child: FilledButton.icon( // Botón relleno
                            style: FilledButton.styleFrom(backgroundColor: doradoCanaan, foregroundColor: marinoCanaan, minimumSize: const Size.fromHeight(52)), // Dorado, todo el ancho, alto 52
                            icon: const Icon(Icons.play_circle_fill, size: 26), // Ícono de reproducir
                            label: const Text('Ver transmisión', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), // Texto
                            onPressed: () => _abrirEnVivo(context), // Abre el video
                          ), // Fin del botón
                        ), // Fin del margen
                    ], // Fin de los elementos
                  ), // Fin de la columna
                ), // Fin de la tarjeta en vivo
              if (iglesia.radioDisponible) // Si la radio está al aire...
                TarjetaCanaan( // ...tarjeta con franja DORADA
                  franja: doradoCanaan, // Dorado
                  alTocar: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaRadio(api: api))), // Al tocar, abre la radio
                  child: const Row( // Ícono y textos
                    children: [ // Elementos
                      Icon(Icons.headphones, color: doradoOscuro, size: 30), // Audífonos
                      SizedBox(width: 12), // Espacio
                      Expanded(child: Text('🎧 Radio al aire · Escuchar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: marinoCanaan))), // Texto
                      Icon(Icons.chevron_right, color: Colors.black38), // Flechita: se puede tocar
                    ], // Fin de los elementos
                  ), // Fin de la fila
                ), // Fin de la tarjeta de la radio
              if (aviso.activo) // Si hay un aviso urgente vigente...
                TarjetaCanaan( // ...tarjeta con franja según el nivel (rojo urgente, dorado importante, azul informativo)
                  franja: colorDeNivel(aviso.nivel), // Color del nivel
                  child: Row( // Ícono y textos
                    crossAxisAlignment: CrossAxisAlignment.start, // Arriba
                    children: [ // Elementos
                      Icon(Icons.campaign, color: colorDeNivel(aviso.nivel) == doradoCanaan ? doradoOscuro : colorDeNivel(aviso.nivel), size: 30), // Megáfono del color del nivel
                      const SizedBox(width: 12), // Espacio
                      Expanded( // Textos
                        child: Column( // Uno debajo del otro
                          crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
                          children: [ // Elementos
                            Text(aviso.titulo ?? 'Aviso', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: marinoCanaan)), // Título
                            const SizedBox(height: 4), // Espacio
                            Text(aviso.mensaje ?? '', style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.35)), // Mensaje
                          ], // Fin de los elementos
                        ), // Fin de la columna
                      ), // Fin de los textos
                    ], // Fin de los elementos
                  ), // Fin de la fila
                ), // Fin de la tarjeta del aviso
              if (!iglesia.enVivo.activo && !iglesia.radioDisponible && !aviso.activo && anuncios.isEmpty) // Si no hay nada que mostrar...
                const Padding( // ...confirma que la conexión funciona
                  padding: EdgeInsets.only(top: 24), // Separación
                  child: Text('✓ Conectado con el panel', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)), // Gris
                ), // Fin del texto
              if (anuncios.isNotEmpty) // Si hay anuncios...
                const Padding( // ...encabezado de la sección
                  padding: EdgeInsets.only(top: 24, bottom: 0, left: 4), // Separación
                  child: Text('ANUNCIOS', style: TextStyle(color: doradoOscuro, fontWeight: FontWeight.bold, letterSpacing: 1.5)), // Dorado oscuro (se lee sobre el fondo claro)
                ), // Fin del encabezado
              for (final anuncio in anuncios) _TarjetaAnuncio(anuncio: anuncio), // Una tarjeta por anuncio
            ], // Fin de los elementos
          ), // Fin de la columna
        ), // Fin del contenido
      ], // Fin de los elementos
    ); // Fin de la lista
  } // Fin de build
} // Fin de _DatosIglesia

class _Encabezado extends StatelessWidget { // Franja marino de arriba: logo, saludo, nombre y fecha (bordes de abajo redondeados)
  const _Encabezado({required this.iglesia}); // Constructor

  final Iglesia iglesia; // Datos de la iglesia

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Container( // Caja con degradado
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 22), // Deja espacio para la hora del teléfono
      decoration: const BoxDecoration( // Fondo
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [marinoCanaan, azulCanaan]), // Marino → azul
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)), // Bordes de abajo redondeados
      ), // Fin del fondo
      child: Row( // Logo a la izquierda y textos a la derecha
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
                Text(saludoSegunHora(DateTime.now()), style: const TextStyle(color: doradoCanaan, fontSize: 16, fontWeight: FontWeight.bold)), // "Buenos días"…
                Text(iglesia.nombre, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.2)), // Nombre de la iglesia
                Text(fechaLarga(DateTime.now()), style: const TextStyle(color: Colors.white70, fontSize: 15)), // "Jueves, 29 de octubre"
              ], // Fin de los elementos
            ), // Fin de la columna
          ), // Fin del Expanded
        ], // Fin de los elementos
      ), // Fin de la fila
    ); // Fin de la caja
  } // Fin de build
} // Fin de _Encabezado

class _TarjetaAnuncio extends StatelessWidget { // Tarjeta de un anuncio (franja AZUL)
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
    return TarjetaCanaan( // Tarjeta con franja azul
      franja: azulCanaan, // Azul
      margen: const EdgeInsets.only(top: 10), // Separación
      child: Column( // Elementos uno debajo del otro
        crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
        children: [ // Elementos
          Row( // Ícono y título en fila
            crossAxisAlignment: CrossAxisAlignment.start, // Arriba
            children: [ // Elementos
              const Icon(Icons.campaign_outlined, color: azulCanaan, size: 26), // Megáfono azul
              const SizedBox(width: 10), // Espacio
              Expanded(child: Text(anuncio.titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: marinoCanaan))), // Título (ocupa el resto)
            ], // Fin de los elementos
          ), // Fin de la fila
          const SizedBox(height: 6), // Espacio
          Text(anuncio.mensaje, style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.35)), // Texto del anuncio
          if (fechas.isNotEmpty) // Si hay fechas...
            Padding( // ...las muestra en gris
              padding: const EdgeInsets.only(top: 8), // Separación
              child: Text(fechas, style: const TextStyle(color: Colors.black54, fontSize: 13)), // Gris pequeño
            ), // Fin de las fechas
        ], // Fin de los elementos
      ), // Fin de la columna
    ); // Fin de la tarjeta
  } // Fin de build
} // Fin de _TarjetaAnuncio
