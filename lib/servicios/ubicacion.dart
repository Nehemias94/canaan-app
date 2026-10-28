import 'package:geolocator/geolocator.dart'; // Ubicación del teléfono (GPS / red; en el navegador, la del navegador)

class Coordenadas { // Un punto en el mapa
  const Coordenadas(this.latitud, this.longitud); // Constructor

  final double latitud; // Norte/sur
  final double longitud; // Este/oeste
} // Fin de Coordenadas

// Plantilla: QUÉ debe saber hacer el servicio de ubicación (en las pruebas se usa uno de mentira).
abstract class ServicioUbicacion { // "abstract" = plantilla
  static ServicioUbicacion Function() crear = UbicacionReal.new; // Cómo crearlo (la app usa el real)

  Future<Coordenadas?> posicionActual(); // Dónde está el teléfono ahora (null = no se pudo o no dio permiso)
} // Fin de ServicioUbicacion

class UbicacionReal implements ServicioUbicacion { // Versión real con el paquete geolocator
  @override // Cumple la plantilla
  Future<Coordenadas?> posicionActual() async { // Pide la ubicación (y el permiso, la primera vez)
    try { // Cualquier falla = "no se sabe"
      if (!await Geolocator.isLocationServiceEnabled()) return null; // Ubicación apagada en el teléfono: no insiste
      var permiso = await Geolocator.checkPermission(); // ¿Ya dio permiso?
      if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission(); // Si no ha decidido, pregunta (ventana del sistema)
      if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) return null; // Dijo que no: respeta y no vuelve a molestar
      final posicion = await Geolocator.getCurrentPosition( // Ubicación actual...
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 20)), // ...precisión media (suficiente para ~100 m, gasta menos batería), máximo 20 s
      ); // Fin de la ubicación
      return Coordenadas(posicion.latitude, posicion.longitude); // La devuelve
    } catch (_) { // Tardó demasiado, sin señal, etc.
      return null; // No se sabe
    } // Fin del try
  } // Fin de posicionActual
} // Fin de UbicacionReal
