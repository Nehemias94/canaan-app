import 'dart:convert'; // Para convertir el texto JSON en datos de Dart (jsonDecode)

import 'package:http/http.dart' as http; // Paquete para hacer peticiones a internet

import '../config.dart'; // Dirección de la API y tiempo máximo de espera
import 'conexion.dart'; // Copia local (funcionar sin internet)
import '../modelos/actividad.dart'; // Molde de una actividad del horario
import '../modelos/evento.dart'; // Molde de un evento especial
import '../modelos/anuncio.dart'; // Molde de un anuncio
import '../modelos/iglesia.dart'; // Molde de los datos de la iglesia
import '../modelos/predica.dart'; // Molde de una prédica

class ErrorApi implements Exception { // Error de la API con su código (ej: 401 = token inválido)
  const ErrorApi(this.codigo, [this.mensaje]); // Constructor: código y, si el panel lo envió, su mensaje (los [] lo hacen opcional)

  final int codigo; // Código HTTP (401, 422, 429, 500…)
  final String? mensaje; // Mensaje en español del panel (ej: "Ya enviaste 3 peticiones hoy…"), si vino

  @override // Reemplaza toString
  String toString() => mensaje ?? 'El servidor respondió con el código $codigo'; // Texto del error
} // Fin de ErrorApi

class RespuestaPeticion { // Lo que responde el panel al recibir una petición de oración
  const RespuestaPeticion({required this.mensaje, required this.restantesHoy}); // Constructor

  final String mensaje; // Ej: "Recibimos tu petición. Estaremos orando por ti."
  final int restantesHoy; // Cuántas más puede enviar hoy (máximo 3 por día)
} // Fin de RespuestaPeticion

class SenalEnVivo { // Respuesta del panel a cada señal del en vivo
  const SenalEnVivo({required this.enVivo, required this.viendoAhora, required this.siguienteSegundos}); // Constructor

  final bool enVivo; // false = la transmisión terminó
  final int viendoAhora; // Personas viendo en este momento
  final int siguienteSegundos; // Segundos para la próxima señal (normalmente 30)
} // Fin de SenalEnVivo

class Api { // Todas las llamadas a la API del panel se hacen desde aquí
  const Api(); // Constructor (const: no guarda nada, se puede reutilizar)

  Map<String, dynamic> _revisar(http.Response respuesta) { // Ayuda interna: revisa la respuesta y devuelve el JSON
    if (respuesta.statusCode < 200 || respuesta.statusCode > 299) { // Si no es un código de éxito (200–299)...
      String? mensaje; // Mensaje del panel (si lo hay)
      try { // Intenta leerlo (si la respuesta no es JSON, se ignora)
        mensaje = (jsonDecode(respuesta.body) as Map<String, dynamic>)['mensaje'] as String?; // El panel usa la clave "mensaje" para sus textos en español
      } catch (_) {} // No era JSON: sin mensaje
      throw ErrorApi(respuesta.statusCode, mensaje); // ...lanza un error con el código y el mensaje
    } // Fin del if
    return jsonDecode(respuesta.body) as Map<String, dynamic>; // Convierte el texto en un mapa (clave → valor)
  } // Fin de _revisar

  Future<Map<String, dynamic>> _leer(String ruta, [Map<String, String>? parametros, String? token, bool guardarCopia = false]) async { // Ayuda interna: hace un GET y devuelve el JSON. guardarCopia = sirve sin internet (usa la última respuesta guardada)
    final direccion = Uri.parse('$apiBase/$ruta').replace(queryParameters: parametros); // Arma la dirección, ej: .../api/predicas?buscar=fe
    final copia = guardarCopia ? await CopiaLocal.leer(ruta) : null; // Copia guardada (si la hay)
    try { // Intenta pedirlo al panel
      final respuesta = await http // Hace la petición y espera la respuesta...
          .get(direccion, headers: { // ...GET con estas cabeceras:
            'Accept': 'application/json', // Pide JSON (también los errores)
            if (token != null) 'Authorization': 'Bearer $token', // La llave del teléfono, solo si la ruta la necesita
          }) // Fin de las cabeceras
          .timeout(copia != null ? esperaConCopia : tiempoMaximoEspera); // Si tarda demasiado, se corta (con copia guardada, no se espera tanto)
      final json = _revisar(respuesta); // Revisa y convierte
      if (guardarCopia) { // Ruta que sirve sin internet...
        await CopiaLocal.guardar(ruta, json); // ...guarda la copia nueva
        sinConexion.value = false; // ...y ya hay conexión
      } // Fin del if
      return json; // Datos del panel
    } catch (error) { // Sin internet, muy lento o el servidor falló
      final esDeRed = error is! ErrorApi || error.codigo >= 500; // ¿Problema de conexión o del servidor? (un 401/404/422 es una respuesta real: no se reemplaza)
      if (copia != null && esDeRed) { // Hay copia: la usa
        sinConexion.value = true; // Avisa (franja "Sin conexión")
        return copia; // Lo último guardado
      } // Fin del if
      rethrow; // Sin copia: el error sigue (la pantalla muestra "Reintentar")
    } // Fin del try
  } // Fin de _leer

