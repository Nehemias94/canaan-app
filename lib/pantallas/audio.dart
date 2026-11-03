import 'dart:async'; // StreamSubscription (escuchar al reproductor)

import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../componentes/imagen_guardada.dart'; // Miniatura guardada en el teléfono
import '../modelos/predica.dart'; // Datos de la prédica
import '../servicios/api.dart'; // Para contar la vista
import '../servicios/audio.dart'; // Control del audio y posiciones guardadas
import '../servicios/radio.dart'; // EstadoRadio (detenida / cargando / sonando)
import '../servicios/registro.dart'; // Llave del teléfono
import '../tema.dart'; // Colores de Canaán

class PantallaAudio extends StatefulWidget { // "Escuchar solo el audio" de una prédica (sigue sonando con la pantalla bloqueada)
  const PantallaAudio({super.key, required this.api, required this.registro, required this.predica}); // Constructor

  final Api api; // Para contar la vista
  final RegistroDispositivo registro; // Llave del teléfono
  final Predica predica; // Prédica (trae audioUrl)

  @override // Reemplaza createState
  State<PantallaAudio> createState() => _PantallaAudioState(); // Crea el estado
} // Fin de PantallaAudio

class _PantallaAudioState extends State<PantallaAudio> { // Estado de la pantalla
  static const _salto = Duration(seconds: 10); // Cuánto adelantan o retroceden los botones (como el ícono "10")
  final ControlAudio _control = ControlAudio.crear(); // Reproductor (el real en la app; uno de mentira en las pruebas)
  final List<StreamSubscription<dynamic>> _escuchas = []; // Escuchas del reproductor (se cancelan al salir)
  EstadoRadio _estado = EstadoRadio.cargando; // Estado actual (empieza conectando)
  Duration _posicion = Duration.zero; // Por dónde va
  Duration? _duracion; // Cuánto dura
  Duration? _retomaDesde; // Si siguió donde se quedó la vez pasada (para ofrecer "desde el principio")
  String? _error; // Mensaje si no se pudo cargar
  bool _listo = false; // true cuando el MP3 ya cargó
  bool _vistaContada = false; // Solo se cuenta una vez
  DateTime _ultimoGuardado = DateTime.now(); // Para guardar la posición cada 10 s (no a cada rato)

  @override // Reemplaza initState
  void initState() { // Al abrir la pantalla
    super.initState(); // Lo de Flutter por defecto
    _escuchas.add(_control.estados.listen((e) { // Cambios de estado
      if (!mounted) return; // Pantalla cerrada: nada
      setState(() => _estado = e); // Redibuja el botón
      if (e == EstadoRadio.sonando) _contarVista(); // Empezó a sonar: cuenta la vista
      if (e == EstadoRadio.detenida && _listo) _guardarPosicion(); // Al pausar, anota por dónde va
    })); // Fin
    _escuchas.add(_control.posiciones.listen((p) { // Avance
      if (!mounted) return; // Pantalla cerrada: nada
      setState(() => _posicion = p); // Mueve la barra
      if (DateTime.now().difference(_ultimoGuardado).inSeconds >= 10) _guardarPosicion(); // Cada 10 s, anota por dónde va
    })); // Fin
    _escuchas.add(_control.duraciones.listen((d) { if (mounted) setState(() => _duracion = d); })); // Duración del archivo
    _escuchas.add(_control.terminados.listen((fin) { if (fin) PosicionesAudio.olvidar(widget.predica.id); })); // La terminó: la próxima vez desde el principio
    _cargar(); // Conecta con el MP3
  } // Fin de initState

  Future<void> _cargar() async { // Conecta con el MP3 y empieza a sonar
    setState(() { _error = null; _estado = EstadoRadio.cargando; }); // Limpia errores y muestra "Conectando…"
    try { // Intenta
      final guardada = await PosicionesAudio.leer(widget.predica.id); // ¿Dónde se quedó la vez pasada?
      final desde = guardada.inSeconds >= 20 ? guardada - const Duration(seconds: 5) : Duration.zero; // Retoma 5 s antes (para no perder el hilo); si casi no la había empezado, desde el principio
      await _control.cargar(widget.predica.audioUrl!, titulo: widget.predica.titulo, artista: widget.predica.predicador, desde: desde); // Carga el archivo
      if (!mounted) return; // Pantalla cerrada mientras cargaba
      setState(() { _listo = true; _posicion = desde; _retomaDesde = desde > Duration.zero ? desde : null; }); // Listo
      await _control.reproducir(); // Suena
    } catch (_) { // No se pudo (enlace caído, sin internet, no es audio)
      if (mounted) setState(() { _error = 'No pudimos cargar el audio. Revisa tu conexión a internet e intenta de nuevo.'; _estado = EstadoRadio.detenida; }); // Mensaje
    } // Fin del try
  } // Fin de _cargar

