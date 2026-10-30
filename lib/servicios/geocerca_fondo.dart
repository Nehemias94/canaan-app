import 'dart:io' show Platform; // Saber si es Android o iPhone (en las pruebas en la PC es Windows: la geocerca de fondo no se usa)
import 'dart:math'; // max (radio mínimo)

import 'package:flutter/foundation.dart'; // kIsWeb (navegador) y debugPrint
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Notificación "local" (la crea el teléfono, no Firebase)
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Caja fuerte: recordar si la persona activó la opción
import 'package:native_geofence/native_geofence.dart'; // Geocerca nativa de Android/iPhone (funciona con la app cerrada y gasta poca batería)
import 'package:permission_handler/permission_handler.dart'; // Pedir permisos (ubicación "todo el tiempo" y notificaciones)

import '../modelos/anuncio.dart'; // Molde de un anuncio
import '../modelos/iglesia.dart'; // Molde de la iglesia (ubicación y radio)
import 'api.dart'; // Para pedir los anuncios cuando el teléfono entra a un área
import 'geocerca.dart'; // Lista de anuncios ya mostrados y copia guardada (compartidas con la geocerca de la app abierta)

// Geocerca con la app CERRADA (Paso 11). Es OPCIONAL: la persona la activa en Servicios → "Avisarme al llegar a la iglesia".
// Cómo funciona: se le dice al sistema del teléfono "avísame cuando entre (o salga) de este círculo".
// Se registran: 1) el círculo de la iglesia (respaldo: al entrar revisa los anuncios "al llegar, enseguida") y
// 2) un círculo POR CADA anuncio "Solo área" pendiente, con su propia área y su momento: al entrar, al quedarse N minutos (Android) o al salir.
// Al pasar, el teléfono despierta a la app un momento (sin abrirla) y esta crea la notificación. La ubicación NUNCA sale del teléfono.
class GeocercaFondo { // Todo lo de la geocerca de fondo
  static const _idGeocerca = 'iglesia'; // Nombre del círculo de la iglesia registrado en el teléfono
  static const prefijoAnuncio = 'anuncio-'; // Nombre de los círculos de cada anuncio: "anuncio-15"
  static const _maxAnuncios = 15; // Máximo de círculos de anuncios (iPhone permite 20 en total por app)
  static const _claveActiva = 'geocerca_fondo'; // Caja fuerte: "si" = la persona la activó
  static const _claveLugar = 'geocerca_fondo_lugar'; // Caja fuerte: lugar de la iglesia registrado ("lat,lng,radio"), para saber si cambió
  static const _claveAnuncios = 'geocerca_fondo_anuncios'; // Caja fuerte: firma de los círculos de anuncios registrados, para saber si cambiaron
  static const _almacen = FlutterSecureStorage(); // Caja fuerte

  static bool get soportada => !kIsWeb && (Platform.isAndroid || Platform.isIOS); // Solo en teléfonos (no en el navegador ni en las pruebas)

  static Future<bool> estaActiva() async { // ¿La persona la activó?
    if (!soportada) return false; // En el navegador nunca
    try { return await _almacen.read(key: _claveActiva) == 'si'; } catch (_) { return false; } // Lee la caja fuerte
  } // Fin de estaActiva

  static Future<String?> activar(Iglesia iglesia) async { // Pide permisos y registra los círculos; devuelve null si salió bien o el motivo si no
    if (!await Permission.location.request().isGranted) { // 1) Ubicación mientras se usa la app
      return 'Necesitamos permiso de ubicación para saber cuándo llegas a la iglesia.'; // Dijo que no
    } // Fin del if
    if (!await Permission.locationAlways.request().isGranted) { // 2) Ubicación "todo el tiempo" (Android abre Ajustes: hay que elegir "Permitir todo el tiempo")
      return 'Para avisarte con la app cerrada, elige "Permitir todo el tiempo" en el permiso de ubicación.'; // No eligió "todo el tiempo"
    } // Fin del if
    await Permission.notification.request(); // 3) Notificaciones (Android 13+ / iPhone); si dice que no, igual se registra (no verá el aviso)
    try { // Registrar puede fallar (servicios de Google apagados, etc.)
      if (iglesia.tieneUbicacion) await _registrar(iglesia); // Círculo de la iglesia (respaldo), si el panel tiene la ubicación
      await _almacen.write(key: _claveActiva, value: 'si'); // Recuerda que está activa
      final copia = await Geocerca().leerCopia(); // Anuncios "Solo área" que ya tiene el teléfono
      await sincronizarAnuncios(copia?.anuncios ?? const [], iglesia); // Un círculo por anuncio pendiente
      return null; // Todo bien
    } catch (error) { // Falló
      debugPrint('Geocerca de fondo: no se pudo registrar: $error'); // Detalle en la consola de desarrollo
      return 'No pudimos activar el aviso en este teléfono. Intenta de nuevo más tarde.'; // Mensaje amable
    } // Fin del try
  } // Fin de activar

