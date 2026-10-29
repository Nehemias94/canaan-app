import 'dart:convert'; // jsonEncode / jsonDecode (guardar la lista de anuncios ya mostrados)
import 'dart:math'; // sin, cos, sqrt, atan2, pi (fórmula de distancia)

import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Caja fuerte del teléfono (recordar qué anuncios ya se mostraron)

import '../modelos/anuncio.dart'; // Molde de un anuncio
import '../modelos/iglesia.dart'; // Molde de la iglesia (ubicación y radio)
import 'ubicacion.dart'; // Ubicación del teléfono

// Geocerca (Paso 10): anuncios "Solo área" que se muestran UNA vez cuando la persona está en la iglesia durante la ventana del anuncio.
// La ubicación solo se pide si hay un anuncio de área en su ventana, y NUNCA sale del teléfono (la distancia se calcula aquí).
class Geocerca { // Revisa si el teléfono está en la iglesia
  Geocerca({ServicioUbicacion? ubicacion, FlutterSecureStorage? almacen}) // Constructor (en pruebas se pasan versiones de mentira)
      : _ubicacion = ubicacion ?? ServicioUbicacion.crear(), // Servicio de ubicación
        _almacen = almacen ?? const FlutterSecureStorage(); // Caja fuerte

  final ServicioUbicacion _ubicacion; // De dónde se saca la ubicación
  final FlutterSecureStorage _almacen; // Dónde se recuerdan los anuncios ya mostrados

  static const _clave = 'anuncios_area_mostrados'; // Nombre con el que se guarda la lista

  Future<Set<int>> mostrados() async { // Lista de anuncios ya mostrados en este teléfono (se lee siempre de la caja fuerte: la geocerca de fondo también la cambia)
    try { // Intenta leerla
      final texto = await _almacen.read(key: _clave); // Texto guardado, ej: "[3,7]"
      return texto == null ? <int>{} : (jsonDecode(texto) as List).cast<int>().toSet(); // Convierte a conjunto de números
    } catch (_) { // Si estaba dañada...
      return <int>{}; // ...empieza vacía
    } // Fin del try
  } // Fin de mostrados

  Future<List<Anuncio>> pendientes(List<Anuncio> anuncios, DateTime ahora) async { // Anuncios de área en su ventana que este teléfono aún no ha mostrado
    final vistos = await mostrados(); // Ya mostrados
    return anuncios.where((a) => a.enVentana(ahora) && !vistos.contains(a.id)).toList(); // De área, en su ventana y no mostrados
  } // Fin de pendientes

  Future<void> marcarMostrados(List<Anuncio> anuncios) async { // Anota estos anuncios como mostrados (así no se repiten)
    final vistos = await mostrados(); // Lista actual
    vistos.addAll(anuncios.map((a) => a.id)); // Agrega los nuevos
    await _almacen.write(key: _clave, value: jsonEncode(vistos.toList())); // La guarda
  } // Fin de marcarMostrados

  Future<List<Anuncio>> revisar(Iglesia iglesia, List<Anuncio> anuncios, DateTime ahora) async { // Devuelve los anuncios de área NUEVOS que hay que mostrar ahora (vacío si no está en la iglesia)
    if (!iglesia.tieneUbicacion) return []; // El panel no tiene la ubicación del templo: no hay geocerca
    final candidatos = await pendientes(anuncios, ahora); // De área, en su ventana y aún no mostrados
    if (candidatos.isEmpty) return []; // Nada pendiente: NI SIQUIERA pide la ubicación
    final aqui = await _ubicacion.posicionActual(); // Dónde está el teléfono (puede pedir permiso la primera vez)
    if (aqui == null) return []; // No se sabe (sin permiso o sin señal)
    final metros = distanciaMetros(aqui.latitud, aqui.longitud, iglesia.latitud!, iglesia.longitud!); // Distancia al templo
    if (metros > iglesia.radioMetros) return []; // Lejos: nada
    await marcarMostrados(candidatos); // Está en la iglesia: los marca como mostrados
    return candidatos; // Los que hay que mostrar
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
