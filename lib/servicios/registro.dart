import 'package:flutter/foundation.dart'; // kIsWeb y defaultTargetPlatform (saber si es navegador, Android o iPhone)
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Caja fuerte del teléfono para guardar datos privados
import 'package:uuid/uuid.dart'; // Genera códigos únicos (UUID)

import 'api.dart'; // Llamadas a la API (registrar y verificar)

// Registro del teléfono en el panel: la primera vez crea un código único (UUID), se registra y guarda la "llave" (token).
// En las siguientes aperturas solo comprueba que la llave siga sirviendo; si no (401), se registra de nuevo con el MISMO código.
class RegistroDispositivo { // Se encarga de que el teléfono esté siempre registrado
  RegistroDispositivo({required this.api, FlutterSecureStorage? almacen}) // Constructor: recibe la API y (opcional) la caja fuerte
      : _almacen = almacen ?? const FlutterSecureStorage(); // Si no se pasa una caja fuerte, usa la del teléfono

  final Api api; // De dónde se registra
  final FlutterSecureStorage _almacen; // Caja fuerte (Android: Keystore; iPhone: Keychain; navegador: almacenamiento cifrado)

  static const _claveUuid = 'dispositivo_uuid'; // Nombre con el que se guarda el código del teléfono
  static const _claveToken = 'dispositivo_token'; // Nombre con el que se guarda la llave

  int? numero; // Número del teléfono en el panel (null hasta que se confirme el registro)

  Future<void>? _proceso; // Registro en curso o terminado (para no repetirlo si varias pantallas lo piden)

  Future<void> iniciar() => _proceso ??= asegurar(); // Arranca el registro UNA sola vez y devuelve siempre el mismo proceso ("??=": solo si aún no hay)

  Future<void> reintentar() => _proceso = asegurar(); // Vuelve a intentarlo (ej: falló porque no había internet)

  static String plataformaActual() { // Qué plataforma enviar al panel
    if (kIsWeb) return 'web'; // Abierta en un navegador (pruebas en Chrome)
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios'; // iPhone
    return 'android'; // Android (y cualquier otro caso)
  } // Fin de plataformaActual

  Future<String?> token() => _almacen.read(key: _claveToken); // Lee la llave guardada (null si todavía no hay)

  Future<String> _uuid() async { // Devuelve el código del teléfono; lo crea la primera vez
    final guardado = await _almacen.read(key: _claveUuid); // Busca el código guardado
    if (guardado != null) return guardado; // Si ya existe, lo usa (así el panel reconoce al mismo teléfono)
    final nuevo = const Uuid().v4(); // Si no, crea uno nuevo al azar, ej: "3f2a…-…"
    await _almacen.write(key: _claveUuid, value: nuevo); // Lo guarda para siempre
    return nuevo; // Lo devuelve
  } // Fin de _uuid

  Future<void> _registrar() async { // Se registra en el panel y guarda la llave nueva
    final nuevoToken = await api.registrarDispositivo(uuid: await _uuid(), plataforma: plataformaActual()); // Pide la llave al panel
    await _almacen.write(key: _claveToken, value: nuevoToken); // La guarda en la caja fuerte
    numero = await api.verificarToken(nuevoToken); // Confirma que funciona y anota el número del teléfono
  } // Fin de _registrar

  Future<void> asegurar() async { // Lo que se llama al abrir la app: deja el teléfono registrado
    final guardado = await token(); // ¿Ya hay llave guardada?
    if (guardado == null) return _registrar(); // No: primera vez → registrarse
    try { // Sí: comprobar que sigue sirviendo
      numero = await api.verificarToken(guardado); // Si responde bien, listo
    } on ErrorApi catch (error) { // Si el panel respondió con error...
      if (error.codigo == 401 || error.codigo == 403) return _registrar(); // ...llave inválida: registrarse de nuevo (mismo código)
      rethrow; // Otro error (ej: servidor caído): se avisa a quien llamó
    } // Fin del try
  } // Fin de asegurar
} // Fin de RegistroDispositivo