  static Future<void> desactivar() async { // Quita todos los círculos y olvida la opción
    try { // Por si no había nada registrado
      await NativeGeofenceManager.instance.initialize(); // Prepara el paquete
      await NativeGeofenceManager.instance.removeAllGeofences(); // Quita la iglesia y los anuncios
    } catch (_) {} // Si no existían, no pasa nada
    await _almacen.delete(key: _claveActiva); // Olvida que estaba activa
    await _almacen.delete(key: _claveLugar); // Olvida el lugar
    await _almacen.delete(key: _claveAnuncios); // Olvida los anuncios registrados
  } // Fin de desactivar

  static Future<void> actualizar(Iglesia iglesia, [List<Anuncio>? anuncios]) async { // Se llama al cargar Inicio: vuelve a registrar lo que haya cambiado en el panel
    if (!await estaActiva()) return; // La persona no la activó: nada
    try { // Cualquier falla aquí no debe afectar a Inicio
      if (!await Permission.locationAlways.isGranted) return; // Le quitaron el permiso en Ajustes: no se puede registrar
      if (!iglesia.tieneUbicacion) { // El panel quitó la ubicación de la iglesia...
        await _quitar(_idGeocerca); // ...quita solo su círculo (los anuncios con área propia siguen)
        await _almacen.delete(key: _claveLugar); // ...y olvida el lugar
      } else if (await _almacen.read(key: _claveLugar) != _lugar(iglesia)) { // Lugar nuevo (o nunca registrado)...
        await _registrar(iglesia); // ...vuelve a registrar
      } // Fin del if
      if (anuncios != null) await sincronizarAnuncios(anuncios, iglesia); // Círculos de los anuncios
    } catch (error) { // Falló
      debugPrint('Geocerca de fondo: no se pudo actualizar: $error'); // Solo lo anota
    } // Fin del try
  } // Fin de actualizar

  static Future<void> sincronizarAnuncios(List<Anuncio> anuncios, Iglesia? iglesia) async { // Deja registrado un círculo por cada anuncio "Solo área" pendiente (lo llaman Inicio y el aviso silencioso del panel)
    if (!await estaActiva()) return; // La persona no la activó: nada
    try { // Cualquier falla: se intenta la próxima vez
      if (!await Permission.locationAlways.isGranted) return; // Sin permiso "todo el tiempo" no se puede
      final ahora = DateTime.now(); // Hora actual
      final vistos = await Geocerca().mostrados(); // Ya mostrados: no hace falta vigilarlos
      final deseados = <(Anuncio, ZonaAnuncio)>[]; // Anuncios a vigilar, con su área
      for (final a in anuncios) { // Revisa cada uno
        final zona = Geocerca.zonaDe(a, iglesia); // Su área
        final vigente = a.tipo == 'area' && a.terminaEn != null && a.terminaEn!.isAfter(ahora); // De área y su ventana no ha terminado (puede empezar después)
        if (vigente && zona != null && !vistos.contains(a.id)) deseados.add((a, zona)); // Se vigila
      } // Fin del for
      deseados.sort((x, y) => x.$1.iniciaEn!.compareTo(y.$1.iniciaEn!)); // Los que empiezan antes primero
      final lista = deseados.take(_maxAnuncios).toList(); // Hasta el máximo
      final firma = lista.map((d) => '${d.$1.id}:${d.$2.firma}:${d.$1.disparo}:${d.$1.minutos}').join('|'); // Resumen de lo que debe quedar registrado
      if (await _almacen.read(key: _claveAnuncios) == firma) return; // Igual que antes: nada que hacer
      final gestor = NativeGeofenceManager.instance; // Atajo
      await gestor.initialize(); // Prepara el paquete
      for (final id in await gestor.getRegisteredGeofenceIds()) { // Quita los círculos de anuncios anteriores
        if (id.startsWith(prefijoAnuncio)) await _quitar(id); // (la iglesia se queda)
      } // Fin del for
      for (final (anuncio, zona) in lista) { // Registra los nuevos
        await gestor.createGeofence(_circuloDeAnuncio(anuncio, zona), geocercaEntro); // Círculo + función que se ejecuta al pasar
      } // Fin del for
      await _almacen.write(key: _claveAnuncios, value: firma); // Anota lo registrado
    } catch (error) { // Falló
      debugPrint('Geocerca de fondo: no se pudieron registrar los anuncios: $error'); // Solo lo anota
    } // Fin del try
  } // Fin de sincronizarAnuncios

