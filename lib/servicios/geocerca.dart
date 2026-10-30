import 'dart:convert'; // jsonEncode / jsonDecode (guardar la lista de anuncios ya mostrados)
import 'dart:math'; // sin, cos, sqrt, atan2, pi (fórmula de distancia)

import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Caja fuerte del teléfono (recordar qué anuncios ya se mostraron)

import '../modelos/anuncio.dart'; // Molde de un anuncio
import '../modelos/iglesia.dart'; // Molde de la iglesia (ubicación y radio)
import 'ubicacion.dart'; // Ubicación del teléfono

// Geocerca (Paso 10): anuncios "Solo área" que se muestran UNA vez cuando la persona está en SU área durante la ventana del anuncio.
// Cada anuncio puede tener un área propia (si no, la de la iglesia) y avisar al llegar (enseguida o tras N minutos adentro) o al salir.
// La ubicación solo se pide si hay un anuncio de área en su ventana, y NUNCA sale del teléfono (la distancia se calcula aquí).
class Geocerca { // Revisa si el teléfono está en la iglesia
  Geocerca({ServicioUbicacion? ubicacion, FlutterSecureStorage? almacen}) // Constructor (en pruebas se pasan versiones de mentira)
      : _ubicacion = ubicacion ?? ServicioUbicacion.crear(), // Servicio de ubicación
        _almacen = almacen ?? const FlutterSecureStorage(); // Caja fuerte

  final ServicioUbicacion _ubicacion; // De dónde se saca la ubicación
  final FlutterSecureStorage _almacen; // Dónde se recuerdan los anuncios ya mostrados

  static const _clave = 'anuncios_area_mostrados'; // Nombre con el que se guarda la lista
  static const _claveCopia = 'anuncios_area_copia'; // Copia de los anuncios "Solo área" (la usa el aviso con la app cerrada)
  static const vigenciaCopia = Duration(hours: 12); // Si la copia tiene más de 12 h, el aviso de fondo intenta pedir los anuncios al panel
  static const _claveDentro = 'anuncios_area_dentro'; // Desde cuándo el teléfono está dentro del área de cada anuncio (para "si se queda N minutos")
  static const _claveEstuvo = 'anuncios_area_estuvo'; // Anuncios "al salir" cuya área ya visitó el teléfono (para avisar cuando se vaya)

  static ZonaAnuncio? zonaDe(Anuncio anuncio, Iglesia? iglesia) { // Área donde avisa un anuncio: la suya o, si no trae, la de la iglesia
    if (anuncio.zona != null) return anuncio.zona; // La que mandó el panel
    if (iglesia == null || !iglesia.tieneUbicacion) return null; // Sin área
    return ZonaAnuncio(latitud: iglesia.latitud!, longitud: iglesia.longitud!, radioMetros: iglesia.radioMetros); // La de la iglesia
  } // Fin de zonaDe

  Future<Map<String, dynamic>> _leerMapa(String clave) async { // Lee un dato guardado como mapa (vacío si no hay)
    try { final t = await _almacen.read(key: clave); return t == null ? {} : jsonDecode(t) as Map<String, dynamic>; } catch (_) { return {}; } // Dañado → vacío
  } // Fin de _leerMapa

  Future<Set<int>> mostrados() async { // Lista de anuncios ya mostrados en este teléfono (se lee siempre de la caja fuerte: la geocerca de fondo también la cambia)
    try { // Intenta leerla
      final texto = await _almacen.read(key: _clave); // Texto guardado, ej: "[3,7]"
      return texto == null ? <int>{} : (jsonDecode(texto) as List).cast<int>().toSet(); // Convierte a conjunto de números
    } catch (_) { // Si estaba dañada...
      return <int>{}; // ...empieza vacía
    } // Fin del try
  } // Fin de mostrados

  Future<void> guardarCopia(List<Anuncio> anuncios) async { // Guarda en el teléfono los anuncios "Solo área" que mandó el panel (se llama en cada carga de Inicio)
    final area = anuncios.where((a) => a.tipo == 'area').map((a) => a.aJson()).toList(); // Solo los de área, como datos
    await _almacen.write( // Guarda...
      key: _claveCopia, // ...con este nombre...
      value: jsonEncode({'guardada': DateTime.now().toUtc().toIso8601String(), 'anuncios': area}), // ...la hora de la copia y la lista
    ); // Fin de guardar
  } // Fin de guardarCopia

  Future<({DateTime guardada, List<Anuncio> anuncios})?> leerCopia() async { // Lee la copia (null si no hay o está dañada)
    try { // Intenta
      final texto = await _almacen.read(key: _claveCopia); // Texto guardado
      if (texto == null) return null; // Nunca se guardó
      final datos = jsonDecode(texto) as Map<String, dynamic>; // Convierte el texto en datos
      return ( // Devuelve dos cosas juntas:
        guardada: DateTime.parse(datos['guardada'] as String).toLocal(), // cuándo se guardó...
        anuncios: (datos['anuncios'] as List).map((a) => Anuncio.desdeJson(a as Map<String, dynamic>)).toList(), // ...y los anuncios
      ); // Fin
    } catch (_) { // Dañada
      return null; // Como si no hubiera
    } // Fin del try
  } // Fin de leerCopia

