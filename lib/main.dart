import 'package:flutter/material.dart'; // Componentes visuales de Flutter
import 'package:just_audio_background/just_audio_background.dart'; // Radio en segundo plano (pantalla bloqueada)

import 'pantallas/principal.dart'; // Pantalla con el menú de abajo y las pestañas
import 'servicios/api.dart'; // Llamadas a la API del panel
import 'servicios/preferencias.dart'; // Letra grande y otras preferencias guardadas
import 'servicios/registro.dart'; // Registro del teléfono en el panel
import 'tema.dart'; // Colores y estilos de Canaán

Future<void> main() async { // Punto de arranque: es lo primero que se ejecuta al abrir la app
  await JustAudioBackground.init( // Prepara la radio para sonar en segundo plano (Paso 11)
    androidNotificationChannelId: 'com.mcccanaan.canaan_app.radio', // Canal de notificaciones de la radio (Android)
    androidNotificationChannelName: 'Radio', // Nombre del canal que se ve en Ajustes → Notificaciones
    androidNotificationOngoing: true, // Mientras suena, la notificación no se puede quitar deslizando (se detiene con el botón)
  ); // Fin de la preparación
  await Preferencias.cargar(); // Lee las preferencias guardadas (letra grande, notificaciones, recordatorios)
  runApp(CanaanApp()); // Dibuja la app en la pantalla
} // Fin de main

class CanaanApp extends StatelessWidget { // La app completa
  CanaanApp({super.key, this.api = const Api(), RegistroDispositivo? registro}) // Constructor; por defecto la API real (en las pruebas, una falsa)
      : registro = registro ?? RegistroDispositivo(api: api); // Si no se pasa un registro, crea uno con esa API

  final Api api; // De dónde se sacan los datos
  final RegistroDispositivo registro; // Se encarga de registrar el teléfono

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve la app
    return MaterialApp( // Contenedor principal con el estilo Material de Google
      title: 'Canaán', // Nombre de la app (pestaña del navegador y lista de apps abiertas)
      debugShowCheckedModeBanner: false, // Quita la cinta roja "DEBUG"
      theme: temaCanaan(), // Colores y estilos de Canaán (lib/tema.dart)
      home: PantallaPrincipal(api: api, registro: registro), // Primera pantalla: la del menú de abajo
      builder: (context, pantalla) => ValueListenableBuilder<bool>( // Envuelve TODA la app para aplicar "Letra grande"
        valueListenable: Preferencias.letraGrande, // Escucha la preferencia
        builder: (context, grande, _) { // Cada vez que cambia
          final medidas = MediaQuery.of(context); // Medidas del teléfono (incluye el tamaño de letra del sistema)
          return MediaQuery( // Mismas medidas...
            data: medidas.copyWith(textScaler: grande ? TextScaler.linear(medidas.textScaler.scale(1) * Preferencias.escalaLetraGrande) : medidas.textScaler), // ...con la letra 20 % más grande si está activada
            child: pantalla!, // La app
          ); // Fin
        }, // Fin del builder
      ), // Fin de la letra grande
    ); // Fin de MaterialApp
  } // Fin de build
} // Fin de CanaanApp
