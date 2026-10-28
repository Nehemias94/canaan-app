import 'dart:async'; // unawaited (arrancar algo sin esperar a que termine)

import 'package:firebase_core/firebase_core.dart'; // Arranque de Firebase
import 'package:firebase_messaging/firebase_messaging.dart'; // Notificaciones de Firebase
import 'package:flutter/foundation.dart'; // kIsWeb y debugPrint

import '../firebase_config.dart'; // Datos del proyecto de Firebase (vacíos = sin notificaciones)
import 'api.dart'; // Para enviar el fcm_token al panel
import 'registro.dart'; // Llave del teléfono

// Notificaciones (Paso 8). Al abrir la app:
// 1) arranca Firebase, 2) pide permiso, 3) obtiene la dirección del teléfono (fcm_token) y se la envía al panel,
// 4) en Android/iPhone se suscribe al tema "todos" (el panel envía UNA notificación a ese tema y llega a todos),
// 5) avisa a la pantalla cuando llega una notificación con la app abierta, o cuando la persona toca una.
class ServicioNotificaciones { // Todo lo de notificaciones en un solo lugar
  static const String tema = 'todos'; // Tema al que envía el panel (igual que App\Support\Notificaciones::TEMA)

  static Future<void> iniciar({ // Arranca todo; si Firebase no está configurado, no hace nada
    required Api api, // Para enviar el fcm_token
    required RegistroDispositivo registro, // Llave del teléfono
    required void Function(RemoteMessage mensaje) alRecibir, // Qué hacer si llega una notificación con la app ABIERTA (el teléfono no la muestra solo)
    required void Function(RemoteMessage mensaje) alTocar, // Qué hacer cuando la persona TOCA una notificación
  }) async {
    if (!firebaseConfigurado) return; // Sin datos de Firebase (firebase_config.dart vacío): la app sigue sin notificaciones
    try { // Cualquier falla aquí no debe tumbar la app
      await Firebase.initializeApp(options: opcionesFirebase()); // 1) Arranca Firebase con los datos del proyecto
      final mensajeria = FirebaseMessaging.instance; // Atajo a la mensajería

      final permiso = await mensajeria.requestPermission(); // 2) Pide permiso (Android 13+, iPhone y navegador muestran una ventana)
      if (permiso.authorizationStatus == AuthorizationStatus.denied) { // Si dijo que no...
        await registro.conLlave((t) => api.guardarFcmToken(token: t, fcmToken: null)); // ...avisa al panel (borra su dirección)
        return; // ...y termina
      } // Fin del if

      // ignore: deprecated_member_use (getToken sigue funcionando; el método nuevo register()/onRegistered entrega otro tipo de id: revisar al actualizar el paquete)
      final fcmToken = await mensajeria.getToken(vapidKey: kIsWeb ? vapidKey : null); // 3) Dirección de este teléfono en Firebase (en el navegador necesita la clave VAPID)
      if (fcmToken != null) await registro.conLlave((t) => api.guardarFcmToken(token: t, fcmToken: fcmToken)); // La envía al panel
      // ignore: deprecated_member_use (mismo motivo que getToken)
      mensajeria.onTokenRefresh.listen((nuevo) { // Si Firebase la cambia más adelante...
        unawaited(registro.conLlave((t) => api.guardarFcmToken(token: t, fcmToken: nuevo)).catchError((_) {})); // ...envía la nueva
      }); // Fin de la escucha

      if (!kIsWeb) await mensajeria.subscribeToTopic(tema); // 4) Android/iPhone: se suscribe al tema "todos" (el navegador no admite temas)

      FirebaseMessaging.onMessage.listen(alRecibir); // 5a) Llega con la app abierta
      FirebaseMessaging.onMessageOpenedApp.listen(alTocar); // 5b) La toca con la app en segundo plano
      final inicial = await mensajeria.getInitialMessage(); // 5c) La app estaba CERRADA y se abrió tocando una notificación
      if (inicial != null) alTocar(inicial); // La atiende
    } catch (error) { // Algo falló (datos mal copiados, sin internet…)
      debugPrint('Notificaciones: no se pudieron activar: $error'); // Solo lo anota en la consola de desarrollo
    } // Fin del try
  } // Fin de iniciar
} // Fin de ServicioNotificaciones