  static GeofenceEvent eventoDe(Anuncio anuncio, {required bool esIphone}) { // Qué evento del teléfono corresponde al anuncio
    if (anuncio.alSalir) return GeofenceEvent.exit; // Al salir
    if (anuncio.minutos > 0 && !esIphone) return GeofenceEvent.dwell; // Al llegar y quedarse N minutos (solo Android: iPhone no lo tiene)
    return GeofenceEvent.enter; // Al llegar, enseguida
  } // Fin de eventoDe

  static Geofence _circuloDeAnuncio(Anuncio anuncio, ZonaAnuncio zona) { // Datos del círculo de un anuncio
    final evento = eventoDe(anuncio, esIphone: Platform.isIOS); // Entrar, quedarse o salir
    return Geofence( // Círculo
      id: '$prefijoAnuncio${anuncio.id}', // Nombre, ej: "anuncio-15"
      location: Location(latitude: zona.latitud, longitude: zona.longitud), // Centro del área
      radiusMeters: max(zona.radioMetros, 100).toDouble(), // Radio (mínimo 100 m: con menos, el teléfono avisa tarde o nunca)
      triggers: {evento}, // Solo el evento que le toca
      iosSettings: IosGeofenceSettings(initialTrigger: evento == GeofenceEvent.enter), // iPhone: si ya está adentro al registrarlo, cuenta como entrar (no aplica a "salir")
      androidSettings: AndroidGeofenceSettings( // Android
        initialTriggers: evento == GeofenceEvent.exit ? const {} : {evento}, // Si ya está adentro al registrarlo, cuenta (al salir no: avisaría a todos los que están lejos)
        loiteringDelay: Duration(minutes: max(anuncio.minutos, 1)), // "Quedarse": minutos adentro antes de avisar
        notificationResponsiveness: const Duration(minutes: 2), // Puede avisar con hasta 2 min de retraso (ahorra batería)
      ), // Fin de Android
    ); // Fin del círculo
  } // Fin de _circuloDeAnuncio

  static Future<void> _quitar(String id) async { // Quita un círculo (si no existe, no pasa nada)
    try { await NativeGeofenceManager.instance.removeGeofenceById(id); } catch (_) {} // Quita
  } // Fin de _quitar

  static Future<void> olvidarAnuncios(Iterable<int> ids) async { // Quita los círculos de anuncios ya mostrados (lo llama el aviso de fondo)
    for (final id in ids) { await _quitar('$prefijoAnuncio$id'); } // Uno por uno
    await _almacen.delete(key: _claveAnuncios); // La próxima sincronización vuelve a revisar
  } // Fin de olvidarAnuncios

  static String _lugar(Iglesia iglesia) => '${iglesia.latitud},${iglesia.longitud},${iglesia.radioMetros}'; // Ej: "13.69,-89.21,200"

