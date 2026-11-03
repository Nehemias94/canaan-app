import 'package:flutter/services.dart'; // MethodChannel (hablar con el código de Android)

// Sugerir (o quitar) la red Wi-Fi de invitados de la iglesia en Android 10+ (ver WifiInvitadosPlugin.java).
// En otros teléfonos o en el navegador, todas las funciones devuelven false sin fallar.
class WifiInvitados { // Solo funciones estáticas
  static const _canal = MethodChannel('com.mcccanaan.canaan_app/wifi_invitados'); // Canal con Android

  static Future<bool> _llamar(String metodo, [Map<String, dynamic>? datos]) async { // Llama a Android sin lanzar errores
    try { return await _canal.invokeMethod<bool>(metodo, datos) ?? false; } catch (_) { return false; } // false si no existe (iPhone, navegador, pruebas)
  } // Fin de _llamar

  static Future<bool> soportado() => _llamar('soportado'); // ¿Android 10 o más nuevo?
  static Future<bool> wifiEncendido() => _llamar('wifiEncendido'); // ¿Wi-Fi encendido?
  static Future<bool> sugerir(String nombre, String contrasena) => _llamar('sugerir', {'nombre': nombre, 'contrasena': contrasena}); // Agrega la sugerencia
  static Future<bool> quitar(String nombre, String contrasena) => _llamar('quitar', {'nombre': nombre, 'contrasena': contrasena}); // Quita la sugerencia
  static Future<bool> abrirPanelWifi() => _llamar('abrirPanelWifi'); // Abre el panel de Wi-Fi (app abierta)
} // Fin de WifiInvitados