  Future<String> registrarDispositivo({required String uuid, required String plataforma}) async { // Registra el teléfono y devuelve su token (POST /api/dispositivos/registrar)
    final respuesta = await http // Hace la petición...
        .post( // ...de tipo POST (enviar datos)
          Uri.parse('$apiBase/dispositivos/registrar'), // Dirección
          headers: {'Accept': 'application/json', 'Content-Type': 'application/json'}, // Envía y recibe JSON
          body: jsonEncode({'uuid': uuid, 'plataforma': plataforma, 'version_app': versionApp}), // Datos del teléfono convertidos a texto JSON
        ) // Fin del post
        .timeout(tiempoMaximoEspera); // Tiempo máximo
    return _revisar(respuesta)['token'] as String; // Devuelve solo el token
  } // Fin de registrarDispositivo

  Future<RespuestaPeticion> enviarPeticion({required String token, required String nombre, required String peticion}) async { // Envía una petición de oración (POST /api/peticiones, anónima)
    final respuesta = await http // Hace la petición...
        .post( // ...de tipo POST
          Uri.parse('$apiBase/peticiones'), // Dirección
          headers: { // Cabeceras
            'Accept': 'application/json', // Recibe JSON
            'Content-Type': 'application/json', // Envía JSON
            'Authorization': 'Bearer $token', // Llave del teléfono (el panel solo la usa para el límite de 3 por día; no la guarda con la petición)
          }, // Fin de las cabeceras
          body: jsonEncode({ // Datos convertidos a texto JSON
            if (nombre.trim().isNotEmpty) 'nombre': nombre.trim(), // Nombre solo si escribió uno (si no, llega como "Anónimo")
            'peticion': peticion.trim(), // Texto de la petición, sin espacios sobrantes
          }), // Fin de los datos
        ) // Fin del post
        .timeout(tiempoMaximoEspera); // Tiempo máximo
    final json = _revisar(respuesta); // Revisa (429 = ya envió 3 hoy, con su mensaje) y lee el JSON
    return RespuestaPeticion( // Devuelve lo importante
      mensaje: json['mensaje'] as String? ?? 'Recibimos tu petición.', // Mensaje del panel
      restantesHoy: json['restantes_hoy'] as int? ?? 0, // Cuántas le quedan hoy
    ); // Fin de la respuesta
  } // Fin de enviarPeticion

  Future<Map<String, dynamic>> _enviarConToken(String ruta, String token) async { // Ayuda interna: POST sin cuerpo con la llave del teléfono
    final respuesta = await http // Hace la petición...
        .post( // ...de tipo POST
          Uri.parse('$apiBase/$ruta'), // Dirección
          headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'}, // Pide JSON y manda la llave
        ) // Fin del post
        .timeout(tiempoMaximoEspera); // Tiempo máximo
    return _revisar(respuesta); // Revisa y devuelve el JSON
  } // Fin de _enviarConToken

  Future<bool> registrarReproduccion({required String token, required int predicaId}) async { // Cuenta una vista de la prédica (POST /api/predicas/{id}/reproduccion)
    final json = await _enviarConToken('predicas/$predicaId/reproduccion', token); // Avisa al panel
    return json['contada'] == true; // true = se sumó; false = ese teléfono ya la vio en las últimas 6 horas (no es error)
  } // Fin de registrarReproduccion

  Future<SenalEnVivo> senalEnVivo(String token) async { // "Sigo viendo" el en vivo (POST /api/en-vivo/senal), cada 30 s
    final json = await _enviarConToken('en-vivo/senal', token); // Envía la señal
    return SenalEnVivo( // Devuelve lo que respondió el panel
      enVivo: json['en_vivo'] == true, // ¿Sigue la transmisión?
      viendoAhora: json['viendo_ahora'] as int? ?? 0, // Personas viendo ahora
      siguienteSegundos: json['siguiente_senal_segundos'] as int? ?? 30, // Cuándo mandar la siguiente señal
    ); // Fin de la respuesta
  } // Fin de senalEnVivo

