import 'package:flutter/services.dart'; // MethodChannel (hablar con el código de Android)

// Conectar SOLO la app a la red Wi-Fi de invitados de la iglesia en Android 10+ (ver WifiInvitadosPlugin.java).
// En otros teléfonos o en el navegador, todas las funciones devuelven false sin fallar.
class WifiInvitados { // Solo funciones estáticas
  static const _canal = MethodChannel('com.mcccanaan.canaan_app/wifi_invitados'); // Canal con Android

  static Future<bool> _llamar(String metodo, [Map<String, dynamic>? datos]) async { // Llama a Android sin lanzar errores
    try { return await _canal.invokeMethod<bool>(metodo, datos) ?? false; } catch (_) { return false; } // false si no existe (iPhone, navegador, pruebas)
  } // Fin de _llamar

  static Future<bool> soportado() => _llamar('soportado'); // ¿Android 10 o más nuevo?
  static Future<bool> wifiEncendido() => _llamar('wifiEncendido'); // ¿Wi-Fi encendido?
  static Future<bool> conectado() => _llamar('conectado'); // ¿La app está usando la red de la iglesia?
  static Future<bool> conectarSoloApp(String nombre, String contrasena) => _llamar('conectarSoloApp', {'nombre': nombre, 'contrasena': contrasena}); // Conecta la app (Android pregunta); true = conectada
  static Future<bool> desconectar() => _llamar('desconectar'); // Suelta la red (vuelve a los datos)
  static Future<bool> sugerir(String nombre, String contrasena) => _llamar('sugerir', {'nombre': nombre, 'contrasena': contrasena}); // Pone la red para TODO el teléfono (al compartir)
  static Future<bool> quitar(String nombre, String contrasena) => _llamar('quitar', {'nombre': nombre, 'contrasena': contrasena}); // La quita de todo el teléfono
  static Future<bool> abrirPanelWifi() => _llamar('abrirPanelWifi'); // Abre el panel de Wi-Fi
} // Fin de WifiInvitados
