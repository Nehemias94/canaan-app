import 'dart:async'; // Timer (para mandar la señal del en vivo cada 30 s) y StreamSubscription

import 'package:flutter/material.dart'; // Componentes visuales de Flutter
import 'package:youtube_player_iframe/youtube_player_iframe.dart'; // Reproductor de YouTube dentro de la app

import '../servicios/api.dart'; // Llamadas a la API (vistas y señales)
import '../servicios/registro.dart'; // Llave del teléfono
import '../tema.dart'; // Colores de Canaán

class PantallaVideo extends StatefulWidget { // Pantalla con el video de YouTube (prédica o transmisión en vivo)
  const PantallaVideo({ // Constructor
    super.key, // Llave interna de Flutter
    required this.api, // API
    required this.registro, // Registro del teléfono
    required this.youtubeId, // Código del video
    required this.titulo, // Título
    this.subtitulo, // Ej: "Pastor Juan · 5 oct 2026"
    this.descripcion, // Texto debajo del video
    this.predicaId, // Número de la prédica (para contar la vista); null en el en vivo
    this.enVivo = false, // true = transmisión en vivo (manda señales y muestra cuántos ven)
  }); // Fin del constructor

  final Api api; // De dónde se envían vistas y señales
  final RegistroDispositivo registro; // Para la llave del teléfono
  final String youtubeId; // Código del video de YouTube
  final String titulo; // Título
  final String? subtitulo; // Línea gris bajo el título
  final String? descripcion; // Descripción
  final int? predicaId; // Prédica a la que se le cuenta la vista
  final bool enVivo; // ¿Es la transmisión en vivo?

  static Widget? reproductorDePrueba; // Solo en pruebas automáticas: reemplaza al reproductor real (YouTube no carga ahí). En la app siempre es null

  @override // Reemplaza createState
  State<PantallaVideo> createState() => _PantallaVideoState(); // Crea el estado
} // Fin de PantallaVideo

class _PantallaVideoState extends State<PantallaVideo> { // Estado de la pantalla del video
  YoutubePlayerController? _control; // Control del reproductor (pausar, cerrar…); null en las pruebas
  StreamSubscription<YoutubePlayerValue>? _escucha; // Escucha los cambios del reproductor (para saber cuándo empieza a sonar)
  bool _vistaContada = false; // true cuando ya se avisó al panel de esta vista (solo una vez por pantalla)
  Timer? _temporizador; // Reloj que manda la siguiente señal del en vivo
  int? _viendoAhora; // Personas viendo el en vivo (null hasta la primera señal)
  bool _transmisionTerminada = false; // true si el panel avisa que el en vivo terminó

  @override // Reemplaza initState
  void initState() { // Al abrir la pantalla
    super.initState(); // Lo de Flutter por defecto
    if (PantallaVideo.reproductorDePrueba == null) { // Con el reproductor real (no en pruebas)...
      _control = YoutubePlayerController.fromVideoId( // ...crea el control del video
        videoId: widget.youtubeId, // Video a reproducir
        autoPlay: true, // Empieza solo (algunos navegadores lo bloquean hasta que se toca la pantalla)
        params: const YoutubePlayerParams( // Opciones del reproductor
          showFullscreenButton: true, // Botón de pantalla completa
          strictRelatedVideos: true, // Al terminar, solo sugiere videos del mismo canal
        ), // Fin de las opciones
      ); // Fin del control
      _escucha = _control!.stream.listen((valor) { // Cada vez que el reproductor cambia de estado...
        if (valor.playerState == PlayerState.playing) _contarVista(); // ...si empezó a reproducirse, cuenta la vista
      }); // Fin de la escucha
    } // Fin del if
    if (widget.enVivo) _enviarSenal(); // En vivo: primera señal apenas se abre (luego cada 30 s)
  } // Fin de initState

  Future<void> _contarVista() async { // Avisa al panel que se está viendo la prédica (una sola vez)
    if (_vistaContada || widget.predicaId == null) return; // Ya contada, o no es una prédica: nada que hacer
    _vistaContada = true; // Marca como contada (antes de enviar, para no repetir si llegan varios "playing")
    try { // Intenta avisar
      await widget.registro.conLlave((token) => widget.api.registrarReproduccion(token: token, predicaId: widget.predicaId!)); // POST de la vista
    } catch (_) {} // Si falla (sin internet), no importa: el video sigue
  } // Fin de _contarVista

  Future<void> _enviarSenal() async { // Manda "sigo viendo" y programa la siguiente
    try { // Intenta enviar
      final senal = await widget.registro.conLlave(widget.api.senalEnVivo); // POST de la señal con la llave
      if (!mounted) return; // Si ya se cerró la pantalla, no hace nada más
      if (!senal.enVivo) { // El panel dice que terminó la transmisión...
        _control?.stopVideo(); // ...detiene el video (si no, seguiría sonando lo que YouTube aún tenga)...
        setState(() => _transmisionTerminada = true); // ...cambia el reproductor por el aviso de "terminó"...
        return; // ...y deja de mandar señales
      } // Fin del if
      setState(() => _viendoAhora = senal.viendoAhora); // Actualiza "N personas viendo"
      _temporizador = Timer(Duration(seconds: senal.siguienteSegundos), _enviarSenal); // Programa la siguiente señal
    } catch (_) { // Falló (sin internet, servidor ocupado)...
      if (mounted) _temporizador = Timer(const Duration(seconds: 30), _enviarSenal); // ...reintenta en 30 s
    } // Fin del try
  } // Fin de _enviarSenal

