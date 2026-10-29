import 'dart:convert'; // jsonEncode / jsonDecode (guardar las respuestas como texto)

import 'package:flutter/foundation.dart'; // ValueNotifier
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Almacén del teléfono (donde se guardan las copias)

// Copia de lo último que llegó del panel, para que la app funcione SIN INTERNET (por ejemplo, dentro del templo si falla la señal).
// La API guarda cada respuesta buena; si después no hay conexión, entrega la copia y enciende "sinConexion" (la franja de abajo lo avisa).
final ValueNotifier<bool> sinConexion = ValueNotifier<bool>(false); // true = lo que se ve viene de la copia guardada (no hay conexión)

class CopiaLocal { // Guardar y leer las copias
  static const _almacen = FlutterSecureStorage(); // Almacén del teléfono
  static final Map<String, Map<String, dynamic>> _memoria = {}; // Copias ya leídas (más rápido que leer el almacén cada vez)

  static String _clave(String ruta) => 'copia_api_$ruta'; // Nombre en el almacén, ej: "copia_api_eventos"

  static Future<void> guardar(String ruta, Map<String, dynamic> json) async { // Guarda la respuesta de una ruta
    _memoria[ruta] = json; // En memoria
    try { await _almacen.write(key: _clave(ruta), value: jsonEncode(json)); } catch (_) {} // En el teléfono (si falla, solo queda en memoria)
  } // Fin de guardar

  static Future<Map<String, dynamic>?> leer(String ruta) async { // La copia de una ruta (null si nunca se guardó)
    if (_memoria.containsKey(ruta)) return _memoria[ruta]; // Ya estaba en memoria
    try { // Del teléfono
      final texto = await _almacen.read(key: _clave(ruta)); // Texto guardado
      if (texto == null) return null; // Nunca se guardó
      return _memoria[ruta] = jsonDecode(texto) as Map<String, dynamic>; // A datos (y a memoria)
    } catch (_) { // Almacén con problemas o texto dañado
      return null; // Sin copia
    } // Fin del try
  } // Fin de leer

  static void olvidarMemoria() => _memoria.clear(); // Solo para pruebas: obliga a leer del almacén
} // Fin de CopiaLocal
