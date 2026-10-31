import 'package:flutter/foundation.dart'; // kIsWeb, defaultTargetPlatform y ValueNotifier
import 'package:flutter/services.dart'; // MethodChannel: el "teléfono" para hablar con el código de Android (MainActivity.kt)

/// Ventana flotante del video ("imagen en imagen" de Android).
/// Mientras la pantalla del video está abierta, si la persona sale de la app (botón de inicio o gesto),
/// el video sigue en una ventanita encima de las demás apps. Las reglas de YouTube lo permiten porque el video SIGUE VISIBLE.
class VentanaFlotante { // Todo es estático: hay una sola ventana flotante para toda la app
  VentanaFlotante._(); // No se crean objetos de esta clase

  static const _canal = MethodChannel('com.mcccanaan.canaan_app/ventana_flotante'); // Mismo nombre que en MainActivity.kt

  static final activa = ValueNotifier<bool>(false); // true = la app se está viendo como ventanita (la pantalla principal oculta el menú de abajo)
  static VoidCallback? alCerrarla; // Lo que hay que hacer si la persona CIERRA la ventanita con la X (el video la pone en pausa)

  static bool _escuchando = false; // true cuando ya se conectó la escucha de los avisos de Android

  /// Solo en Android (en el navegador y en iPhone no hace nada).
  static bool get soportada => !kIsWeb && defaultTargetPlatform == TargetPlatform.android; // ¿Este aparato la tiene?

  /// Permite (true) o deja de permitir (false) que la app pase a ventanita al salir de ella.
  static Future<void> permitir(bool si) async { // Lo llama la pantalla del video al abrirse (true) y al cerrarse (false)
    if (!soportada) return; // Fuera de Android: nada
    _escuchar(); // Conecta la escucha (una sola vez)
    try { // Intenta avisar a Android
      await _canal.invokeMethod('permitir', si); // MainActivity guarda el permiso (en Android 12+ entra sola al salir)
    } catch (_) {} // Si falla (teléfono muy viejo o pruebas automáticas), el video sigue funcionando normal
  } // Fin de permitir

  /// Pasa a ventanita en este momento (botón de la barra del video).
  static Future<bool> entrar() async { // Devuelve true si Android aceptó
    if (!soportada) return false; // Fuera de Android: no se puede
    try { // Intenta
      return await _canal.invokeMethod<bool>('entrar') ?? false; // Android achica la app a la ventanita
    } catch (_) { // Falló (por ejemplo, la persona desactivó "Pantalla en pantalla" para Canaán en los ajustes)
      return false; // No se pudo
    } // Fin del try
  } // Fin de entrar

  static void _escuchar() { // Recibe los avisos que manda Android
    if (_escuchando) return; // Ya estaba conectada
    _escuchando = true; // Marca como conectada
    _canal.setMethodCallHandler((llamada) async { // Cada aviso de Android...
      if (llamada.method == 'cambio') { // ...entró o salió de la ventanita
        final datos = Map<String, dynamic>.from(llamada.arguments as Map); // {activa: bool, cerrada: bool}
        activa.value = datos['activa'] == true; // Actualiza el aviso (la pantalla se redibuja sola)
        if (datos['cerrada'] == true) alCerrarla?.call(); // La cerró con la X: el video se pausa (que no siga sonando sin verse)
      } // Fin del if
    }); // Fin de la escucha
  } // Fin de _escuchar
} // Fin de VentanaFlotante
