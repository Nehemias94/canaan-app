import 'dart:convert'; // jsonEncode / jsonDecode (lista de recordatorios)

import 'package:flutter/foundation.dart'; // ValueNotifier
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Caja fuerte del teléfono (donde se guardan las preferencias)

// Preferencias que la persona elige en la app (pestaña Servicios / Horario). Se guardan en el teléfono y se recuerdan.
// Son "ValueNotifier": cuando cambian, las pantallas que las escuchan se redibujan solas.
class Preferencias { // Todo junto en un solo lugar
  static const _almacen = FlutterSecureStorage(); // Caja fuerte

  static final ValueNotifier<bool> letraGrande = ValueNotifier<bool>(false); // ¿Agrandar toda la letra de la app?
  static final ValueNotifier<String> apariencia = ValueNotifier<String>('sistema'); // 'sistema' (como el teléfono), 'claro' u 'oscuro'
  static final ValueNotifier<bool> avisosEnVivo = ValueNotifier<bool>(true); // ¿Recibir "¡Estamos en vivo!"?
  static final ValueNotifier<bool> avisosAnuncios = ValueNotifier<bool>(true); // ¿Recibir los anuncios?
  static final ValueNotifier<bool> avisosVersiculo = ValueNotifier<bool>(true); // ¿Recibir el versículo del día como notificación?
  static final ValueNotifier<Set<int>> recordatorios = ValueNotifier<Set<int>>({}); // Cultos (id) con recordatorio 30 min antes
  static final ValueNotifier<Set<int>> recordatoriosEventos = ValueNotifier<Set<int>>({}); // Eventos especiales (id) con recordatorio

  static const double escalaLetraGrande = 1.2; // Cuánto se agranda la letra (20 % más)

  static String nombreInscripcion = ''; // Último nombre usado al inscribirse a un evento (para no escribirlo otra vez)
  static String telefonoInscripcion = ''; // Último teléfono usado

  static Future<void> cargar() async { // Lee lo guardado (se llama al abrir la app)
    try { // Si la caja fuerte falla, se quedan los valores por defecto
      letraGrande.value = await _almacen.read(key: 'pref_letra_grande') == 'si'; // Letra grande
      apariencia.value = await _almacen.read(key: 'pref_apariencia') ?? 'sistema'; // Claro / oscuro / como el teléfono
      nombreInscripcion = await _almacen.read(key: 'pref_inscripcion_nombre') ?? ''; // Último nombre de inscripción
      telefonoInscripcion = await _almacen.read(key: 'pref_inscripcion_telefono') ?? ''; // Último teléfono de inscripción
      avisosEnVivo.value = await _almacen.read(key: 'pref_avisos_en_vivo') != 'no'; // En vivo (encendido si nunca se tocó)
      avisosAnuncios.value = await _almacen.read(key: 'pref_avisos_anuncios') != 'no'; // Anuncios (encendido si nunca se tocó)
      avisosVersiculo.value = await _almacen.read(key: 'pref_avisos_versiculo') != 'no'; // Versículo del día (encendido si nunca se tocó)
      final texto = await _almacen.read(key: 'pref_recordatorios'); // Lista de recordatorios, ej: "[11,14]"
      recordatorios.value = texto == null ? {} : (jsonDecode(texto) as List).cast<int>().toSet(); // A conjunto de números
      final eventos = await _almacen.read(key: 'pref_recordatorios_eventos'); // Eventos con recordatorio
      recordatoriosEventos.value = eventos == null ? {} : (jsonDecode(eventos) as List).cast<int>().toSet(); // A conjunto de números
    } catch (_) {} // Valores por defecto
  } // Fin de cargar

  static Future<void> cambiarLetraGrande(bool valor) async { // Interruptor "Letra grande"
    letraGrande.value = valor; // Avisa a la app (se redibuja con el tamaño nuevo)
    await _guardar('pref_letra_grande', valor ? 'si' : 'no'); // Lo recuerda
  } // Fin de cambiarLetraGrande

  static Future<void> cambiarApariencia(String valor) async { // Selector "Apariencia"
    apariencia.value = valor; // Avisa (la app cambia de colores al instante)
    await _guardar('pref_apariencia', valor); // Lo recuerda
  } // Fin de cambiarApariencia

  static Future<void> cambiarAvisosEnVivo(bool valor) async { // Interruptor "Avisarme cuando estemos en vivo"
    avisosEnVivo.value = valor; // Avisa
    await _guardar('pref_avisos_en_vivo', valor ? 'si' : 'no'); // Lo recuerda
  } // Fin de cambiarAvisosEnVivo

  static Future<void> cambiarAvisosAnuncios(bool valor) async { // Interruptor "Avisarme de anuncios"
    avisosAnuncios.value = valor; // Avisa
    await _guardar('pref_avisos_anuncios', valor ? 'si' : 'no'); // Lo recuerda
  } // Fin de cambiarAvisosAnuncios

  static Future<void> cambiarAvisosVersiculo(bool valor) async { // Interruptor "Recibir el versículo del día"
    avisosVersiculo.value = valor; // Avisa
    await _guardar('pref_avisos_versiculo', valor ? 'si' : 'no'); // Lo recuerda
  } // Fin de cambiarAvisosVersiculo

  static Future<void> guardarRecordatorios(Set<int> ids) async { // Lista de cultos con recordatorio
    recordatorios.value = {...ids}; // Avisa (un conjunto nuevo para que se note el cambio)
    await _guardar('pref_recordatorios', jsonEncode(ids.toList())); // Lo recuerda
  } // Fin de guardarRecordatorios

  static Future<void> guardarRecordatoriosEventos(Set<int> ids) async { // Lista de eventos con recordatorio
    recordatoriosEventos.value = {...ids}; // Avisa (conjunto nuevo)
    await _guardar('pref_recordatorios_eventos', jsonEncode(ids.toList())); // Lo recuerda
  } // Fin de guardarRecordatoriosEventos

  static Future<void> guardarDatosInscripcion(String nombre, String telefono) async { // Recuerda nombre y teléfono de la última inscripción
    nombreInscripcion = nombre; telefonoInscripcion = telefono; // En memoria
    await _guardar('pref_inscripcion_nombre', nombre); // En el teléfono
    await _guardar('pref_inscripcion_telefono', telefono); // En el teléfono
  } // Fin de guardarDatosInscripcion

  static Future<void> _guardar(String clave, String valor) async { // Escribe en la caja fuerte sin tumbar la app si falla
    try { await _almacen.write(key: clave, value: valor); } catch (_) {} // Si falla, solo se pierde al cerrar la app
  } // Fin de _guardar
} // Fin de Preferencias
