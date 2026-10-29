import 'api.dart'; // Llamadas a la API
import 'registro.dart'; // Llave del teléfono

// La API y el registro del teléfono, al alcance de cualquier pantalla (tarjetas y detalle de eventos, por ejemplo)
// sin tener que pasarlos de pantalla en pantalla. Los pone la pantalla principal al abrir la app (en las pruebas, la API falsa).
class ServiciosApp { // Todo junto
  static Api api = const Api(); // API (en la app: la real; en las pruebas: la falsa)
  static RegistroDispositivo? registro; // Registro del teléfono (null hasta que abre la pantalla principal)

  static Future<T> conLlave<T>(Future<T> Function(String token) accion) { // Llama a la API con la llave del teléfono
    final r = registro; // Atajo
    if (r == null) return Future.error(StateError('Sin registro')); // Todavía no abrió la pantalla principal
    return r.conLlave(accion); // Si la llave venció, se registra de nuevo y repite una vez
  } // Fin de conLlave
} // Fin de ServiciosApp
