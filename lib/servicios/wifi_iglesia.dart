import 'dart:convert'; // jsonEncode / jsonDecode (copia guardada)
import 'dart:io' show Platform; // ¿Es Android?

import 'package:flutter/foundation.dart'; // kIsWeb (navegador)
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Caja fuerte del teléfono
import 'package:geolocator/geolocator.dart'; // Ubicación (solo si ya dio permiso: la franja NO pide permisos)
import 'package:http/http.dart' as http; // Para probar si hay internet de verdad
import 'package:wifi_invitados/wifi_invitados.dart'; // Complemento propio: sugerir / quitar la red

import '../modelos/iglesia.dart'; // WifiIglesia
import 'geocerca.dart'; // distanciaMetros
import 'ubicacion.dart'; // Coordenadas

// Wi-Fi para invitados (solo Android 10+): quien llega a la iglesia SIN internet recibe la sugerencia de la red y Android se conecta solo.
// A) Automático: la geocerca de fondo avisa al ENTRAR (alEntrar) y al SALIR (alSalir) del área, aunque la app esté cerrada.
// B) Con un toque: con la app abierta sin internet dentro del área, la franja "¿Sin internet?" llama a conectarConUnToque().
// Los datos de la red se guardan en el teléfono (copia) para funcionar sin internet. La ubicación nunca sale del teléfono.
class WifiIglesiaServicio { // Solo funciones estáticas
  static const _almacen = FlutterSecureStorage(); // Caja fuerte
  static const _claveCopia = 'wifi_copia'; // Datos de la red (JSON) que mandó el panel
  static const _claveSugerida = 'wifi_sugerida'; // Red que se le sugirió a Android (para poder quitarla al salir)

  // Se pueden cambiar en las pruebas automáticas (no hay Android ni GPS ni internet de verdad):
  static bool Function() soportado = () => !kIsWeb && Platform.isAndroid; // ¿Este teléfono puede usarlo? (el complemento revisa además Android 10+)
  static Future<bool> Function() hayInternet = _hayInternetReal; // ¿Hay internet de verdad?
  static Future<bool> Function(String, String) sugerirRed = WifiInvitados.sugerir; // Agrega la sugerencia
  static Future<bool> Function(String, String) quitarRed = WifiInvitados.quitar; // Quita la sugerencia
  static Future<Coordenadas?> Function() ubicacionSinPreguntar = _ubicacionSinPreguntarReal; // Dónde está (null = sin permiso o no se sabe)
  static Future<bool> Function() wifiEncendido = WifiInvitados.wifiEncendido; // ¿Wi-Fi encendido?
  static Future<bool> Function() abrirPanelWifi = WifiInvitados.abrirPanelWifi; // Abre el panelito de Wi-Fi

  static Future<bool> _hayInternetReal() async { // Pide una dirección de Google que responde "204" (la misma que usa Android para saber si hay internet)
    try { // Sin internet, o con un portal de bienvenida que intercepta, falla o responde otra cosa
      final r = await http.get(Uri.parse('https://connectivitycheck.gstatic.com/generate_204')).timeout(const Duration(seconds: 6)); // Máximo 6 s
      return r.statusCode == 204; // 204 = hay internet de verdad
    } catch (_) { return false; } // Sin respuesta: no hay internet
  } // Fin de _hayInternetReal

