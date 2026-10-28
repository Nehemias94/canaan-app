import 'dart:convert'; // Para convertir el texto JSON en datos de Dart (jsonDecode)

import 'package:http/http.dart' as http; // Paquete para hacer peticiones a internet

import '../config.dart'; // Dirección de la API y tiempo máximo de espera
import '../modelos/actividad.dart'; // Molde de una actividad del horario
import '../modelos/iglesia.dart'; // Molde de los datos de la iglesia
import '../modelos/predica.dart'; // Molde de una prédica

class ErrorApi implements Exception { // Error de la API con su código (ej: 401 = token inválido)
  const ErrorApi(this.codigo); // Constructor: recibe el código que respondió el servidor

  final int codigo; // Código HTTP (401, 422, 429, 500…)

  @override // Reemplaza toString
  String toString() => 'El servidor respondió con el código $codigo'; // Texto del error (útil al revisar fallos)
} // Fin de ErrorApi

class Api { // Todas las llamadas a la API del panel se hacen desde aquí
  const Api(); // Constructor (const: no guarda nada, se puede reutilizar)

  Map<String, dynamic> _revisar(http.Response respuesta) { // Ayuda interna: revisa la respuesta y devuelve el JSON
    if (respuesta.statusCode < 200 || respuesta.statusCode > 299) { // Si no es un código de éxito (200–299)...
      throw ErrorApi(respuesta.statusCode); // ...lanza un error con el código
    } // Fin del if
    return jsonDecode(respuesta.body) as Map<String, dynamic>; // Convierte el texto en un mapa (clave → valor)
  } // Fin de _revisar

  Future<Map<String, dynamic>> _leer(String ruta, [Map<String, String>? parametros, String? token]) async { // Ayuda interna: hace un GET y devuelve el JSON
    final direccion = Uri.parse('$apiBase/$ruta').replace(queryParameters: parametros); // Arma la dirección, ej: .../api/predicas?buscar=fe
    final respuesta = await http // Hace la petición y espera la respuesta...
        .get(direccion, headers: { // ...GET con estas cabeceras:
          'Accept': 'application/json', // Pide JSON (también los errores)
          if (token != null) 'Authorization': 'Bearer $token', // La llave del teléfono, solo si la ruta la necesita
        }) // Fin de las cabeceras
        .timeout(tiempoMaximoEspera); // Si tarda demasiado, se corta con error
    return _revisar(respuesta); // Revisa y devuelve el JSON
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

  Future<int> verificarToken(String token) async { // Comprueba que el token sigue sirviendo (GET /api/dispositivos/yo); devuelve el número del teléfono
    final json = await _leer('dispositivos/yo', null, token); // Pide los datos del teléfono con su llave (401 si no sirve)
    return json['id'] as int; // Número del teléfono en el panel
  } // Fin de verificarToken

  Future<Iglesia> obtenerIglesia() async { // Datos de la iglesia (GET /api/iglesia)
    final json = await _leer('iglesia'); // Pide los datos
    return Iglesia.desdeJson(json['data'] as Map<String, dynamic>); // Vienen dentro de "data"
  } // Fin de obtenerIglesia

  Future<List<Predica>> obtenerPredicas({String buscar = ''}) async { // Prédicas (GET /api/predicas), la destacada primero
    final json = await _leer('predicas', { // Pide la lista...
      'por_pagina': '30', // ...hasta 30 (el máximo de la API)
      if (buscar.trim().isNotEmpty) 'buscar': buscar.trim(), // ...y el texto a buscar, solo si escribió algo
    }); // Fin de la petición
    return (json['data'] as List) // La lista viene dentro de "data"...
        .map((p) => Predica.desdeJson(p as Map<String, dynamic>)) // ...cada elemento se convierte en Predica...
        .toList(); // ...y se devuelve como lista
  } // Fin de obtenerPredicas

  Future<List<Actividad>> obtenerActividades() async { // Horario de cultos (GET /api/actividades), ya ordenado por día y hora
    final json = await _leer('actividades'); // Pide la lista
    return (json['data'] as List) // La lista viene dentro de "data"...
        .map((a) => Actividad.desdeJson(a as Map<String, dynamic>)) // ...cada elemento se convierte en Actividad...
        .toList(); // ...y se devuelve como lista
  } // Fin de obtenerActividades
} // Fin de Api
