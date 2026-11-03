package com.mcccanaan.wifi_invitados; // Paquete del complemento

import android.content.Context; // Acceso a los servicios del teléfono
import android.content.Intent; // Para abrir el panel de Wi-Fi
import android.net.wifi.WifiManager; // Servicio de Wi-Fi
import android.net.wifi.WifiNetworkSuggestion; // Sugerencia de red (Android 10+)
import android.os.Build; // Versión de Android
import android.provider.Settings; // Panel de Wi-Fi de los ajustes

import androidx.annotation.NonNull; // Marca "nunca es null"

import java.util.ArrayList; // Listas
import java.util.List; // Listas

import io.flutter.embedding.engine.plugins.FlutterPlugin; // Base de los complementos de Flutter
import io.flutter.plugin.common.MethodCall; // Llamada que llega desde Dart
import io.flutter.plugin.common.MethodChannel; // Canal de comunicación con Dart

// Sugiere a Android la red Wi-Fi de invitados de la iglesia (WifiNetworkSuggestion, Android 10+).
// Con una sugerencia, Android se conecta SOLO cuando la red está cerca (la primera vez pregunta "¿Permitir que Canaán sugiera redes?").
// Al quitar la sugerencia, Android se desconecta de esa red y la olvida. La app NO puede leer otras redes ni contraseñas.
public class WifiInvitadosPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler { // Complemento + receptor de llamadas
  private MethodChannel canal; // Canal con Dart
  private Context contexto; // Contexto de la app (sirve también con la app cerrada)

  @Override // Al conectarse con Flutter (app abierta o despertada por la geocerca)
  public void onAttachedToEngine(@NonNull FlutterPluginBinding enlace) { // Recibe el enlace
    contexto = enlace.getApplicationContext(); // Guarda el contexto de la app
    canal = new MethodChannel(enlace.getBinaryMessenger(), "com.mcccanaan.canaan_app/wifi_invitados"); // Crea el canal
    canal.setMethodCallHandler(this); // Las llamadas llegan a onMethodCall
  } // Fin de onAttachedToEngine

  @Override // Al desconectarse
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding enlace) { // Recibe el enlace
    canal.setMethodCallHandler(null); // Deja de escuchar
    canal = null; // Libera
  } // Fin de onDetachedFromEngine

  @Override // Llegó una llamada desde Dart
  public void onMethodCall(@NonNull MethodCall llamada, @NonNull MethodChannel.Result resultado) { // Llamada y respuesta
    WifiManager wifi = (WifiManager) contexto.getSystemService(Context.WIFI_SERVICE); // Servicio de Wi-Fi
    switch (llamada.method) { // Según lo que se pidió
      case "soportado": // ¿Este teléfono acepta sugerencias?
        resultado.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q); // Solo Android 10 o más nuevo
        return; // Fin
      case "wifiEncendido": // ¿El Wi-Fi está encendido?
        resultado.success(wifi != null && wifi.isWifiEnabled()); // true / false
        return; // Fin
      case "sugerir": // Agregar la sugerencia de la red
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || wifi == null) { resultado.success(false); return; } // Teléfono viejo: no se puede
        String red = llamada.argument("nombre"); // Nombre de la red (SSID)
        String clave = llamada.argument("contrasena"); // Contraseña (vacía = red abierta)
        List<WifiNetworkSuggestion> nueva = new ArrayList<>(); // Lista con una sola sugerencia
        nueva.add(construir(red, clave)); // La sugerencia
        quitarPorNombre(wifi, red); // Quita la anterior (por si cambió la contraseña en el panel)
        int estado = wifi.addNetworkSuggestions(nueva); // Se la da a Android
        resultado.success(estado == WifiManager.STATUS_NETWORK_SUGGESTIONS_SUCCESS || estado == WifiManager.STATUS_NETWORK_SUGGESTIONS_ERROR_ADD_DUPLICATE); // Bien (o ya estaba)
        return; // Fin
      case "quitar": // Quitar la sugerencia (al salir del área o si el panel apagó el servicio)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || wifi == null) { resultado.success(false); return; } // Teléfono viejo: no había
        String nombre = llamada.argument("nombre"); // Nombre de la red
        String contrasena = llamada.argument("contrasena"); // Contraseña con la que se sugirió
        List<WifiNetworkSuggestion> igual = new ArrayList<>(); // La misma sugerencia (Android 10 las compara así)
        igual.add(construir(nombre, contrasena)); // Igual a la que se agregó
        wifi.removeNetworkSuggestions(igual); // La quita (si no estaba, no pasa nada)
        quitarPorNombre(wifi, nombre); // Android 11+: también cualquier otra con ese nombre (ej. con una contraseña vieja)
        resultado.success(true); // Listo
        return; // Fin
      case "abrirPanelWifi": // Abrir el panelito de Wi-Fi (para encenderlo) — solo con la app abierta
        Intent panel = new Intent(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ? Settings.Panel.ACTION_WIFI : Settings.ACTION_WIFI_SETTINGS); // Panel (Android 10+) o ajustes de Wi-Fi
        panel.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); // Necesario al abrir desde el contexto de la app
        try { contexto.startActivity(panel); resultado.success(true); } catch (Exception e) { resultado.success(false); } // Lo abre
        return; // Fin
      default: // Otra cosa
        resultado.notImplemented(); // No existe
    } // Fin del switch
  } // Fin de onMethodCall

  private WifiNetworkSuggestion construir(String nombre, String contrasena) { // Arma la sugerencia (requiere Android 10+)
    WifiNetworkSuggestion.Builder b = new WifiNetworkSuggestion.Builder().setSsid(nombre); // Nombre de la red
    if (contrasena != null && !contrasena.isEmpty()) b.setWpa2Passphrase(contrasena); // Con contraseña: WPA2 (sirve también en redes WPA2/WPA3)
    return b.build(); // Lista
  } // Fin de construir

  private void quitarPorNombre(WifiManager wifi, String nombre) { // Quita las sugerencias de la app con ese nombre (Android 11+)
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return; // Android 10 no permite leer las sugerencias
    List<WifiNetworkSuggestion> quitar = new ArrayList<>(); // Las que se quitan
    for (WifiNetworkSuggestion s : wifi.getNetworkSuggestions()) { // Sugerencias de ESTA app (no ve las de otras)
      if (nombre != null && nombre.equals(s.getSsid())) quitar.add(s); // Mismo nombre
    } // Fin del for
    if (!quitar.isEmpty()) wifi.removeNetworkSuggestions(quitar); // Las quita
  } // Fin de quitarPorNombre
} // Fin de WifiInvitadosPlugin
