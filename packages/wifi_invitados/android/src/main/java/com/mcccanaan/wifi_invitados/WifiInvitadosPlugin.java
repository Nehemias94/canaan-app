package com.mcccanaan.wifi_invitados; // Paquete del complemento

import android.content.Context; // Acceso a los servicios del teléfono
import android.content.Intent; // Para abrir el panel de Wi-Fi
import android.net.ConnectivityManager; // Servicio de conexiones (pedir una red solo para la app)
import android.net.Network; // Una red conectada
import android.net.NetworkCapabilities; // Qué ofrece una red
import android.net.NetworkRequest; // Pedido de red
import android.net.wifi.WifiManager; // Servicio de Wi-Fi
import android.net.wifi.WifiNetworkSpecifier; // "Esta red exacta, solo para esta app" (Android 10+)
import android.net.wifi.WifiNetworkSuggestion; // Sugerencia de red para TODO el teléfono (Android 10+): se usa solo al compartir, si el panel lo permite
import android.os.Build; // Versión de Android
import android.os.Handler; // Para responder en el hilo principal
import android.os.Looper; // Hilo principal
import android.provider.Settings; // Panel de Wi-Fi de los ajustes

import androidx.annotation.NonNull; // Marca "nunca es null"

import java.util.ArrayList; // Listas
import java.util.List; // Listas

import io.flutter.embedding.engine.plugins.FlutterPlugin; // Base de los complementos de Flutter
import io.flutter.plugin.common.MethodCall; // Llamada que llega desde Dart
import io.flutter.plugin.common.MethodChannel; // Canal de comunicación con Dart

// Conecta SOLO la app Canaán a la red Wi-Fi de invitados de la iglesia (WifiNetworkSpecifier, Android 10+).
// Las demás apps del teléfono NO usan esta red. Android muestra su ventana "¿Conectar a…?" (normalmente solo la primera vez),
// y la conexión se suelta sola al cerrar la app o al salir del alcance del router (el teléfono vuelve a sus datos).
// Además, "sugerir"/"quitar" ponen la red para TODO el teléfono (WifiNetworkSuggestion): solo cuando la persona quiere compartir
// algo por WhatsApp sin datos y el panel lo permite; la app la quita al salir de la iglesia.
public class WifiInvitadosPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler { // Complemento + receptor de llamadas
  private static final int ESPERA_MS = 45000; // Máximo 45 s para encontrar la red y que la persona confirme
  private MethodChannel canal; // Canal con Dart
  private Context contexto; // Contexto de la app
  private ConnectivityManager.NetworkCallback escucha; // Escucha de la red pedida (null = no hay conexión pedida)
  private final Handler principal = new Handler(Looper.getMainLooper()); // Para responder a Dart en el hilo principal

  @Override // Al conectarse con Flutter
  public void onAttachedToEngine(@NonNull FlutterPluginBinding enlace) { // Recibe el enlace
    contexto = enlace.getApplicationContext(); // Guarda el contexto de la app
    canal = new MethodChannel(enlace.getBinaryMessenger(), "com.mcccanaan.canaan_app/wifi_invitados"); // Crea el canal
    canal.setMethodCallHandler(this); // Las llamadas llegan a onMethodCall
  } // Fin de onAttachedToEngine

