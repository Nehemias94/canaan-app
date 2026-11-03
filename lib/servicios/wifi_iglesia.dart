import 'dart:async'; // Completer (esperar a que la persona vuelva de WhatsApp)
import 'dart:convert'; // jsonEncode / jsonDecode (copia guardada)
import 'dart:io' show Platform; // ¿Es Android?

import 'package:flutter/foundation.dart'; // kIsWeb (navegador)
import 'package:flutter/material.dart'; // Ventana "¿Conectar todo el teléfono?" y avisos
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
// 3) Al COMPARTIR (si el panel lo permite), SIN preguntar: como WhatsApp no tiene internet, la red se abre para TODO el teléfono
//    solo ese momento (WifiNetworkSuggestion); al volver a Canaán se cierra y queda otra vez SOLO para la app.
//    Si algo falla, se cierra al salir del área (geocerca) o a las 4 horas.
class WifiIglesiaServicio { // Solo funciones estáticas
  static const _almacen = FlutterSecureStorage(); // Caja fuerte
  static const _claveCopia = 'wifi_copia'; // Datos de la red (JSON) que mandó el panel
  static const _claveEnArea = 'wifi_en_area'; // Hora en que la geocerca vio llegar al teléfono SIN internet (se borra al salir)
  static const _horasEnArea = 4; // Cuánto vale ese dato (un culto largo); después se vuelve a revisar con la ubicación
  static const idNotificacion = 990001; // Número de la notificación "¿Sin internet?" (no choca con anuncios ni recordatorios)
  static const toqueConectar = 'conectar_wifi'; // Marca de la notificación: al tocarla, la app se conecta sola
  static const _claveTodo = 'wifi_todo_telefono'; // Red puesta para TODO el teléfono ("nombre\ncontraseña\nhora"), para quitarla después
  static const _horasTodo = 4; // A las 4 horas se quita sola (por si la geocerca no avisó la salida)
  static final llaveAvisos = GlobalKey<ScaffoldMessengerState>(); // Avisos de abajo de toda la app ("Un momento…" si compartir tarda)
  static Duration avisoSiTarda = const Duration(seconds: 2); // Si preparar el Wi-Fi tarda más que esto, sale "Un momento…" (si es rápido, no sale nada)
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
  static Future<bool> Function() appConectada = WifiInvitados.conectado; // ¿La app está usando la red "solo para la app"?
  static Future<bool> Function(String, String) ponerTodo = WifiInvitados.sugerir; // Pone la red para TODO el teléfono
  static Future<bool> Function(String, String) quitarTodo = WifiInvitados.quitar; // La quita de todo el teléfono
  static Duration esperaInternet = const Duration(seconds: 30); // Cuánto se espera a que el teléfono tenga internet (en pruebas, menos)

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
      await quitarTodoElTelefono(); // Si se puso para todo el teléfono (al compartir), la quita
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
      final todo = await _leerTodo(); // ¿Se puso la red para todo el teléfono?
      if (todo != null && (wifi == null || DateTime.now().difference(todo.$3).inHours >= _horasTodo)) await quitarTodoElTelefono(); // Servicio apagado o pasaron 4 horas: la quita
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

  static Future<(String, String, DateTime)?> _leerTodo() async { // Red puesta para todo el teléfono: (nombre, contraseña, hora) o null
    try { // La caja fuerte puede fallar
      final partes = (await _almacen.read(key: _claveTodo))?.split('\n'); // "nombre\ncontraseña\nhora"
      if (partes == null || partes.length < 3) return null; // No hay
      return (partes[0], partes[1], DateTime.tryParse(partes[2]) ?? DateTime.now()); // Datos
    } catch (_) { return null; } // Falló
  } // Fin de _leerTodo

  static Future<void> quitarTodoElTelefono() async { // Quita la red de todo el teléfono (si se había puesto al compartir)
    final todo = await _leerTodo(); // ¿Había?
    if (todo == null) return; // No
    await quitarTodo(todo.$1, todo.$2); // La quita (Android se desconecta de ella)
    try { await _almacen.delete(key: _claveTodo); } catch (_) {} // Olvida
  } // Fin de quitarTodoElTelefono

  static bool _compartiendo = false; // true mientras la red está abierta para todo el teléfono por un "Compartir"

