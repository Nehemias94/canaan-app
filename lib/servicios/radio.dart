import 'dart:async'; // unawaited (arrancar algo sin esperar a que termine)

import 'package:just_audio/just_audio.dart'; // Reproductor de audio (sirve para la radio en línea)
import 'package:just_audio_background/just_audio_background.dart'; // MediaItem: lo que se muestra en la notificación y en la pantalla de bloqueo

enum EstadoRadio { detenida, cargando, sonando } // Estados que muestra la pantalla de la radio

// Plantilla del control de la radio: dice QUÉ debe saber hacer (reproducir, detener…), sin decir CÓMO.
// Así, en las pruebas automáticas (sin altavoz ni internet) se usa una versión de mentira.
abstract class ControlRadio { // "abstract" = plantilla: no se usa directo, se usa una versión que la cumpla
  static ControlRadio Function() crear = ControlRadioReal.new; // Cómo crear el control (en la app, el real; las pruebas lo cambian)

  Stream<EstadoRadio> get estados; // Avisa cada vez que cambia: detenida → cargando → sonando
  Future<void> reproducir(String url, {String titulo = 'Radio Canaán'}); // Conecta con la radio y empieza a sonar (el título sale en la pantalla de bloqueo)
  Future<void> detener(); // Detiene la radio
  Future<void> cerrar(); // Libera el reproductor (al salir de la pantalla)
} // Fin de ControlRadio

// Versión real, con just_audio + just_audio_background (Paso 11): sigue sonando con la pantalla bloqueada y muestra controles
// en la notificación y en la pantalla de bloqueo. Regla del paquete: solo UN AudioPlayer a la vez (se libera al salir de la pantalla).
class ControlRadioReal implements ControlRadio { // "implements" = cumple la plantilla de arriba
  final AudioPlayer _reproductor = AudioPlayer(); // Reproductor de just_audio
  bool _conectada = false; // true si ya se cargó el enlace de la radio

  @override // Cumple la plantilla
  Stream<EstadoRadio> get estados => _reproductor.playerStateStream.map((estado) { // Convierte los estados de just_audio a los nuestros
        if (!estado.playing) return EstadoRadio.detenida; // No se pidió sonar: detenida
        if (estado.processingState == ProcessingState.ready) return EstadoRadio.sonando; // Listo y sonando
        return EstadoRadio.cargando; // Se pidió sonar pero aún carga o llena el búfer
      }); // Fin del map

  @override // Cumple la plantilla
  Future<void> reproducir(String url, {String titulo = 'Radio Canaán'}) async { // Conecta con la radio y empieza a sonar
    if (!_conectada) { // Si todavía no está conectada (primera vez, o después de detener)...
      await _reproductor.setAudioSource(AudioSource.uri( // ...conecta con el enlace (lanza error si no es audio o no responde)
        Uri.parse(url), // Enlace de la radio
        tag: MediaItem(id: url, title: titulo, album: 'Ministerio Cristiano Canaán'), // Datos para la notificación / pantalla de bloqueo
      )); // Fin de la conexión
      _conectada = true; // Anota que ya conectó
    } // Fin del if
    unawaited(_reproductor.play()); // Empieza a sonar ("unawaited": play() no termina hasta que se detiene, así que NO se espera)
  } // Fin de reproducir

  @override // Cumple la plantilla
  Future<void> detener() async { // Detiene la radio
    await _reproductor.stop(); // Detiene y suelta la conexión (en una radio en vivo, "pausar" retomaría con retraso: mejor reconectar)
    _conectada = false; // La próxima vez vuelve a conectar (así suena lo que se transmite AHORA)
  } // Fin de detener

  @override // Cumple la plantilla
  Future<void> cerrar() => _reproductor.dispose(); // Libera el reproductor
} // Fin de ControlRadioReal
