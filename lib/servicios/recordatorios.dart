import 'dart:io' show Platform; // Saber si es Android o iPhone

import 'package:flutter/foundation.dart'; // kIsWeb y debugPrint
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Notificaciones programadas (las crea el teléfono, sin internet)
import 'package:flutter_timezone/flutter_timezone.dart'; // Zona horaria del teléfono (ej: America/El_Salvador)
import 'package:permission_handler/permission_handler.dart'; // Permiso de notificaciones
import 'package:timezone/data/latest_all.dart' as zonas; // Datos de todas las zonas horarias
import 'package:timezone/timezone.dart' as tz; // Fechas con zona horaria

import '../modelos/actividad.dart'; // Molde de una actividad del horario
import '../modelos/evento.dart'; // Molde de un evento especial
import '../tema.dart'; // horaCorta (texto de las horas)
import 'preferencias.dart'; // Lista de cultos con recordatorio

// Recordatorios de cultos: el teléfono avisa 30 minutos antes, CADA SEMANA, aunque no haya internet ni la app esté abierta.
// La persona los activa con la campanita 🔔 de cada culto en Horario. Si el panel cambia la hora, se reprograman al abrir Horario.
class Recordatorios { // Todo lo de recordatorios
  static const minutosAntes = 30; // Cuánto antes avisa
  static const _base = 500000; // Los números de estas notificaciones empiezan aquí (no chocan con las de la geocerca, que usan el id del anuncio)
  static const _baseEventos = 600000; // Números de los recordatorios de eventos especiales

  static bool get soportado => !kIsWeb && (Platform.isAndroid || Platform.isIOS); // Solo en teléfonos (no en el navegador ni en las pruebas)

  static final _notificaciones = FlutterLocalNotificationsPlugin(); // Notificaciones locales
  static bool _listo = false; // ¿Ya se preparó?