  Future<void> _contarVista() async { // Avisa al panel (una sola vez; el panel cuenta máx. 1 cada 6 h por teléfono)
    if (_vistaContada) return; // Ya contada
    _vistaContada = true; // Marca antes de enviar
    try { await widget.registro.conLlave((token) => widget.api.registrarReproduccion(token: token, predicaId: widget.predica.id)); } catch (_) {} // Si falla, no importa
  } // Fin de _contarVista

  void _guardarPosicion() { // Anota por dónde va
    _ultimoGuardado = DateTime.now(); // Hora del último guardado
    final fin = _duracion; // Duración
    if (fin != null && fin - _posicion < const Duration(seconds: 30)) { // Si le faltan menos de 30 s...
      PosicionesAudio.olvidar(widget.predica.id); // ...cuenta como terminada
    } else { // Si no...
      PosicionesAudio.guardar(widget.predica.id, _posicion); // ...guarda el punto
    } // Fin del if
  } // Fin de _guardarPosicion

  @override // Reemplaza dispose
  void dispose() { // Al salir de la pantalla
    if (_listo) _guardarPosicion(); // Anota por dónde iba
    for (final e in _escuchas) { e.cancel(); } // Deja de escuchar
    _control.cerrar(); // Detiene y libera (con la pantalla bloqueada la pantalla sigue abierta: sigue sonando)
    super.dispose(); // Lo de Flutter por defecto
  } // Fin de dispose

  void _alternar() { // Botón grande: pausa o suena
    if (_error != null) { _cargar(); return; } // Si falló, reintenta
    if (_estado == EstadoRadio.detenida) { _control.reproducir(); } else { _control.pausar(); } // Suena o pausa
  } // Fin de _alternar

  void _saltar(Duration cuanto) { // ±10 s
    final fin = _duracion ?? Duration.zero; // Duración (0 si aún no se sabe)
    var nueva = _posicion + cuanto; // Nueva posición
    if (nueva < Duration.zero) nueva = Duration.zero; // No antes del principio
    if (fin > Duration.zero && nueva > fin) nueva = fin; // No después del final
    _control.irA(nueva); // Salta
    setState(() => _posicion = nueva); // Mueve la barra enseguida
  } // Fin de _saltar

  void _desdeElPrincipio() { // Botón "Escuchar desde el principio"
    _control.irA(Duration.zero); // Al principio
    setState(() { _posicion = Duration.zero; _retomaDesde = null; }); // Redibuja
  } // Fin de _desdeElPrincipio

