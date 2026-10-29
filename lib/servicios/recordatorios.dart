import 'dart:io' show Platform; // Saber si es Android o iPhone

import 'package:flutter/foundation.dart'; // kIsWeb y debugPrint
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Notificaciones programadas (las crea el teléfono, sin internet)
import 'package:flutter_timezone/flutter_timezone.dart'; // Zona horaria del teléfono (ej: America/El_Salvador)
import 'package:permission_handler/permission_handler.dart'; // Permiso de notificaciones
import 'package:timezone/data/latest_all.dart' as zonas; // Datos de todas las zonas horarias
import 'package:timezone/timezone.dart' as tz; // Fechas con zona horaria

import '../modelos/actividad.dart'; // Molde de una actividad del horario
import 'preferencias.dart'; // Lista de cultos con recordatorio

// Recordatorios de cultos: el teléfono avisa 30 minutos antes, CADA SEMANA, aunque no haya internet ni la app esté abierta.
// La persona los activa con la campanita 🔔 de cada culto en Horario. Si el panel cambia la hora, se reprograman al abrir Horario.
class Recordatorios { // Todo lo de recordatorios
  static const minutosAntes = 30; // Cuánto antes avisa
  static const _base = 500000; // Los números de estas notificaciones empiezan aquí (no chocan con las de la geocerca, que usan el id del anuncio)

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
