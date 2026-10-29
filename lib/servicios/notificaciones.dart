import 'dart:async'; // unawaited (arrancar algo sin esperar a que termine)

import 'package:firebase_core/firebase_core.dart'; // Arranque de Firebase
import 'package:firebase_messaging/firebase_messaging.dart'; // Notificaciones de Firebase
import 'package:flutter/foundation.dart'; // kIsWeb y debugPrint

import '../firebase_config.dart'; // Datos del proyecto de Firebase (vacíos = sin notificaciones)
import 'api.dart'; // Para enviar el fcm_token al panel
import 'geocerca.dart'; // Copia de los anuncios "Solo área" (se actualiza con el aviso silencioso)
import 'recarga.dart'; // "Timbre" para recargar Inicio al instante (aviso urgente)
import 'registro.dart'; // Llave del teléfono

const String avisoActualizarArea = 'actualizar_area'; // Tipo del aviso SILENCIOSO del panel: "actualiza tus anuncios de área" (igual que en App\Models\Anuncio)

bool esAvisoSilencioso(RemoteMessage mensaje) => mensaje.data['tipo'] == avisoActualizarArea; // ¿Es el aviso invisible del panel?

Future<void> actualizarCopiaArea() async { // Pide los anuncios al panel y guarda la copia de los de área (la usa el aviso al llegar a la iglesia)
  try { // Sin internet o panel dormido: se queda la copia anterior
    final anuncios = await const Api().obtenerAnuncios().timeout(const Duration(seconds: 40)); // Anuncios visibles (40 s: el panel puede tardar en despertar)
    await Geocerca().guardarCopia(anuncios); // Guarda los de área en la caja fuerte
  } catch (error) { // Falló
    debugPrint('Notificaciones: no se pudo actualizar la copia de anuncios de área: $error'); // Solo lo anota
  } // Fin del try
} // Fin de actualizarCopiaArea

// Se ejecuta cuando llega un mensaje con la app CERRADA o en segundo plano (Android/iPhone).
// Debe ser una función "suelta" con @pragma: el teléfono despierta a la app un momento, sin abrirla.
@pragma('vm:entry-point') // No borrar: sin esto, la versión final de la app la eliminaría por "no usada"
Future<void> mensajeEnSegundoPlano(RemoteMessage mensaje) async { // Mensaje recibido
  if (!esAvisoSilencioso(mensaje)) return; // Las notificaciones normales las muestra el teléfono solo: aquí no hay nada que hacer
  await Firebase.initializeApp(options: opcionesFirebase()); // En segundo plano la app arranca "en frío": hay que iniciar Firebase otra vez
  await actualizarCopiaArea(); // Actualiza la copia de anuncios de área (no se ve nada en la pantalla)
} // Fin de mensajeEnSegundoPlano

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
      if (!kIsWeb) FirebaseMessaging.onBackgroundMessage(mensajeEnSegundoPlano); // Mensajes con la app cerrada (el aviso silencioso de anuncios de área); en el navegador no aplica

      final permiso = await mensajeria.requestPermission(); // 2) Pide permiso (Android 13+, iPhone y navegador muestran una ventana)
      if (permiso.authorizationStatus == AuthorizationStatus.denied) { // Si dijo que no...
        await registro.conLlave((t) => api.guardarFcmToken(token: t, fcmToken: null)); // ...avisa al panel (borra su dirección)
        return; // ...y termina
      } // Fin del if

      // ignore: deprecated_member_use (getToken sigue funcionando; el método nuevo register()/onRegistered entrega otro tipo de id: revisar al actualizar el paquete)
      final fcmToken = await mensajeria.getToken(vapidKey: kIsWeb ? vapidKey : null); // 3) Dirección de este teléfono en Firebase (en el navegador necesita la clave VAPID)
      if (fcmToken != null) { // Si Firebase dio la dirección...
        try { // ...intenta enviarla al panel (si falla, NO detiene lo demás: el tema "todos" no depende del panel)
          await registro.conLlave((t) => api.guardarFcmToken(token: t, fcmToken: fcmToken)); // La envía al panel
        } catch (error) { // Sin internet o panel dormido: se vuelve a intentar la próxima vez que se abra la app
          debugPrint('Notificaciones: no se pudo guardar la dirección en el panel: $error'); // Solo lo anota
        } // Fin del try
      } // Fin del if
      // ignore: deprecated_member_use (mismo motivo que getToken)
      mensajeria.onTokenRefresh.listen((nuevo) { // Si Firebase la cambia más adelante...
        unawaited(registro.conLlave((t) => api.guardarFcmToken(token: t, fcmToken: nuevo)).catchError((_) {})); // ...envía la nueva
      }); // Fin de la escucha

      if (!kIsWeb) await mensajeria.subscribeToTopic(tema); // 4) Android/iPhone: se suscribe al tema "todos" (el navegador no admite temas)

      FirebaseMessaging.onMessage.listen((mensaje) { // 5a) Llega con la app abierta...
        if (esAvisoSilencioso(mensaje)) { // ...si es el aviso invisible del panel...
          unawaited(actualizarCopiaArea()); // ...solo actualiza la copia de anuncios de área (no muestra nada)
          return; // Fin
        } // Fin del if
        if (mensaje.data['tipo'] == avisoRecargarInicio) { // ...si cambió el aviso urgente en el panel...
          tocarTimbreInicio(); // ...Inicio recarga al instante (con la app CERRADA este aviso se ignora: al abrirla se actualiza sola)
          return; // Fin
        } // Fin del if
        if (mensaje.notification != null) alRecibir(mensaje); // ...si es una notificación normal, la muestra abajo
      }); // Fin de la escucha
      FirebaseMessaging.onMessageOpenedApp.listen(alTocar); // 5b) La toca con la app en segundo plano
      final inicial = await mensajeria.getInitialMessage(); // 5c) La app estaba CERRADA y se abrió tocando una notificación
      if (inicial != null) alTocar(inicial); // La atiende
    } catch (error) { // Algo falló (datos mal copiados, sin internet…)
      debugPrint('Notificaciones: no se pudieron activar: $error'); // Solo lo anota en la consola de desarrollo
    } // Fin del try
  } // Fin de iniciar
} // Fin de ServicioNotificaciones
