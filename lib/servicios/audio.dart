import 'dart:async'; // unawaited (arrancar algo sin esperar a que termine)

import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Caja fuerte (recordar dónde se quedó la persona)
import 'package:just_audio/just_audio.dart'; // Reproductor de audio (el mismo de la radio)
import 'package:just_audio_background/just_audio_background.dart'; // MediaItem: título en la notificación y en la pantalla de bloqueo

import 'radio.dart'; // EstadoRadio (detenida / cargando / sonando): se reutiliza para el audio

// Plantilla del control del audio de una prédica (MP3): como la radio, pero con pausa, avance y "adelantar/retroceder".
// En las pruebas automáticas se usa una versión de mentira (sin altavoz ni internet).
abstract class ControlAudio { // "abstract" = plantilla
  static ControlAudio Function() crear = ControlAudioReal.new; // Cómo crearlo (en la app, el real; las pruebas lo cambian)

  Stream<EstadoRadio> get estados; // detenida (pausada) → cargando → sonando
  Stream<Duration> get posiciones; // Por dónde va (cada ~200 ms mientras suena)
  Stream<Duration?> get duraciones; // Cuánto dura (null hasta que el archivo lo dice)
  Stream<bool> get terminados; // Avisa true cuando llegó al final
  Future<void> cargar(String url, {required String titulo, String? artista, Duration desde = Duration.zero}); // Conecta con el MP3 (sin sonar todavía)
  Future<void> reproducir(); // Suena (o sigue donde se pausó)
  Future<void> pausar(); // Pausa (se queda en el mismo punto)
  Future<void> irA(Duration posicion); // Salta a un punto (barra de avance, ±10 s)
  Future<void> cerrar(); // Libera el reproductor (al salir de la pantalla)
} // Fin de ControlAudio

// Versión real con just_audio + just_audio_background: sigue sonando con la pantalla bloqueada o usando otra app,
// con controles en la notificación. Regla del paquete: solo UN reproductor a la vez (este o el de la radio).
class ControlAudioReal implements ControlAudio { // Cumple la plantilla
  final AudioPlayer _reproductor = AudioPlayer(); // Reproductor de just_audio

  @override // Cumple la plantilla
  Stream<EstadoRadio> get estados => _reproductor.playerStateStream.map((estado) { // Convierte los estados de just_audio a los nuestros
        if (!estado.playing || estado.processingState == ProcessingState.completed) return EstadoRadio.detenida; // Pausado o terminado
        if (estado.processingState == ProcessingState.ready) return EstadoRadio.sonando; // Sonando
        return EstadoRadio.cargando; // Conectando o llenando el búfer
      }); // Fin del map

  @override // Cumple la plantilla
  Stream<Duration> get posiciones => _reproductor.positionStream; // Posición actual

  @override // Cumple la plantilla
  Stream<Duration?> get duraciones => _reproductor.durationStream; // Duración del archivo

  @override // Cumple la plantilla
  Stream<bool> get terminados => _reproductor.processingStateStream.map((e) => e == ProcessingState.completed); // ¿Llegó al final?

  @override // Cumple la plantilla
  Future<void> cargar(String url, {required String titulo, String? artista, Duration desde = Duration.zero}) async { // Conecta con el MP3
    await _reproductor.setAudioSource( // Carga el archivo (lanza error si no es audio o no responde)
      AudioSource.uri(Uri.parse(url), tag: MediaItem(id: url, title: titulo, artist: artista, album: 'Ministerio Cristiano Canaán')), // Datos para la pantalla de bloqueo
      initialPosition: desde, // Empieza donde se quedó la persona
    ); // Fin de la carga
  } // Fin de cargar

  @override // Cumple la plantilla
  Future<void> reproducir() async { // Suena
    if (_reproductor.processingState == ProcessingState.completed) await _reproductor.seek(Duration.zero); // Si ya había terminado, vuelve al principio
    unawaited(_reproductor.play()); // play() no termina hasta que se pausa: no se espera
  } // Fin de reproducir

  @override // Cumple la plantilla
  Future<void> pausar() => _reproductor.pause(); // Pausa

  @override // Cumple la plantilla
  Future<void> irA(Duration posicion) => _reproductor.seek(posicion); // Salta

  @override // Cumple la plantilla
  Future<void> cerrar() => _reproductor.dispose(); // Libera el reproductor
} // Fin de ControlAudioReal

// Recuerda en el teléfono por dónde iba cada prédica (para seguir otro día donde se quedó).
class PosicionesAudio { // Solo funciones estáticas
  static const _almacen = FlutterSecureStorage(); // Caja fuerte del teléfono
  static String _clave(int predicaId) => 'audio_posicion_$predicaId'; // Una clave por prédica

  static Future<Duration> leer(int predicaId) async { // Dónde se quedó (0 si nunca la escuchó)
    try { // La caja fuerte puede fallar en algunos teléfonos
      final segundos = int.tryParse(await _almacen.read(key: _clave(predicaId)) ?? ''); // Segundos guardados
      return Duration(seconds: segundos ?? 0); // Como duración
    } catch (_) { return Duration.zero; } // Si falla, desde el principio
  } // Fin de leer

  static Future<void> guardar(int predicaId, Duration posicion) async { // Anota por dónde va
    try { await _almacen.write(key: _clave(predicaId), value: '${posicion.inSeconds}'); } catch (_) {} // Si falla, no pasa nada
  } // Fin de guardar

  static Future<void> olvidar(int predicaId) async { // La terminó: la próxima vez empieza desde el principio
    try { await _almacen.delete(key: _clave(predicaId)); } catch (_) {} // Si falla, no pasa nada
  } // Fin de olvidar
} // Fin de PosicionesAudio