  static Future<Coordenadas?> _ubicacionSinPreguntarReal() async { // Ubicación SOLO si ya dio permiso (no muestra la ventana de permisos)
    try { // Cualquier falla = no se sabe
      final permiso = await Geolocator.checkPermission(); // ¿Ya dio permiso?
      if (permiso != LocationPermission.always && permiso != LocationPermission.whileInUse) return null; // No: no se pregunta aquí
      final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15))); // Ubicación (máx. 15 s)
      return Coordenadas(p.latitude, p.longitude); // La devuelve
    } catch (_) { return null; } // No se pudo
  } // Fin de _ubicacionSinPreguntarReal

  static Future<WifiIglesia?> leerCopia() async { // Datos de la red guardados (null = el panel no la ofrece)
    try { // La caja fuerte puede fallar
      final texto = await _almacen.read(key: _claveCopia); // Lee
      return texto == null ? null : WifiIglesia.desdeJson(jsonDecode(texto) as Map<String, dynamic>); // Convierte
    } catch (_) { return null; } // Falló: como si no hubiera
  } // Fin de leerCopia

  static Future<void> sincronizar(WifiIglesia? wifi) async { // Inicio lo llama con lo que mandó el panel: guarda la copia o, si se apagó, quita la red
    if (!soportado()) return; // Solo Android
    try { // Cualquier falla: se intenta la próxima vez
      final anterior = await leerCopia(); // Lo que había
      if (wifi == null) { // El panel apagó el servicio...
        await alSalir(); // ...quita la sugerencia (si había)
        await _almacen.delete(key: _claveCopia); // ...y olvida la red
        return; // Fin
      } // Fin del if
      if (anterior != null && (anterior.nombre != wifi.nombre || anterior.contrasena != wifi.contrasena)) await alSalir(); // Cambió la red o la contraseña: quita la vieja (la nueva se sugiere al llegar)
      await _almacen.write(key: _claveCopia, value: jsonEncode(wifi.aJson())); // Guarda la copia
    } catch (_) {} // Falló: no pasa nada
  } // Fin de sincronizar

  static Future<void> alEntrar() async { // El teléfono ENTRÓ al área (geocerca, app cerrada o abierta)
    final wifi = await leerCopia(); // Datos guardados
    if (wifi == null) return; // El panel no ofrece Wi-Fi
    if (await hayInternet()) return; // Tiene datos o internet: se queda con lo suyo
    await _sugerir(wifi); // Sin internet: le sugiere la red a Android
  } // Fin de alEntrar

  static Future<void> alSalir() async { // El teléfono SALIÓ del área: quita la sugerencia (el próximo culto vuelve a decidir)
    try { // Cualquier falla: no pasa nada
      final sugerida = await _almacen.read(key: _claveSugerida); // ¿Qué red se sugirió? ("nombre\ncontraseña")
      if (sugerida == null) return; // Ninguna
      final partes = sugerida.split('\n'); // Separa nombre y contraseña
      await quitarRed(partes.first, partes.length > 1 ? partes[1] : ''); // La quita (Android se desconecta de ella)
      await _almacen.delete(key: _claveSugerida); // Olvida
    } catch (_) {} // Falló
  } // Fin de alSalir

  static Future<bool> _sugerir(WifiIglesia wifi) async { // Agrega la sugerencia y anota cuál fue
    final bien = await sugerirRed(wifi.nombre, wifi.contrasena); // Se la da a Android
    if (bien) await _almacen.write(key: _claveSugerida, value: '${wifi.nombre}\n${wifi.contrasena}'); // Anota (para quitarla al salir)
    return bien; // ¿Salió bien?
  } // Fin de _sugerir

  static Future<bool?> ofrecerFranja() async { // ¿Mostrar "¿Sin internet? Toca para conectarte"? null = no; true = está en el área; false = no se sabe dónde está (sin permiso)
    if (!soportado()) return null; // Solo Android
    final wifi = await leerCopia(); // ¿El panel ofrece Wi-Fi?
    if (wifi == null) return null; // No
    final aqui = await ubicacionSinPreguntar(); // Dónde está (sin pedir permisos)
    if (aqui == null) return false; // No se sabe: se ofrece preguntando "¿Estás en la iglesia?"
    final distancia = Geocerca.distanciaMetros(aqui.latitud, aqui.longitud, wifi.latitud, wifi.longitud); // Metros hasta el centro del área
    return distancia <= wifi.radioMetros ? true : null; // Dentro: se ofrece; lejos: no
  } // Fin de ofrecerFranja

  static Future<String> conectarConUnToque() async { // Botón de la franja: sugiere la red y, si el Wi-Fi está apagado, abre su panel
    final wifi = await leerCopia(); // Datos guardados
    if (wifi == null) return 'La iglesia no tiene Wi-Fi para invitados en este momento.'; // Ya no se ofrece
    if (!await _sugerir(wifi)) return 'Este teléfono no permite sugerir redes (requiere Android 10 o más nuevo). Conéctate a la red «${wifi.nombre}» desde los ajustes de Wi-Fi.'; // Teléfono viejo
    if (!await wifiEncendido()) { // Wi-Fi apagado...
      await abrirPanelWifi(); // ...abre el panelito para encenderlo
      return 'Enciende el Wi-Fi: el teléfono se conectará solo a «${wifi.nombre}».'; // Instrucción
    } // Fin del if
    return 'Listo: el teléfono se conectará a «${wifi.nombre}» en unos segundos. Si Android pregunta "¿Permitir sugerencias de red?", toca Permitir.'; // Éxito
  } // Fin de conectarConUnToque
} // Fin de WifiIglesiaServicio
