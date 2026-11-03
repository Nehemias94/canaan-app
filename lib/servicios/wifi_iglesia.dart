import 'dart:convert'; // jsonEncode / jsonDecode (copia guardada)
import 'dart:io' show Platform; // ¿Es Android?

import 'package:flutter/foundation.dart'; // kIsWeb (navegador)
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Notificación "¿Sin internet?" al llegar (la crea el teléfono)
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Caja fuerte del teléfono
import 'package:geolocator/geolocator.dart'; // Ubicación (solo si ya dio permiso: la franja NO pide permisos)
import 'package:http/http.dart' as http; // Para probar si hay internet de verdad
import 'package:wifi_invitados/wifi_invitados.dart'; // Complemento propio: conectar solo la app a la red

import '../modelos/iglesia.dart'; // WifiIglesia
import 'geocerca.dart'; // distanciaMetros
import 'ubicacion.dart'; // Coordenadas

// Wi-Fi para invitados (solo Android 10+): SOLO la app Canaán usa la red de la iglesia (las demás apps del teléfono no),
// y solo para quien llega SIN internet y está en el área.
// 1) Geocerca (app cerrada; requiere "Avisarme al llegar a la iglesia"): al ENTRAR al área revisa si hay internet; si NO hay,
//    muestra la notificación "¿Sin internet?". Al tocarla se abre la app y se conecta sola. Al SALIR se quita la notificación.
//    (Android no deja conectar "solo la app" con la app cerrada: necesita su ventana "¿Conectar a…?", normalmente solo la primera vez.)
// 2) Con la app abierta sin internet en el área: la franja "¿Sin internet? Toca para conectarte".
// La conexión se suelta sola al cerrar la app o al salir del alcance del router. La ubicación nunca sale del teléfono.
class WifiIglesiaServicio { // Solo funciones estáticas
  static const _almacen = FlutterSecureStorage(); // Caja fuerte
  static const _claveCopia = 'wifi_copia'; // Datos de la red (JSON) que mandó el panel
  static const _claveEnArea = 'wifi_en_area'; // Hora en que la geocerca vio llegar al teléfono SIN internet (se borra al salir)
  static const _horasEnArea = 4; // Cuánto vale ese dato (un culto largo); después se vuelve a revisar con la ubicación
  static const idNotificacion = 990001; // Número de la notificación "¿Sin internet?" (no choca con anuncios ni recordatorios)
  static const toqueConectar = 'conectar_wifi'; // Marca de la notificación: al tocarla, la app se conecta sola
  static final ValueNotifier<bool> conexionPendiente = ValueNotifier(false); // true = la persona tocó la notificación: la franja conecta en cuanto pueda

  // Se pueden cambiar en las pruebas automáticas (no hay Android ni GPS de verdad):
  static bool Function() soportado = () => !kIsWeb && Platform.isAndroid; // ¿Este teléfono puede usarlo? (el complemento revisa además Android 10+)
  static Future<bool> Function() hayInternet = _hayInternetReal; // ¿Hay internet de verdad?
  static Future<void> Function() mostrarNotificacion = _mostrarNotificacionReal; // Muestra "¿Sin internet en la iglesia?"
  static Future<void> Function() quitarNotificacion = _quitarNotificacionReal; // La quita
  static Future<bool> Function(String, String) conectarRed = WifiInvitados.conectarSoloApp; // Conecta la app a la red (true = conectada)
  static Future<bool> Function() desconectarRed = WifiInvitados.desconectar; // Suelta la red
  static Future<Coordenadas?> Function() ubicacionSinPreguntar = _ubicacionSinPreguntarReal; // Dónde está (null = sin permiso o no se sabe)
  static Future<bool> Function() wifiEncendido = WifiInvitados.wifiEncendido; // ¿Wi-Fi encendido?
  static Future<bool> Function() abrirPanelWifi = WifiInvitados.abrirPanelWifi; // Abre el panelito de Wi-Fi

  static Future<bool> _hayInternetReal() async { // Pide una dirección de Google que responde "204" (la misma que usa Android para saber si hay internet)
    try { // Sin internet, o con un portal de bienvenida que intercepta, falla o responde otra cosa
      final r = await http.get(Uri.parse('https://connectivitycheck.gstatic.com/generate_204')).timeout(const Duration(seconds: 6)); // Máximo 6 s
      return r.statusCode == 204; // 204 = hay internet de verdad
    } catch (_) { return false; } // Sin respuesta: no hay internet
  } // Fin de _hayInternetReal

  static void alTocarNotificacion(NotificationResponse respuesta) { // Se tocó una notificación local (también la pasan los recordatorios al prepararse)
    if (respuesta.payload == toqueConectar) conexionPendiente.value = true; // Era la del Wi-Fi: la franja se conecta sola
  } // Fin de alTocarNotificacion

  static Future<void> prepararToques() async { // Al abrir la app: escucha los toques y revisa si se abrió desde la notificación del Wi-Fi
    if (!soportado()) return; // Solo Android
    try { // Cualquier falla: no pasa nada (la franja sigue disponible)
      final n = FlutterLocalNotificationsPlugin(); // Notificaciones locales
      await n.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')), onDidReceiveNotificationResponse: alTocarNotificacion); // Prepara y escucha los toques
      final inicio = await n.getNotificationAppLaunchDetails(); // ¿La app se abrió tocando una notificación?
      final toque = inicio?.notificationResponse; // El toque (si hubo)
      if (inicio?.didNotificationLaunchApp == true && toque != null) alTocarNotificacion(toque); // Sí: lo atiende
    } catch (_) {} // Falló
  } // Fin de prepararToques