  static Future<void> _registrar(Iglesia iglesia) async { // Registra (o reemplaza) el círculo del templo en el teléfono
    final gestor = NativeGeofenceManager.instance; // Atajo
    await gestor.initialize(); // Prepara el paquete
    await _quitar(_idGeocerca); // Quita el anterior, si había
    await gestor.createGeofence( // Registra el círculo
      Geofence( // Datos del círculo
        id: _idGeocerca, // Nombre
        location: Location(latitude: iglesia.latitud!, longitude: iglesia.longitud!), // Centro: el templo
        radiusMeters: max(iglesia.radioMetros, 100).toDouble(), // Radio (mínimo 100 m)
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

// Elige qué anuncios avisar según el círculo y el evento (separado para poder probarlo en la PC).
// - Círculo de la iglesia (respaldo, al entrar): anuncios "al llegar" sin espera cuya área contenga al teléfono (o sea la de la iglesia).
// - Círculo de un anuncio: ese anuncio, si el evento es el suyo (entrar / quedarse / salir).
List<Anuncio> anunciosParaAvisar({ // Devuelve los anuncios que tocan
  required List<String> circulos, // Nombres de los círculos que avisó el teléfono
  required GeofenceEvent evento, // Qué pasó (entró, se quedó, salió)
  required List<Anuncio> pendientes, // Anuncios de área en su ventana y no mostrados
  required bool esIphone, // iPhone no tiene "quedarse"
  double? latitud, // Dónde estaba el teléfono (Android; puede faltar)
  double? longitud, // (idem)
}) {
  final elegidos = <int, Anuncio>{}; // Sin repetir (un anuncio puede venir por dos círculos)
  for (final circulo in circulos) { // Cada círculo
    if (circulo == 'iglesia') { // Círculo de la iglesia
      if (evento != GeofenceEvent.enter) continue; // Solo al entrar
      for (final a in pendientes) { // Anuncios "al llegar" sin espera
        if (a.alSalir || (a.minutos > 0 && !esIphone)) continue; // Esos los atiende su propio círculo
        final propia = a.zona != null && a.zona!.propia; // ¿Tiene un área distinta?
        if (propia) { // Área propia: solo si se sabe que el teléfono está dentro de ella
          if (latitud == null || longitud == null) continue; // Sin dato: lo deja a su propio círculo
          if (Geocerca.distanciaMetros(latitud, longitud, a.zona!.latitud, a.zona!.longitud) > a.zona!.radioMetros) continue; // Fuera de su área
        } // Fin del if
        elegidos[a.id] = a; // Toca
      } // Fin del for
    } else if (circulo.startsWith(GeocercaFondo.prefijoAnuncio)) { // Círculo de un anuncio
      final id = int.tryParse(circulo.substring(GeocercaFondo.prefijoAnuncio.length)); // Número del anuncio
      for (final a in pendientes.where((a) => a.id == id)) { // El anuncio (si sigue pendiente)
        if (GeocercaFondo.eventoDe(a, esIphone: esIphone) == evento) elegidos[a.id] = a; // Solo si es su evento
      } // Fin del for
    } // Fin del if
  } // Fin del for
  return elegidos.values.toList(); // Los que tocan
} // Fin de anunciosParaAvisar

// Se ejecuta cuando el teléfono ENTRA, SE QUEDA o SALE de un círculo, aunque la app esté cerrada.
// Debe ser una función "suelta" (fuera de una clase) con @pragma: así Android/iPhone la encuentran al despertar la app.
// (Conserva el nombre "geocercaEntro": los círculos ya registrados en los teléfonos apuntan a esta función.)
@pragma('vm:entry-point') // No borrar: sin esto, la versión final de la app la eliminaría por "no usada"
Future<void> geocercaEntro(GeofenceCallbackParams params) async { // Datos del aviso del teléfono
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
    final candidatos = anunciosParaAvisar( // ¿Cuáles tocan con este círculo y este evento?
      circulos: params.geofences.map((g) => g.id).toList(), // Círculos que avisó el teléfono
      evento: params.event, // Entró / se quedó / salió
      pendientes: await geocerca.pendientes(anuncios, DateTime.now()), // De área, en su ventana y no mostrados
      esIphone: Platform.isIOS, // iPhone no tiene "quedarse"
      latitud: params.location?.latitude, // Dónde estaba (Android)
      longitud: params.location?.longitude, // (idem)
    ); // Fin
    if (candidatos.isEmpty) return; // Nada que avisar
    final nuevos = await geocerca.reclamar(candidatos); // Los marca ANTES de avisar, releyendo la lista: si mientras se esperaba al panel la app abierta ya mostró la ventana, no se repite (cada anuncio sale UNA sola vez en total)
    if (nuevos.isEmpty) return; // Ya se mostraron por otro lado
    await GeocercaFondo.olvidarAnuncios(nuevos.map((a) => a.id)); // Ya no hace falta vigilarlos

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
        title: '${anuncio.alSalir ? '👋' : '📍'} ${anuncio.titulo}', // Título con pin (al llegar) o mano (al salir)
        body: anuncio.mensaje, // Texto del anuncio
        notificationDetails: const NotificationDetails( // Cómo se ve
          android: AndroidNotificationDetails( // Android
            'geocerca', // Canal
            'Avisos al llegar a la iglesia', // Nombre del canal (Ajustes → Notificaciones)
            channelDescription: 'Anuncios que se muestran al llegar o al salir de la iglesia', // Descripción del canal
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