  static Future<void> antesDeCompartir() async { // Lo llama cada "Compartir": si la app usa el Wi-Fi "solo para la app", lo abre para TODO el teléfono (sin preguntar) para que WhatsApp pueda enviar
    if (!soportado()) return; // Solo Android
    final wifi = await leerCopia(); // ¿El panel ofrece Wi-Fi?
    if (wifi == null || !wifi.todoElTelefono) return; // No ofrece, o el panel no lo permite: se comparte normal (WhatsApp enviará cuando haya datos)
    if (!await appConectada()) return; // La app no usa el Wi-Fi "solo para la app": el teléfono tiene sus datos (o no está en la iglesia)
    final avisos = llaveAvisos.currentState; // Avisos de abajo
    var mostrado = false; // ¿Ya salió "Un momento…"?
    final reloj = Timer(avisoSiTarda, () { // Solo si tarda más de 2 s (para que no parezca que el botón no hace nada)
      mostrado = true; // Salió
      avisos?.showSnackBar(const SnackBar(content: Text('Un momento… preparando para compartir'), duration: Duration(seconds: 30))); // Texto sencillo, sin hablar del Wi-Fi
    }); // Fin del reloj
    await desconectarRed(); // Suelta la conexión "solo la app" (ahora la tendrá todo el teléfono)
    final puesta = await ponerTodo(wifi.nombre, wifi.contrasena); // Pone la red para todo el teléfono
    if (puesta) { // Anota (para cerrarla al terminar, o a las 4 horas si algo falla)
      _compartiendo = true; // Abierta por compartir
      await _almacen.write(key: _claveTodo, value: '${wifi.nombre}\n${wifi.contrasena}\n${DateTime.now().toIso8601String()}'); // Datos
    } // Fin del if
    var conInternet = false; // ¿Ya tiene internet todo el teléfono?
    final limite = DateTime.now().add(esperaInternet); // Hasta cuándo esperar
    while (puesta && !conInternet && DateTime.now().isBefore(limite)) { // Espera a que Android se conecte
      conInternet = await hayInternet(); // ¿Ya?
      if (!conInternet) await Future.delayed(const Duration(seconds: 2)); // Todavía no: espera un poco
    } // Fin de la espera
    reloj.cancel(); // Si terminó antes de 2 s, el aviso ya no sale
    if (mostrado) avisos?.hideCurrentSnackBar(); // Si salió, lo quita
    if (conInternet) return; // Listo: se abre la ventana de compartir y WhatsApp tiene internet
    await despuesDeCompartir(esperar: false); // No se conectó: vuelve a dejar el Wi-Fi solo para la app
    avisos?.showSnackBar(const SnackBar(duration: Duration(seconds: 10), content: Text('No se pudo abrir el Wi-Fi para WhatsApp: se enviará cuando tengas datos. Si Android muestra arriba "¿Permitir redes sugeridas por Canaán?", toca Permitir.'))); // Explicación
  } // Fin de antesDeCompartir

  static Future<void> Function() esperarRegreso = _esperarRegresoReal; // Espera a que la persona termine de compartir y vuelva a Canaán (en pruebas, nada)

  static Future<void> _esperarRegresoReal() async { // Espera: salir a WhatsApp → volver a Canaán (+ unos segundos para que termine de enviar)
    final binding = WidgetsBinding.instance; // Estado de la app
    final salio = Completer<void>(); // Se completa cuando la app pasa a segundo plano (abrió WhatsApp)
    final volvio = Completer<void>(); // Se completa cuando la persona regresa a Canaán
    final escucha = AppLifecycleListener( // Escucha el estado de la app
      onPause: () { if (!salio.isCompleted) salio.complete(); }, // Se fue a otra app
      onResume: () { if (salio.isCompleted && !volvio.isCompleted) volvio.complete(); }, // Regresó
    ); // Fin de la escucha
    try { // Siempre se suelta la escucha
      if (binding.lifecycleState != AppLifecycleState.resumed && !salio.isCompleted) salio.complete(); // Ya estaba fuera
      final seFue = await Future.any([salio.future.then((_) => true), Future.delayed(const Duration(seconds: 4), () => false)]); // ¿Se fue a otra app en 4 s? (si cerró la ventana sin elegir, no)
      if (!seFue) return; // No compartió: se cierra ya
      await Future.any([volvio.future, Future.delayed(const Duration(minutes: 15))]); // Espera a que vuelva (máximo 15 min)
      await Future.delayed(const Duration(seconds: 8)); // Unos segundos para que WhatsApp termine de enviar
    } finally { // Al final
      escucha.dispose(); // Deja de escuchar
    } // Fin del try
  } // Fin de _esperarRegresoReal

  static Future<void> despuesDeCompartir({bool esperar = true}) async { // Lo llama cada "Compartir" al terminar: vuelve a dejar el Wi-Fi SOLO para la app
    if (!_compartiendo) return; // No se abrió para todo el teléfono
    if (esperar) await esperarRegreso(); // Espera a que termine de compartir
    _compartiendo = false; // Ya no
    await quitarTodoElTelefono(); // Cierra la red para las demás apps
    final wifi = await leerCopia(); // Datos guardados
    if (wifi != null) await conectarRed(wifi.nombre, wifi.contrasena); // Canaán vuelve a usarla (Android normalmente ya no pregunta)
  } // Fin de despuesDeCompartir

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
