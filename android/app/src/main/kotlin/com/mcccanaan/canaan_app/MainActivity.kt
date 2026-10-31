package com.mcccanaan.canaan_app // Paquete de la app

import android.app.PictureInPictureParams // Opciones de la ventana flotante (forma, entrar sola)
import android.content.res.Configuration // Datos de la pantalla (los manda Android al cambiar de modo)
import android.os.Build // Para saber la versión de Android del teléfono
import android.util.Rational // Proporción del video (16:9)
import androidx.lifecycle.Lifecycle // Estado de la pantalla (para saber si la ventanita se CERRÓ o se agrandó)
import com.ryanheise.audioservice.AudioServiceActivity // Actividad de audio_service (necesaria para la radio en segundo plano)
import io.flutter.embedding.engine.FlutterEngine // Motor de Flutter (para conectar el canal)
import io.flutter.plugin.common.MethodChannel // Canal para hablar con Flutter (lib/servicios/ventana_flotante.dart)

class MainActivity : AudioServiceActivity() { // Pantalla principal de Android: igual que la de Flutter, pero conectada al servicio de audio
    private var canal: MethodChannel? = null // Canal con Flutter (null hasta que arranca el motor)
    private var permitida = false // true mientras la pantalla del video está abierta (solo entonces se pasa a ventanita)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) { // Cuando Flutter arranca
        super.configureFlutterEngine(flutterEngine) // Lo de siempre (registra los paquetes)
        canal = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.mcccanaan.canaan_app/ventana_flotante") // Mismo nombre que en Flutter
        canal?.setMethodCallHandler { llamada, respuesta -> // Pedidos que llegan de Flutter
            when (llamada.method) { // Según el pedido...
                "permitir" -> { // ...permitir o no la ventanita
                    permitida = llamada.arguments as? Boolean ?: false // Guarda el permiso
                    aplicarOpciones() // Android 12+: entra sola al salir de la app
                    respuesta.success(null) // Listo
                }
                "entrar" -> respuesta.success(entrarAhora()) // ...pasar a ventanita ya (botón de la barra del video)
                else -> respuesta.notImplemented() // Pedido desconocido
            }
        }
    }

    private fun opciones(): PictureInPictureParams? { // Arma las opciones de la ventanita
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null // Antes de Android 8 no existe la ventanita
        val constructor = PictureInPictureParams.Builder().setAspectRatio(Rational(16, 9)) // Con forma de video (ancho 16, alto 9)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) { // Android 12 o más nuevo...
            constructor.setAutoEnterEnabled(permitida) // ...entra solo al salir de la app (más suave)
            constructor.setSeamlessResizeEnabled(false) // ...recomendado por Google para videos (evita parpadeos)
        }
        return constructor.build() // Opciones listas
    }

    private fun aplicarOpciones() { // Le pasa las opciones a Android
        val o = opciones() ?: return // Teléfono sin ventanita: nada
        try { setPictureInPictureParams(o) } catch (e: Exception) {} // Si falla, el video sigue normal
    }

    private fun entrarAhora(): Boolean { // Achica la app a la ventanita en este momento
        val o = opciones() ?: return false // Teléfono sin ventanita: no se puede
        return try { enterPictureInPictureMode(o) } catch (e: Exception) { false } // false si la persona la desactivó en los ajustes
    }

    override fun onUserLeaveHint() { // La persona sale de la app (botón de inicio o gesto)
        super.onUserLeaveHint() // Lo de siempre
        if (permitida && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) entrarAhora() // Android 8 a 11: hay que entrar a mano (en 12+ entra sola)
    }

    override fun onPictureInPictureModeChanged(activa: Boolean, nuevaConfig: Configuration) { // Entró o salió de la ventanita
        super.onPictureInPictureModeChanged(activa, nuevaConfig) // Lo de siempre
        val cerrada = !activa && lifecycle.currentState == Lifecycle.State.CREATED // Salió y la app ya no se ve = la cerró con la X (si la agrandó, la app vuelve a verse)
        canal?.invokeMethod("cambio", mapOf("activa" to activa, "cerrada" to cerrada)) // Avisa a Flutter (oculta el menú o pausa el video)
    }
}