  static String tiempo(Duration d) { // 754 s → "12:34"; 3754 s → "1:02:34"
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60; // Horas, minutos y segundos
    final mm = h > 0 ? m.toString().padLeft(2, '0') : '$m'; // Minutos con dos cifras solo si hay horas
    return '${h > 0 ? '$h:' : ''}$mm:${s.toString().padLeft(2, '0')}'; // Texto
  } // Fin de tiempo

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    final p = widget.predica; // Atajo
    final sonando = _estado == EstadoRadio.sonando; // ¿Suena?
    final cargando = _estado == EstadoRadio.cargando; // ¿Conectando?
    final fin = _duracion ?? Duration.zero; // Duración (0 si aún no se sabe)
    final avance = fin.inMilliseconds > 0 ? (_posicion.inMilliseconds / fin.inMilliseconds).clamp(0.0, 1.0) : 0.0; // 0 a 1 para la barra
    return Scaffold( // Estructura
      appBar: AppBar(title: const Text('Escuchar prédica')), // Barra con flecha para volver
      body: Container( // Fondo
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [marinoCanaan, azulCanaan])), // Degradado como la radio
        child: Center( // Centrado
          child: SingleChildScrollView( // Se desplaza si no cabe (letra grande, teléfonos pequeños)
            padding: const EdgeInsets.all(28), // Margen
            child: Column( // Uno debajo del otro
              mainAxisSize: MainAxisSize.min, // Solo lo necesario
              children: [ // Elementos
                ClipRRect( // Miniatura con esquinas redondeadas
                  borderRadius: BorderRadius.circular(16), // Radio
                  child: SizedBox( // Tamaño
                    width: 260, height: 146, // 16:9
                    child: p.miniaturaUrl == null // ¿Tiene miniatura?
                        ? Container(color: Colors.white10, child: const Icon(Icons.headphones, color: doradoCanaan, size: 64)) // No: audífonos dorados
                        : ImagenGuardada(p.miniaturaUrl!, fit: BoxFit.cover, alError: (_) => Container(color: Colors.white10)), // Sí: la del video
                  ), // Fin del tamaño
                ), // Fin de la miniatura
                const SizedBox(height: 20), // Espacio
                Text(p.titulo, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)), // Título
                if ((p.predicador ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(p.predicador!, style: const TextStyle(color: Colors.white70, fontSize: 16))), // Predicador
                const SizedBox(height: 24), // Espacio
                SliderTheme( // Barra de avance (dorada)
                  data: SliderTheme.of(context).copyWith(activeTrackColor: doradoCanaan, inactiveTrackColor: Colors.white24, thumbColor: doradoCanaan, overlayColor: doradoCanaan.withValues(alpha: 0.2)), // Colores
                  child: Slider( // Se puede arrastrar
                    value: avance, // Posición (0 a 1)
                    semanticFormatterCallback: (_) => '${tiempo(_posicion)} de ${tiempo(fin)}', // Lectores de pantalla: "12:34 de 45:00"
                    onChanged: fin > Duration.zero && _listo ? (v) => setState(() => _posicion = fin * v) : null, // Al arrastrar, mueve el número
                    onChangeEnd: fin > Duration.zero && _listo ? (v) => _control.irA(fin * v) : null, // Al soltar, salta
                  ), // Fin de la barra
                ), // Fin del tema
                Padding( // Tiempos debajo de la barra
                  padding: const EdgeInsets.symmetric(horizontal: 20), // Alineados con la barra
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ // A los extremos
                    Text(tiempo(_posicion), style: const TextStyle(color: Colors.white)), // Por dónde va
                    Text(fin > Duration.zero ? tiempo(fin) : '--:--', style: const TextStyle(color: Colors.white70)), // Cuánto dura
                  ]), // Fin de la fila
                ), // Fin de los tiempos
                const SizedBox(height: 16), // Espacio
                Row( // Botones: −10 · ▶/⏸ · +10
                  mainAxisAlignment: MainAxisAlignment.center, // Centrados
                  children: [ // Elementos
                    IconButton(iconSize: 44, color: Colors.white, tooltip: 'Retroceder 10 segundos', onPressed: _listo ? () => _saltar(-_salto) : null, icon: const Icon(Icons.replay_10_rounded)), // Retroceder
                    const SizedBox(width: 16), // Espacio
                    SizedBox( // Botón redondo grande
                      width: 92, height: 92, // Tamaño
                      child: FilledButton( // Relleno
                        onPressed: cargando ? null : _alternar, // Mientras conecta, no se toca
                        style: FilledButton.styleFrom(backgroundColor: doradoCanaan, foregroundColor: marinoCanaan, disabledBackgroundColor: doradoCanaan, shape: const CircleBorder(), padding: EdgeInsets.zero), // Dorado y redondo
                        child: cargando // ¿Conectando?
                            ? const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(color: marinoCanaan, strokeWidth: 3)) // Rueda
                            : Icon(_error != null ? Icons.refresh_rounded : (sonando ? Icons.pause_rounded : Icons.play_arrow_rounded), size: 54, semanticLabel: _error != null ? 'Reintentar' : (sonando ? 'Pausar' : 'Escuchar')), // Reintentar, pausar o escuchar
                      ), // Fin del botón
                    ), // Fin del tamaño
                    const SizedBox(width: 16), // Espacio
                    IconButton(iconSize: 44, color: Colors.white, tooltip: 'Adelantar 10 segundos', onPressed: _listo ? () => _saltar(_salto) : null, icon: const Icon(Icons.forward_10_rounded)), // Adelantar
                  ], // Fin de los elementos
                ), // Fin de los botones
                const SizedBox(height: 12), // Espacio
                Text(cargando ? 'Conectando…' : (_error != null ? 'Toca para reintentar' : (sonando ? 'Escuchando' : 'En pausa')), style: const TextStyle(color: Colors.white)), // Estado en palabras
                if (_retomaDesde != null) // Si siguió donde se quedó...
                  TextButton.icon( // ...ofrece empezar de nuevo
                    onPressed: _desdeElPrincipio, // Al principio
                    style: TextButton.styleFrom(foregroundColor: doradoCanaan), // Dorado
                    icon: const Icon(Icons.restart_alt), // Ícono
                    label: Text('Seguiste donde te quedaste (${tiempo(_retomaDesde!)}). Escuchar desde el principio'), // Texto
                  ), // Fin del botón
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFB4AB)))), // Error en rojo claro
                const SizedBox(height: 20), // Espacio
                const Text('Puedes bloquear el teléfono o usar otra app: el audio sigue sonando. Se detiene al salir de esta pantalla.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 13)), // Explicación
              ], // Fin de los elementos
            ), // Fin de la columna
          ), // Fin del desplazamiento
        ), // Fin del centrado
      ), // Fin del fondo
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de _PantallaAudioState