  @override // Reemplaza dispose
  void dispose() { // Al cerrar la pantalla
    _temporizador?.cancel(); // Detiene las señales ("?." = solo si existe)
    _escucha?.cancel(); // Deja de escuchar al reproductor
    _control?.close(); // Cierra el reproductor (libera memoria)
    if (widget.enVivo && !_transmisionTerminada) { // Si estaba viendo un en vivo activo...
      widget.registro.conLlave(widget.api.salirEnVivo).catchError((_) {}); // ...avisa "dejé de ver" (baja el contador al instante; si falla, se ignora)
    } // Fin del if
    super.dispose(); // Lo de Flutter por defecto
  } // Fin de dispose

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Scaffold( // Estructura de la pantalla
      appBar: AppBar(title: Text(widget.enVivo ? 'En vivo' : 'Prédica')), // Barra con flecha para volver
      body: ListView( // Video arriba y textos abajo (desplazable)
        children: [ // Elementos
          if (_transmisionTerminada) // Si el en vivo terminó...
            _videoTerminado() // ...recuadro negro con el aviso (el reproductor se quita para que no siga sonando)
          else // Si no...
            PantallaVideo.reproductorDePrueba ?? YoutubePlayer(controller: _control!, aspectRatio: 16 / 9), // ...el video (16:9) o el de reemplazo en pruebas
          if (widget.enVivo) _barraEnVivo(), // En vivo: franja con "EN VIVO · N viendo" o "terminó"
          Padding( // Margen de los textos
            padding: const EdgeInsets.all(16), // 16 por lado
            child: Column( // Textos uno debajo del otro
              crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
              children: [ // Elementos
                Text(widget.titulo, style: Theme.of(context).textTheme.titleLarge), // Título grande
                if (widget.subtitulo != null && widget.subtitulo!.isNotEmpty) // Si hay subtítulo...
                  Padding( // ...con un poco de espacio arriba
                    padding: const EdgeInsets.only(top: 4), // Espacio
                    child: Text(widget.subtitulo!, style: const TextStyle(color: Colors.black54)), // Gris
                  ), // Fin del subtítulo
                if (widget.descripcion != null && widget.descripcion!.isNotEmpty) // Si hay descripción...
                  Padding( // ...separada
                    padding: const EdgeInsets.only(top: 16), // Espacio
                    child: Text(widget.descripcion!), // Texto
                  ), // Fin de la descripción
              ], // Fin de los elementos
            ), // Fin de la columna
          ), // Fin del margen
        ], // Fin de los elementos
      ), // Fin de la lista
    ); // Fin del Scaffold
  } // Fin de build

  Widget _videoTerminado() { // Recuadro que reemplaza al video cuando el en vivo terminó
    return AspectRatio( // Mismo tamaño que el video (16:9)
      aspectRatio: 16 / 9, // Ancho : alto
      child: Container( // Fondo
        color: marinoCanaan, // Marino
        alignment: Alignment.center, // Contenido centrado
        child: Column( // Elementos uno debajo del otro
          mainAxisSize: MainAxisSize.min, // Ocupa solo lo necesario
          children: [ // Elementos
            const Icon(Icons.tv_off, color: Colors.white70, size: 48), // Televisor apagado
            const SizedBox(height: 8), // Espacio
            const Text('La transmisión terminó', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), // Mensaje
            const SizedBox(height: 12), // Espacio
            OutlinedButton( // Botón para volver
              onPressed: () => Navigator.pop(context), // Cierra esta pantalla
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)), // Blanco
              child: const Text('Volver al inicio'), // Texto
            ), // Fin del botón
          ], // Fin de los elementos
        ), // Fin de la columna
      ), // Fin del fondo
    ); // Fin de AspectRatio
  } // Fin de _videoTerminado

  Widget _barraEnVivo() { // Franja bajo el video del en vivo
    if (_transmisionTerminada) { // Si terminó...
      return Container( // ...franja gris
        color: Colors.black87, // Casi negro
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Relleno
        child: const Text('La transmisión terminó. ¡Gracias por acompañarnos!', style: TextStyle(color: Colors.white)), // Mensaje
      ); // Fin de la franja
    } // Fin del if
    return Container( // Transmisión activa: franja marino
      color: marinoCanaan, // Fondo marino
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Relleno
      child: Row( // Elementos en fila
        children: [ // Elementos
          Container( // Etiqueta roja "● EN VIVO"
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // Relleno
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)), // Rojo con esquinas suaves
            child: const Text('● EN VIVO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)), // Texto
          ), // Fin de la etiqueta
          const Spacer(), // Empuja lo siguiente a la derecha
          const Icon(Icons.visibility, color: Colors.white70, size: 18), // Ojo
          const SizedBox(width: 6), // Espacio
          Text( // Cuántos ven
            _viendoAhora == null ? '…' : '$_viendoAhora ${_viendoAhora == 1 ? 'persona viendo' : 'personas viendo'}', // "…" hasta la primera señal; singular o plural
            style: const TextStyle(color: Colors.white), // Blanco
          ), // Fin del texto
        ], // Fin de los elementos
      ), // Fin de la fila
    ); // Fin de la franja
  } // Fin de _barraEnVivo
} // Fin de _PantallaVideoState
