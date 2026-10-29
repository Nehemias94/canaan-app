import 'dart:io' show Platform; // Saber si es Android o iPhone (en las pruebas en la PC es Windows: la geocerca de fondo no se usa)
import 'dart:math'; // max (radio mínimo)

import 'package:flutter/foundation.dart'; // kIsWeb (navegador) y debugPrint
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Notificación "local" (la crea el teléfono, no Firebase)
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Caja fuerte: recordar si la persona activó la opción
import 'package:native_geofence/native_geofence.dart'; // Geocerca nativa de Android/iPhone (funciona con la app cerrada y gasta poca batería)
import 'package:permission_handler/permission_handler.dart'; // Pedir permisos (ubicación "todo el tiempo" y notificaciones)

import '../modelos/anuncio.dart'; // Molde de un anuncio
import '../modelos/iglesia.dart'; // Molde de la iglesia (ubicación y radio)
import 'api.dart'; // Para pedir los anuncios cuando el teléfono entra a la iglesia
import 'geocerca.dart'; // Lista de anuncios ya mostrados (compartida con la geocerca de la app abierta)

// Geocerca con la app CERRADA (Paso 11). Es OPCIONAL: la persona la activa en Más → "Avisarme al llegar a la iglesia".
// Cómo funciona: se le dice al sistema del teléfono "avísame cuando entre a este círculo" (templo + radio).
// Al entrar, el teléfono despierta a la app un momento (sin abrirla), esta pide los anuncios "Solo área"
// y, si hay alguno en su ventana y no mostrado, crea una notificación. La ubicación NUNCA sale del teléfono.
class GeocercaFondo { // Todo lo de la geocerca de fondo
  static const _idGeocerca = 'iglesia'; // Nombre del círculo registrado en el teléfono
  static const _claveActiva = 'geocerca_fondo'; // Caja fuerte: "si" = la persona la activó
  static const _claveLugar = 'geocerca_fondo_lugar'; // Caja fuerte: lugar registrado ("lat,lng,radio"), para saber si cambió
  static const _almacen = FlutterSecureStorage(); // Caja fuerte

  static bool get soportada => !kIsWeb && (Platform.isAndroid || Platform.isIOS); // Solo en teléfonos (no en el navegador ni en las pruebas)

  static Future<bool> estaActiva() async { // ¿La persona la activó?
    if (!soportada) return false; // En el navegador nunca
    try { return await _almacen.read(key: _claveActiva) == 'si'; } catch (_) { return false; } // Lee la caja fuerte
  } // Fin de estaActiva

  static Future<String?> activar(Iglesia iglesia) async { // Pide permisos y registra el círculo; devuelve null si salió bien o el motivo si no
    if (!iglesia.tieneUbicacion) return 'La iglesia todavía no tiene su ubicación configurada.'; // Sin ubicación del templo no hay círculo
    if (!await Permission.location.request().isGranted) { // 1) Ubicación mientras se usa la app
      return 'Necesitamos permiso de ubicación para saber cuándo llegas a la iglesia.'; // Dijo que no
    } // Fin del if
    if (!await Permission.locationAlways.request().isGranted) { // 2) Ubicación "todo el tiempo" (Android abre Ajustes: hay que elegir "Permitir todo el tiempo")
      return 'Para avisarte con la app cerrada, elige "Permitir todo el tiempo" en el permiso de ubicación.'; // No eligió "todo el tiempo"
    } // Fin del if
    await Permission.notification.request(); // 3) Notificaciones (Android 13+ / iPhone); si dice que no, igual se registra (no verá el aviso)
    try { // Registrar puede fallar (servicios de Google apagados, etc.)
      await _registrar(iglesia); // Registra el círculo en el teléfono
      await _almacen.write(key: _claveActiva, value: 'si'); // Recuerda que está activa
      return null; // Todo bien
    } catch (error) { // Falló
      debugPrint('Geocerca de fondo: no se pudo registrar: $error'); // Detalle en la consola de desarrollo
      return 'No pudimos activar el aviso en este teléfono. Intenta de nuevo más tarde.'; // Mensaje amable
    } // Fin del try
  } // Fin de activar

  static Future<void> desactivar() async { // Quita el círculo y olvida la opción
    try { // Por si no estaba registrado
      await NativeGeofenceManager.instance.initialize(); // Prepara el paquete
      await NativeGeofenceManager.instance.removeGeofenceById(_idGeocerca); // Quita el círculo
    } catch (_) {} // Si no existía, no pasa nada
    await _almacen.delete(key: _claveActiva); // Olvida que estaba activa
    await _almacen.delete(key: _claveLugar); // Olvida el lugar
  } // Fin de desactivar

  static Future<void> actualizar(Iglesia iglesia) async { // Se llama al cargar Inicio: si el panel cambió la ubicación o el radio, vuelve a registrar el círculo
    if (!await estaActiva()) return; // La persona no la activó: nada
    try { // Cualquier falla aquí no debe afectar a Inicio
      if (!iglesia.tieneUbicacion) return await desactivar(); // El panel quitó la ubicación: quita el círculo
      if (await _almacen.read(key: _claveLugar) == _lugar(iglesia)) return; // Mismo lugar: nada que hacer
      if (!await Permission.locationAlways.isGranted) return; // Le quitaron el permiso en Ajustes: no se puede registrar
      await _registrar(iglesia); // Lugar nuevo: vuelve a registrar
    } catch (error) { // Falló
      debugPrint('Geocerca de fondo: no se pudo actualizar: $error'); // Solo lo anota
    } // Fin del try
  } // Fin de actualizar

  static String _lugar(Iglesia iglesia) => '${iglesia.latitud},${iglesia.longitud},${iglesia.radioMetros}'; // Ej: "13.69,-89.21,200"