  Future<List<Anuncio>> pendientes(List<Anuncio> anuncios, DateTime ahora) async { // Anuncios de área en su ventana que este teléfono aún no ha mostrado
    final vistos = await mostrados(); // Ya mostrados
    return anuncios.where((a) => a.enVentana(ahora) && !vistos.contains(a.id)).toList(); // De área, en su ventana y no mostrados
  } // Fin de pendientes

  Future<void> marcarMostrados(List<Anuncio> anuncios) async { // Anota estos anuncios como mostrados (así no se repiten)
    final vistos = await mostrados(); // Lista actual
    vistos.addAll(anuncios.map((a) => a.id)); // Agrega los nuevos
    await _almacen.write(key: _clave, value: jsonEncode(vistos.toList())); // La guarda
  } // Fin de marcarMostrados

  Future<bool> estaDentro(ZonaAnuncio zona) async { // ¿El teléfono está dentro de este círculo? (false si no se sabe: sin permiso o sin señal)
    final aqui = await _ubicacion.posicionActual(); // Dónde está (puede pedir permiso la primera vez)
    if (aqui == null) return false; // No se sabe
    return distanciaMetros(aqui.latitud, aqui.longitud, zona.latitud, zona.longitud) <= zona.radioMetros; // Dentro del radio
  } // Fin de estaDentro

  Future<List<Anuncio>> revisar(Iglesia iglesia, List<Anuncio> anuncios, DateTime ahora) async { // Devuelve los anuncios de área NUEVOS que hay que mostrar ahora (se llama con la app abierta, cada 90 s y al volver)
    final candidatos = (await pendientes(anuncios, ahora)).where((a) => zonaDe(a, iglesia) != null).toList(); // De área, en su ventana, no mostrados y con un área conocida
    if (candidatos.isEmpty) return []; // Nada pendiente: NI SIQUIERA pide la ubicación
    final aqui = await _ubicacion.posicionActual(); // Dónde está el teléfono (puede pedir permiso la primera vez)
    if (aqui == null) return []; // No se sabe (sin permiso o sin señal)
    final dentro = await _leerMapa(_claveDentro); // id → desde cuándo está adentro
    final estuvo = (await _leerMapa(_claveEstuvo)).keys.toSet(); // ids "al salir" cuya área ya visitó
    final ids = candidatos.map((a) => '${a.id}').toSet(); // Para olvidar anuncios que ya no aplican
    dentro.removeWhere((id, _) => !ids.contains(id)); // Limpia lo viejo
    estuvo.removeWhere((id) => !ids.contains(id)); // Limpia lo viejo
    final mostrar = <Anuncio>[]; // Los que tocan ahora
    for (final a in candidatos) { // Revisa cada anuncio con SU área
      final zona = zonaDe(a, iglesia)!; // Su área
      final adentro = distanciaMetros(aqui.latitud, aqui.longitud, zona.latitud, zona.longitud) <= zona.radioMetros; // ¿Está dentro del círculo?
      final id = '${a.id}'; // Clave
      if (a.alSalir) { // "Al salir": hay que haber estado adentro y luego estar afuera
        if (adentro) { estuvo.add(id); } else if (estuvo.contains(id)) { mostrar.add(a); } // Adentro: lo anota; afuera después de estar: avisa
        continue; // Siguiente
      } // Fin de "al salir"
      if (!adentro) { dentro.remove(id); continue; } // "Al llegar" y está afuera: reinicia la espera
      if (a.minutos <= 0) { mostrar.add(a); continue; } // Enseguida
      final desde = DateTime.tryParse(dentro[id] as String? ?? ''); // ¿Desde cuándo está adentro?
      if (desde == null) { dentro[id] = ahora.toIso8601String(); continue; } // Recién llegó: empieza a contar
      if (ahora.difference(desde) >= Duration(minutes: a.minutos)) mostrar.add(a); // Ya se quedó lo suficiente: avisa
    } // Fin del for
    await _almacen.write(key: _claveDentro, value: jsonEncode(dentro)); // Guarda las esperas
    await _almacen.write(key: _claveEstuvo, value: jsonEncode({for (final id in estuvo) id: true})); // Guarda las visitas
    if (mostrar.isNotEmpty) await marcarMostrados(mostrar); // Los marca: no se repiten (tampoco como notificación)
    return mostrar; // Los que hay que mostrar
  } // Fin de revisar

  static double distanciaMetros(double lat1, double lon1, double lat2, double lon2) { // Distancia entre dos puntos de la Tierra (fórmula de "haversine")
    const radioTierra = 6371000.0; // Radio de la Tierra en metros
    double rad(double grados) => grados * pi / 180; // Grados → radianes
    final dLat = rad(lat2 - lat1); // Diferencia de latitud
    final dLon = rad(lon2 - lon1); // Diferencia de longitud
    final a = sin(dLat / 2) * sin(dLat / 2) + cos(rad(lat1)) * cos(rad(lat2)) * sin(dLon / 2) * sin(dLon / 2); // Parte de la fórmula
    return radioTierra * 2 * atan2(sqrt(a), sqrt(1 - a)); // Distancia en metros
  } // Fin de distanciaMetros
} // Fin de Geocerca
