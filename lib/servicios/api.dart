import 'dart:convert'; // Para convertir el texto JSON en datos de Dart (jsonDecode)

import 'package:http/http.dart' as http; // Paquete para hacer peticiones a internet

import '../config.dart'; // Dirección de la API y tiempo máximo de espera
import '../modelos/actividad.dart'; // Molde de una actividad del horario
import '../modelos/iglesia.dart'; // Molde de los datos de la iglesia
import '../modelos/predica.dart'; // Molde de una prédica

class Api { // Todas las llamadas a la API del panel se hacen desde aquí
  const Api(); // Constructor (const: no guarda nada, se puede reutilizar)

  Future<Map<String, dynamic>> _leer(String ruta, [Map<String, String>? parametros]) async { // Ayuda interna: hace un GET y devuelve el JSON
    final direccion = Uri.parse('$apiBase/$ruta').replace(queryParameters: parametros); // Arma la dirección, ej: .../api/predicas?buscar=fe
    final respuesta = await http // Hace la petición y espera la respuesta...
        .get(direccion, headers: {'Accept': 'application/json'}) // ...GET pidiendo JSON (también los errores)
        .timeout(tiempoMaximoEspera); // Si tarda demasiado, se corta con error
    if (respuesta.statusCode != 200) { // Si el servidor no respondió "todo bien"...
      throw Exception('El servidor respondió con el código ${respuesta.statusCode}'); // ...lanza un error
    } // Fin del if
    return jsonDecode(respuesta.body) as Map<String, dynamic>; // Convierte el texto en un mapa (clave → valor)
  } // Fin de _leer

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