  static Future<void> _registrar(Iglesia iglesia) async { // Registra (o reemplaza) el círculo del templo en el teléfono
    final gestor = NativeGeofenceManager.instance; // Atajo
    await gestor.initialize(); // Prepara el paquete
    try { await gestor.removeGeofenceById(_idGeocerca); } catch (_) {} // Quita el anterior, si había
    await gestor.createGeofence( // Registra el círculo
      Geofence( // Datos del círculo
        id: _idGeocerca, // Nombre
        location: Location(latitude: iglesia.latitud!, longitude: iglesia.longitud!), // Centro: el templo
        radiusMeters: max(iglesia.radioMetros, 100).toDouble(), // Radio (mínimo 100 m: con menos, el teléfono avisa tarde o nunca)
        triggers: {GeofenceEvent.enter}, // Avisar solo al ENTRAR
        iosSettings: const IosGeofenceSettings(initialTrigger: true), // iPhone: si ya está adentro al activarlo, cuenta como entrar
        androidSettings: const AndroidGeofenceSettings( // Android
          initialTriggers: {GeofenceEvent.enter}, // Si ya está adentro al activarlo, cuenta como entrar
          notificationResponsiveness: Duration(minutes: 2), // Puede avisar con hasta 2 min de retraso (ahorra batería)
        ), // Fin de Android
      ), // Fin del círculo
      geocercaEntro, // Función que se ejecuta al entrar (abajo)
    ); // Fin del registro
    await _almacen.write(key: _claveLugar, value: _lugar(iglesia)); // Anota el lugar registrado
  } // Fin de _registrar
} // Fin de GeocercaFondo

// Se ejecuta cuando el teléfono ENTRA al círculo del templo, aunque la app esté cerrada.
// Debe ser una función "suelta" (fuera de una clase) con @pragma: así Android/iPhone la encuentran al despertar la app.
@pragma('vm:entry-point') // No borrar: sin esto, la versión final de la app la eliminaría por "no usada"
Future<void> geocercaEntro(GeofenceCallbackParams params) async { // Datos del aviso del teléfono
  if (params.event != GeofenceEvent.enter) return; // Solo nos interesa "entró"
  try { // Cualquier falla: no hace nada (no hay pantalla donde mostrar errores)
    final geocerca = Geocerca(); // Copia guardada y lista compartida de anuncios ya mostrados
    final copia = await geocerca.leerCopia(); // 1) Primero la copia que guardó Inicio: es instantánea y no necesita internet
    var anuncios = copia?.anuncios ?? <Anuncio>[]; // Anuncios de la copia (vacío si no hay)
    final copiaVieja = copia == null || DateTime.now().difference(copia.guardada) > Geocerca.vigenciaCopia; // ¿No hay copia o tiene más de 12 h?
    if (copiaVieja || (await geocerca.pendientes(anuncios, DateTime.now())).isEmpty) { // 2) Si la copia es vieja o no trae nada pendiente (pudo crearse un anuncio después)...
      try { // ...intenta preguntar al panel
        anuncios = await const Api().obtenerAnuncios().timeout(const Duration(seconds: 40)); // 40 s: el panel gratis tarda ~50 s en despertar; iPhone corta a los 60 s
        await geocerca.guardarCopia(anuncios); // Actualiza la copia
      } catch (_) {} // Sin internet o panel dormido: se queda con la copia (si había)
    } // Fin del if
    final nuevos = await geocerca.pendientes(anuncios, DateTime.now()); // De área, en su ventana y no mostrados
    if (nuevos.isEmpty) return; // Nada que avisar
    await geocerca.marcarMostrados(nuevos); // Los marca ANTES de avisar: cada anuncio se muestra una sola vez en total (al abrir la app ya no sale la ventana de bienvenida)

    final notificaciones = FlutterLocalNotificationsPlugin(); // Notificaciones locales
    await notificaciones.initialize( // Las prepara
      settings: const InitializationSettings( // Ajustes por plataforma
        android: AndroidInitializationSettings('@mipmap/ic_launcher'), // Ícono de la notificación (el de la app)
        iOS: DarwinInitializationSettings( // iPhone: los permisos ya se pidieron al activar la opción
          requestAlertPermission: false, // No volver a preguntar
          requestBadgePermission: false, // No volver a preguntar
          requestSoundPermission: false, // No volver a preguntar
        ), // Fin de iPhone
      ), // Fin de los ajustes
    ); // Fin de la preparación
    for (final anuncio in nuevos) { // Una notificación por anuncio
      await notificaciones.show( // La muestra
        id: anuncio.id, // Número del anuncio (si llega dos veces, reemplaza la anterior)
        title: '📍 ${anuncio.titulo}', // Título con el pin
        body: anuncio.mensaje, // Texto del anuncio
        notificationDetails: const NotificationDetails( // Cómo se ve
          android: AndroidNotificationDetails( // Android
            'geocerca', // Canal
            'Avisos al llegar a la iglesia', // Nombre del canal (Ajustes → Notificaciones)
            channelDescription: 'Anuncios que se muestran cuando estás en el templo', // Descripción del canal
            importance: Importance.high, // Aparece arriba de la pantalla
            priority: Priority.high, // Prioridad alta
          ), // Fin de Android
          iOS: DarwinNotificationDetails(), // iPhone: valores por defecto
        ), // Fin de cómo se ve
      ); // Fin de show
    } // Fin del for
  } catch (error) { // Sin internet, panel dormido demasiado tiempo, etc.
    debugPrint('Geocerca de fondo: no se pudo avisar: $error'); // Solo lo anota
  } // Fin del try
} // Fin de geocercaEntro