  static Future<void> alEntrar() async { // La geocerca vio ENTRAR al teléfono al área (app cerrada o abierta)
    final wifi = await leerCopia(); // Datos guardados
    if (wifi == null) return; // El panel no ofrece Wi-Fi
    if (await hayInternet()) return; // Tiene datos o internet: no se le ofrece nada
    await _almacen.write(key: _claveEnArea, value: DateTime.now().toIso8601String()); // Anota que llegó sin internet (la franja no necesitará la ubicación)
    await mostrarNotificacion(); // Le ofrece el Wi-Fi con una notificación
  } // Fin de alEntrar

  static Future<void> _mostrarNotificacionReal() async { // Notificación "¿Sin internet en la iglesia?" (la crea el teléfono)
    final n = FlutterLocalNotificationsPlugin(); // Notificaciones locales
    await n.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'))); // Las prepara
    await n.show( // Muestra la notificación
      id: idNotificacion, // Siempre la misma (no se acumulan)
      title: '📶 ¿Sin internet en la iglesia?', // Título
      body: 'Toca para conectar la app Canaán al Wi-Fi de la iglesia (solo la app lo usará).', // Texto
      payload: toqueConectar, // Marca: al tocarla, la app se conecta sola
      notificationDetails: const NotificationDetails(android: AndroidNotificationDetails( // Cómo se ve en Android
        'geocerca', 'Avisos al llegar a la iglesia', // Mismo canal que los anuncios al llegar
        channelDescription: 'Anuncios que se muestran al llegar o al salir de la iglesia', // Descripción del canal
        importance: Importance.high, priority: Priority.high, // Aparece arriba de la pantalla
      )), // Fin
    ); // Fin de show
  } // Fin de _mostrarNotificacionReal

  static Future<void> _quitarNotificacionReal() async { // Quita la notificación "¿Sin internet?"
    final n = FlutterLocalNotificationsPlugin(); // Notificaciones locales
    await n.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'))); // Las prepara
    await n.cancel(id: idNotificacion); // La quita (si seguía ahí)
  } // Fin de _quitarNotificacionReal

  static Future<void> alSalir() async { // La geocerca vio SALIR al teléfono del área
    try { // Cualquier falla: no pasa nada
      await _almacen.delete(key: _claveEnArea); // Ya no está en el área
      await quitarNotificacion(); // Quita la notificación "¿Sin internet?" (si seguía ahí)
      await desconectarRed(); // Suelta la red si la app la estaba usando (también se suelta sola al salir del alcance)
    } catch (_) {} // Falló
  } // Fin de alSalir

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

  static Future<void> sincronizar(WifiIglesia? wifi) async { // Inicio lo llama con lo que mandó el panel: guarda la copia o, si se apagó, la borra
    if (!soportado()) return; // Solo Android
    try { // Cualquier falla: se intenta la próxima vez
      if (wifi == null) { // El panel apagó el servicio...
        await desconectarRed(); // ...suelta la red (si la app la estaba usando)
        await _almacen.delete(key: _claveCopia); // ...y olvida los datos
        return; // Fin
      } // Fin del if
      await _almacen.write(key: _claveCopia, value: jsonEncode(wifi.aJson())); // Guarda la copia (para usarla sin internet)
    } catch (_) {} // Falló: no pasa nada
  } // Fin de sincronizar

  static Future<bool?> ofrecerFranja() async { // ¿Mostrar "¿Sin internet? Toca para conectarte"? null = no; true = está en el área; false = no se sabe dónde está (sin permiso)
    if (!soportado()) return null; // Solo Android
    final wifi = await leerCopia(); // ¿El panel ofrece Wi-Fi?
    if (wifi == null) return null; // No
    try { // ¿La geocerca lo vio llegar sin internet hace poco?
      final llego = DateTime.tryParse(await _almacen.read(key: _claveEnArea) ?? ''); // Hora en que llegó
      if (llego != null && DateTime.now().difference(llego).inHours < _horasEnArea) return true; // Sí: está en el área (no hace falta la ubicación)
    } catch (_) {} // Falló: se revisa con la ubicación
    final aqui = await ubicacionSinPreguntar(); // Dónde está (sin pedir permisos)
    if (aqui == null) return false; // No se sabe: se ofrece preguntando "¿Estás en la iglesia?"
    final distancia = Geocerca.distanciaMetros(aqui.latitud, aqui.longitud, wifi.latitud, wifi.longitud); // Metros hasta el centro del área
    return distancia <= wifi.radioMetros ? true : null; // Dentro: se ofrece; lejos: no
  } // Fin de ofrecerFranja

  static Future<(bool, String)> conectarConUnToque() async { // Botón de la franja: conecta la app; devuelve (¿conectada?, mensaje)
    final wifi = await leerCopia(); // Datos guardados
    if (wifi == null) return (false, 'La iglesia no tiene Wi-Fi para invitados en este momento.'); // Ya no se ofrece
    if (!await wifiEncendido()) { // Wi-Fi apagado...
      await abrirPanelWifi(); // ...abre el panelito para encenderlo
      return (false, 'Enciende el Wi-Fi y vuelve a tocar la franja.'); // Instrucción
    } // Fin del if
    if (!await conectarRed(wifi.nombre, wifi.contrasena)) { // No se conectó (no la encontró, contraseña distinta o tocó "Cancelar")
      return (false, 'No se pudo conectar a «${wifi.nombre}». Revisa que estés cerca del router y, si Android pregunta, toca «Conectar».'); // Explicación
    } // Fin del if
    return (true, 'Conectado al Wi-Fi de la iglesia. Solo la app Canaán lo usa; las demás apps siguen con tus datos.'); // Éxito
  } // Fin de conectarConUnToque
} // Fin de WifiIglesiaServicio