  @Override // Al desconectarse
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding enlace) { // Recibe el enlace
    desconectar(); // Suelta la red de la iglesia (si estaba conectada)
    canal.setMethodCallHandler(null); // Deja de escuchar
    canal = null; // Libera
  } // Fin de onDetachedFromEngine

  @Override // Llegó una llamada desde Dart
  public void onMethodCall(@NonNull MethodCall llamada, @NonNull MethodChannel.Result resultado) { // Llamada y respuesta
    WifiManager wifi = (WifiManager) contexto.getSystemService(Context.WIFI_SERVICE); // Servicio de Wi-Fi
    switch (llamada.method) { // Según lo que se pidió
      case "soportado": // ¿Este teléfono permite conectar solo la app?
        resultado.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q); // Solo Android 10 o más nuevo
        return; // Fin
      case "wifiEncendido": // ¿El Wi-Fi está encendido?
        resultado.success(wifi != null && wifi.isWifiEnabled()); // true / false
        return; // Fin
      case "conectado": // ¿La app está usando ahora la red de la iglesia?
        resultado.success(escucha != null); // true mientras dure la conexión
        return; // Fin
      case "conectarSoloApp": // Conectar la app (solo la app) a la red
        conectar(llamada.argument("nombre"), llamada.argument("contrasena"), resultado); // Pide la red
        return; // Fin
      case "desconectar": // Soltar la red y volver a los datos
        desconectar(); // Suelta
        resultado.success(true); // Listo
        return; // Fin
      case "sugerir": // Poner la red para TODO el teléfono (al compartir)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || wifi == null) { resultado.success(false); return; } // Teléfono viejo: no se puede
        String red = llamada.argument("nombre"); // Nombre de la red
        String clave = llamada.argument("contrasena"); // Contraseña
        List<WifiNetworkSuggestion> nueva = new ArrayList<>(); // Lista con una sola sugerencia
        nueva.add(sugerencia(red, clave)); // La sugerencia
        quitarPorNombre(wifi, red); // Quita una anterior (por si cambió la contraseña)
        int estado = wifi.addNetworkSuggestions(nueva); // Se la da a Android (la 1.ª vez pregunta "¿Permitir redes sugeridas por Canaán?")
        resultado.success(estado == WifiManager.STATUS_NETWORK_SUGGESTIONS_SUCCESS || estado == WifiManager.STATUS_NETWORK_SUGGESTIONS_ERROR_ADD_DUPLICATE); // Bien (o ya estaba)
        return; // Fin
      case "quitar": // Quitar la red de TODO el teléfono (al salir de la iglesia)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || wifi == null) { resultado.success(false); return; } // Teléfono viejo: no había
        String nombre = llamada.argument("nombre"); // Nombre de la red
        List<WifiNetworkSuggestion> igual = new ArrayList<>(); // La misma sugerencia (Android 10 las compara así)
        igual.add(sugerencia(nombre, llamada.argument("contrasena"))); // Igual a la que se agregó
        wifi.removeNetworkSuggestions(igual); // La quita (Android se desconecta de ella)
        quitarPorNombre(wifi, nombre); // Android 11+: también cualquier otra con ese nombre
        resultado.success(true); // Listo
        return; // Fin
      case "abrirPanelWifi": // Abrir el panelito de Wi-Fi (para encenderlo)
        Intent panel = new Intent(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ? Settings.Panel.ACTION_WIFI : Settings.ACTION_WIFI_SETTINGS); // Panel (Android 10+) o ajustes de Wi-Fi
        panel.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); // Necesario al abrir desde el contexto de la app
        try { contexto.startActivity(panel); resultado.success(true); } catch (Exception e) { resultado.success(false); } // Lo abre
        return; // Fin
      default: // Otra cosa
        resultado.notImplemented(); // No existe
    } // Fin del switch
  } // Fin de onMethodCall

  private void conectar(String nombre, String contrasena, MethodChannel.Result resultado) { // Pide la red a Android (muestra su ventana de confirmación)
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) { resultado.success(false); return; } // Teléfono viejo: no se puede
    desconectar(); // Suelta un pedido anterior (si había)
    WifiNetworkSpecifier.Builder red = new WifiNetworkSpecifier.Builder().setSsid(nombre); // Esta red exacta
    if (contrasena != null && !contrasena.isEmpty()) red.setWpa2Passphrase(contrasena); // Con contraseña (WPA2; sirve en WPA2/WPA3)
    NetworkRequest pedido = new NetworkRequest.Builder() // Pedido
        .addTransportType(NetworkCapabilities.TRANSPORT_WIFI) // Por Wi-Fi
        .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) // Android marca estas redes "solo para la app": no se exige que el sistema la valide como internet (igual navega si el router tiene internet)
        .setNetworkSpecifier(red.build()) // La red de la iglesia
        .build(); // Listo
    ConnectivityManager conexiones = (ConnectivityManager) contexto.getSystemService(Context.CONNECTIVITY_SERVICE); // Servicio de conexiones
    final boolean[] respondido = {false}; // Para responder a Dart una sola vez
    escucha = new ConnectivityManager.NetworkCallback() { // Lo que pasa con la red pedida
      @Override public void onAvailable(@NonNull Network n) { // Se conectó
        conexiones.bindProcessToNetwork(n); // TODA la app (pantallas, videos, Biblia) usa esta red; las demás apps no
        responder(resultado, respondido, true); // Avisa a Dart: conectada
      } // Fin de onAvailable
      @Override public void onUnavailable() { // No la encontró o la persona tocó "Cancelar"
        escucha = null; // Ya no hay pedido
        responder(resultado, respondido, false); // Avisa a Dart: no se pudo
      } // Fin de onUnavailable
      @Override public void onLost(@NonNull Network n) { // Se perdió (salió del alcance del router o la apagaron)
        conexiones.bindProcessToNetwork(null); // La app vuelve a los datos del teléfono
        desconectar(); // Suelta el pedido
      } // Fin de onLost
    }; // Fin de la escucha
    try { // Pedir la red puede fallar (permisos, Wi-Fi apagado)
      conexiones.requestNetwork(pedido, escucha, ESPERA_MS); // Pide la red (máx. 45 s)
    } catch (Exception e) { // Falló
      escucha = null; // Sin pedido
      responder(resultado, respondido, false); // No se pudo
    } // Fin del try
  } // Fin de conectar

  private WifiNetworkSuggestion sugerencia(String nombre, String contrasena) { // Arma la sugerencia para todo el teléfono (Android 10+)
    WifiNetworkSuggestion.Builder b = new WifiNetworkSuggestion.Builder().setSsid(nombre); // Nombre de la red
    if (contrasena != null && !contrasena.isEmpty()) b.setWpa2Passphrase(contrasena); // Con contraseña (WPA2)
    return b.build(); // Lista
  } // Fin de sugerencia

  private void quitarPorNombre(WifiManager wifi, String nombre) { // Quita las sugerencias de ESTA app con ese nombre (Android 11+)
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return; // Android 10 no permite leerlas
    List<WifiNetworkSuggestion> quitar = new ArrayList<>(); // Las que se quitan
    for (WifiNetworkSuggestion s : wifi.getNetworkSuggestions()) { if (nombre != null && nombre.equals(s.getSsid())) quitar.add(s); } // Mismo nombre
    if (!quitar.isEmpty()) wifi.removeNetworkSuggestions(quitar); // Las quita
  } // Fin de quitarPorNombre

  private void responder(MethodChannel.Result resultado, boolean[] respondido, boolean valor) { // Responde a Dart una sola vez y en el hilo principal
    principal.post(() -> { if (!respondido[0]) { respondido[0] = true; resultado.success(valor); } }); // Solo la primera vez
  } // Fin de responder

  private void desconectar() { // Suelta la red de la iglesia (la app vuelve a los datos)
    if (escucha == null) return; // No había conexión pedida
    ConnectivityManager conexiones = (ConnectivityManager) contexto.getSystemService(Context.CONNECTIVITY_SERVICE); // Servicio de conexiones
    conexiones.bindProcessToNetwork(null); // La app deja de usar esa red
    try { conexiones.unregisterNetworkCallback(escucha); } catch (Exception ignorado) {} // Suelta el pedido (Android se desconecta de la red)
    escucha = null; // Sin pedido
  } // Fin de desconectar
} // Fin de WifiInvitadosPlugin