  static Future<void> _preparar() async { // Prepara zonas horarias y notificaciones (una sola vez)
    if (_listo) return; // Ya estaba
    zonas.initializeTimeZones(); // Carga las zonas horarias
    try { // Zona del teléfono
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier)); // Ej: America/El_Salvador
    } catch (_) { // Si no se pudo saber...
      tz.setLocalLocation(tz.getLocation('America/El_Salvador')); // ...la de la iglesia
    } // Fin del try
    await _notificaciones.initialize(settings: const InitializationSettings( // Prepara las notificaciones
      android: AndroidInitializationSettings('@mipmap/ic_launcher'), // Ícono
      iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false), // Permisos se piden aparte
    )); // Fin de la preparación
    _listo = true; // Listo
  } // Fin de _preparar

  static Future<bool> activar(Actividad actividad) async { // Activa el recordatorio de un culto (true = quedó activado)
    if (!soportado || actividad.proxima == null) return false; // Sin teléfono o sin fecha: no se puede
    if (!await Permission.notification.request().isGranted) return false; // Sin permiso de notificaciones: no se puede
    await _preparar(); // Prepara
    await _programar(actividad); // Programa la notificación semanal
    await Preferencias.guardarRecordatorios({...Preferencias.recordatorios.value, actividad.id}); // Lo recuerda
    return true; // Listo
  } // Fin de activar

  static Future<void> desactivar(int actividadId) async { // Quita el recordatorio de un culto
    if (soportado) { // Solo en teléfonos
      await _preparar(); // Prepara
      await _notificaciones.cancel(id: _base + actividadId); // Cancela la notificación programada
    } // Fin del if
    await Preferencias.guardarRecordatorios({...Preferencias.recordatorios.value}..remove(actividadId)); // Lo olvida
  } // Fin de desactivar

  static Future<void> sincronizar(List<Actividad> horario) async { // Reprograma con los datos nuevos del panel (por si cambió la hora) y quita los de cultos que ya no existen
    if (!soportado || Preferencias.recordatorios.value.isEmpty) return; // Nada que hacer
    try { // Que una falla no afecte al Horario
      await _preparar(); // Prepara
      final porId = {for (final a in horario) a.id: a}; // Actividades por número
      for (final id in {...Preferencias.recordatorios.value}) { // Cada recordatorio activado
        final actividad = porId[id]; // Su actividad
        if (actividad == null || actividad.proxima == null) { // Ya no existe (o sin fecha)...
          await desactivar(id); // ...se quita
        } else { // Sigue...
          await _programar(actividad); // ...se reprograma (misma id: reemplaza la anterior)
        } // Fin del if
      } // Fin del for
    } catch (error) { // Falló
      debugPrint('Recordatorios: no se pudieron sincronizar: $error'); // Solo lo anota
    } // Fin del try
  } // Fin de sincronizar

  static const _porEvento = 25; // Números reservados por evento (máximo: 7 días × 3 por día + 1 del mismo día = 22)

  static String _tiempo(int minutos) => minutos % 60 == 0 // "1 hora", "2 horas" o "30 minutos"
      ? '${minutos ~/ 60} ${minutos == 60 ? 'hora' : 'horas'}' // Horas exactas
      : '$minutos minutos'; // Minutos

  static List<({DateTime cuando, String titulo})> avisosDeEvento(Evento evento, DateTime ahora) { // Los avisos que el teléfono programaría para un evento (solo los que aún no pasan), en orden. Pública para las pruebas
    final avisos = <({DateTime cuando, String titulo})>[]; // Lista
    final inicio = evento.iniciaEn; // Cuándo empieza
    for (var dias = evento.diasAntes; dias >= 1; dias--) { // Cada día desde N días antes hasta la víspera
      for (final hora in evento.horasAviso) { // Cada hora de ese día (1, 2 o 3)
        final partes = hora.split(':'); // "18:00" → ["18", "00"]
        final cuando = DateTime(inicio.year, inicio.month, inicio.day - dias, int.parse(partes[0]), int.parse(partes[1])); // Ese día a esa hora
        if (cuando.isAfter(ahora) && cuando.isBefore(inicio)) avisos.add((cuando: cuando, titulo: dias == 1 ? '📅 Mañana: ${evento.titulo}' : '📅 En $dias días: ${evento.titulo}')); // Solo si aún no pasa
      } // Fin del for de horas
    } // Fin del for de días
    if (evento.minutosAntes > 0) { // Aviso del mismo día
      final cuando = inicio.subtract(Duration(minutes: evento.minutosAntes)); // Minutos antes de empezar
      if (cuando.isAfter(ahora)) avisos.add((cuando: cuando, titulo: '⏰ En ${_tiempo(evento.minutosAntes)}: ${evento.titulo}')); // Solo si aún no pasa
    } // Fin del if
    return avisos; // Lista (puede estar vacía)
  } // Fin de avisosDeEvento

  static String explicacionDeEvento(Evento evento, DateTime ahora) { // Para el mensaje al activar la 🔔, ej: "cada día desde 3 días antes (9:00 am y 6:00 pm) y 1 hora antes de empezar"
    final avisos = avisosDeEvento(evento, ahora); // Los que aún no pasan
    final partes = <String>[]; // Partes del texto
    if (avisos.any((a) => a.titulo.startsWith('📅'))) { // Quedan avisos de días antes
      final horas = evento.horasAviso.map((h) { final p = h.split(':'); return horaCorta(DateTime(2000, 1, 1, int.parse(p[0]), int.parse(p[1]))); }).join(' y '); // "9:00 am y 6:00 pm"
      partes.add('${evento.diasAntes == 1 ? 'un día antes' : 'cada día desde ${evento.diasAntes} días antes'} ($horas)'); // Días antes
    } // Fin del if
    if (avisos.any((a) => a.titulo.startsWith('⏰'))) partes.add('${_tiempo(evento.minutosAntes)} antes de empezar'); // El mismo día
    return partes.join(' y '); // Todo junto
  } // Fin de explicacionDeEvento

  static Future<void> _programarEvento(Evento evento) async { // Programa (o reemplaza) los avisos de un evento
    await _cancelarEvento(evento.id); // Quita los anteriores (por si el panel cambió la fecha o el recordatorio)
    final avisos = avisosDeEvento(evento, DateTime.now()); // Los que aún no pasan
    for (var k = 0; k < avisos.length; k++) { // Cada aviso
      await _notificaciones.zonedSchedule( // Programa (una sola vez: sin matchDateTimeComponents)
        id: _baseEventos + evento.id * _porEvento + k, // Número: hasta 25 por evento
        scheduledDate: tz.TZDateTime.from(avisos[k].cuando, tz.local), // Cuándo
        title: avisos[k].titulo, // Título
        body: [evento.cuandoTexto(), evento.lugar].where((t) => t != null && t.isNotEmpty).join(' · '), // Fecha y lugar
        notificationDetails: const NotificationDetails( // Cómo se ve
          android: AndroidNotificationDetails('recordatorios', 'Recordatorios de cultos', channelDescription: 'Aviso 30 minutos antes de los cultos que elegiste', importance: Importance.high, priority: Priority.high), // Mismo canal que los cultos
          iOS: DarwinNotificationDetails(), // iPhone
        ), // Fin de cómo se ve
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, // Sin permiso de alarmas exactas (puede variar 1–2 minutos)
      ); // Fin de la programación
    } // Fin del for
  } // Fin de _programarEvento

  static Future<void> _cancelarEvento(int eventoId) async { // Cancela los avisos de un evento
    for (var k = 0; k < _porEvento; k++) { // Todos los números reservados del evento
      await _notificaciones.cancel(id: _baseEventos + eventoId * _porEvento + k); // Cancela
    } // Fin del for
    for (final id in [_baseEventos + eventoId * 2, _baseEventos + eventoId * 2 + 1, _baseEventos + eventoId]) { // Números de versiones anteriores de la app
      await _notificaciones.cancel(id: id); // Cancela
    } // Fin del for
  } // Fin de _cancelarEvento

  static Future<String?> activarEvento(Evento evento) async { // Activa la 🔔 de un evento. Devuelve cuándo avisará (ej: "un día antes (9:00 am) y 1 hora antes de empezar") o null si no se pudo
    if (!soportado) return null; // Solo en teléfonos
    final avisos = avisosDeEvento(evento, DateTime.now()); // Avisos que aún no pasan
    if (avisos.isEmpty) return null; // Ya no queda ninguno (o el panel no quiere avisos)
    if (!await Permission.notification.request().isGranted) return null; // Sin permiso: no se puede
    await _preparar(); // Prepara
    await _programarEvento(evento); // Programa los avisos
    await Preferencias.guardarRecordatoriosEventos({...Preferencias.recordatoriosEventos.value, evento.id}); // Lo recuerda
    return explicacionDeEvento(evento, DateTime.now()); // Ej: "cada día desde 3 días antes (9:00 am y 6:00 pm) y 1 hora antes de empezar"
  } // Fin de activarEvento

  static Future<void> desactivarEvento(int eventoId) async { // Quita la 🔔 de un evento
    if (soportado) { // Solo en teléfonos
      await _preparar(); // Prepara
      await _cancelarEvento(eventoId); // Cancela sus avisos
    } // Fin del if
    await Preferencias.guardarRecordatoriosEventos({...Preferencias.recordatoriosEventos.value}..remove(eventoId)); // Lo olvida
  } // Fin de desactivarEvento

  static Future<void> sincronizarEventos(List<Evento> eventos) async { // Reprograma con los datos nuevos del panel (fecha u opciones cambiadas) y olvida los eventos que ya no están
    if (!soportado || Preferencias.recordatoriosEventos.value.isEmpty) return; // Nada que hacer
    try { // Que una falla no afecte a la pestaña Eventos
      await _preparar(); // Prepara
      final porId = {for (final e in eventos) e.id: e}; // Eventos por número
      for (final id in {...Preferencias.recordatoriosEventos.value}) { // Cada evento con 🔔
        final evento = porId[id]; // Su evento
        if (evento == null) { await desactivarEvento(id); continue; } // Ya no existe (borrado o terminó): se olvida
        await _programarEvento(evento); // Sigue: reprograma (si ya no queda ningún aviso, simplemente no programa nada)
      } // Fin del for
    } catch (error) { // Falló
      debugPrint('Recordatorios: no se pudieron sincronizar los eventos: $error'); // Solo lo anota
    } // Fin del try
  } // Fin de sincronizarEventos

  static Future<void> _programar(Actividad actividad) async { // Programa (o reemplaza) la notificación semanal de un culto
    var cuando = tz.TZDateTime.from(actividad.proxima!, tz.local).subtract(const Duration(minutes: minutosAntes)); // 30 min antes de la próxima vez
    final ahora = tz.TZDateTime.now(tz.local); // Ahora
    while (cuando.isBefore(ahora)) { // Si ya pasó (ej: el culto empieza en 10 min)...
      cuando = cuando.add(const Duration(days: 7)); // ...la semana siguiente
    } // Fin del while
    await _notificaciones.zonedSchedule( // Programa
      id: _base + actividad.id, // Número (uno por culto)
      scheduledDate: cuando, // Primera vez
      title: '⏰ En $minutosAntes minutos: ${actividad.nombre}', // Título
      body: [actividad.horario, actividad.lugar].where((t) => t != null && t.isNotEmpty).join(' · '), // "7:00 pm – 8:30 pm · Templo principal"
      notificationDetails: const NotificationDetails( // Cómo se ve
        android: AndroidNotificationDetails('recordatorios', 'Recordatorios de cultos', channelDescription: 'Aviso 30 minutos antes de los cultos que elegiste', importance: Importance.high, priority: Priority.high), // Android
        iOS: DarwinNotificationDetails(), // iPhone
      ), // Fin de cómo se ve
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, // Sin pedir permiso de "alarmas exactas" (puede variar 1–2 minutos)
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // Se repite CADA SEMANA el mismo día y hora
    ); // Fin de la programación
  } // Fin de _programar
} // Fin de Recordatorios