  Future<void> salirEnVivo(String token) async { // "Dejé de ver" el en vivo (POST /api/en-vivo/salir): baja el contador al instante
    await _enviarConToken('en-vivo/salir', token); // Avisa al panel
  } // Fin de salirEnVivo

  Future<void> guardarFcmToken({required String token, required String? fcmToken}) async { // Envía al panel la dirección de notificaciones (POST /api/dispositivos/notificaciones)
    final respuesta = await http // Hace la petición...
        .post( // ...de tipo POST
          Uri.parse('$apiBase/dispositivos/notificaciones'), // Dirección
          headers: {'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, // JSON + llave del teléfono
          body: jsonEncode({'fcm_token': fcmToken}), // La dirección de Firebase (null = sin notificaciones)
        ) // Fin del post
        .timeout(tiempoMaximoEspera); // Tiempo máximo
    _revisar(respuesta); // Revisa (lanza ErrorApi si falló)
  } // Fin de guardarFcmToken

  Future<int> verificarToken(String token) async { // Comprueba que el token sigue sirviendo (GET /api/dispositivos/yo); devuelve el número del teléfono
    final json = await _leer('dispositivos/yo', null, token); // Pide los datos del teléfono con su llave (401 si no sirve)
    return json['id'] as int; // Número del teléfono en el panel
  } // Fin de verificarToken

  Future<Iglesia> obtenerIglesia() async { // Datos de la iglesia (GET /api/iglesia)
    final json = await _leer('iglesia', null, null, true); // Pide los datos (con copia: sirve sin internet)
    return Iglesia.desdeJson(json['data'] as Map<String, dynamic>); // Vienen dentro de "data"
  } // Fin de obtenerIglesia

  Future<List<Predica>> obtenerPredicas({String buscar = ''}) async { // Prédicas (GET /api/predicas), la destacada primero
    final json = await _leer('predicas', { // Pide la lista...
      'por_pagina': '30', // ...hasta 30 (el máximo de la API)
      if (buscar.trim().isNotEmpty) 'buscar': buscar.trim(), // ...y el texto a buscar, solo si escribió algo
    }, null, buscar.trim().isEmpty); // Fin de la petición (la lista completa se guarda para verla sin internet; las búsquedas no)
    return (json['data'] as List) // La lista viene dentro de "data"...
        .map((p) => Predica.desdeJson(p as Map<String, dynamic>)) // ...cada elemento se convierte en Predica...
        .toList(); // ...y se devuelve como lista
  } // Fin de obtenerPredicas

  Future<List<Anuncio>> obtenerAnuncios() async { // Anuncios visibles (GET /api/anuncios), los más recientes primero
    final json = await _leer('anuncios', null, null, true); // Pide la lista (con copia: sirve sin internet)
    return (json['data'] as List) // La lista viene dentro de "data"...
        .map((a) => Anuncio.desdeJson(a as Map<String, dynamic>)) // ...cada elemento se convierte en Anuncio...
        .toList(); // ...y se devuelve como lista
  } // Fin de obtenerAnuncios

  Future<List<Actividad>> obtenerActividades() async { // Horario de cultos (GET /api/actividades), ya ordenado por día y hora
    final json = await _leer('actividades', null, null, true); // Pide la lista (con copia: sirve sin internet)
    return (json['data'] as List) // La lista viene dentro de "data"...
        .map((a) => Actividad.desdeJson(a as Map<String, dynamic>)) // ...cada elemento se convierte en Actividad...
        .toList(); // ...y se devuelve como lista
  } // Fin de obtenerActividades

  Future<List<Evento>> obtenerEventos() async { // Eventos especiales que aún no terminan (GET /api/eventos), del más cercano al más lejano
    final json = await _leer('eventos', null, null, true); // Pide la lista (con copia: sirve sin internet)
    return (json['data'] as List) // La lista viene dentro de "data"...
        .map((e) => Evento.desdeJson(e as Map<String, dynamic>)) // ...cada elemento se convierte en Evento...
        .toList(); // ...y se devuelve como lista
  } // Fin de obtenerEventos
} // Fin de Api
