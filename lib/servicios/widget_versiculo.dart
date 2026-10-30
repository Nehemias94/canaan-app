import 'package:flutter/foundation.dart'; // kIsWeb, defaultTargetPlatform y debugPrint
import 'package:home_widget/home_widget.dart'; // Comunicación con el widget de la pantalla de inicio

import '../modelos/iglesia.dart'; // VersiculoDia

// Widget "Versículo del día" en la pantalla de inicio de Android (el diseño está en android/…/res/layout/widget_versiculo.xml
// y su código en VersiculoWidget.kt). La app le pasa el versículo cada vez que carga Inicio: así se actualiza al abrir la app.
class WidgetVersiculo { // Todo junto
  static const _proveedor = 'com.mcccanaan.canaan_app.VersiculoWidget'; // Nombre completo de la clase de Android

  static String? _ultimo; // Último versículo enviado (para no redibujar si no cambió)

  static Future<void> actualizar(VersiculoDia? versiculo) async { // Guarda el versículo para el widget y lo redibuja
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return; // Solo en Android (en el navegador no hay widgets)
    final clave = '${versiculo?.referencia}|${versiculo?.texto}'; // Para saber si cambió
    if (clave == _ultimo) return; // Igual que la última vez: nada que hacer
    try { // Que una falla del widget nunca afecte a la app
      await HomeWidget.saveWidgetData<String>('versiculo_texto', versiculo == null ? null : '“${versiculo.texto}”'); // Texto entre comillas (null = el widget invita a abrir la app)
      await HomeWidget.saveWidgetData<String>('versiculo_referencia', versiculo?.referencia); // Cita
      await HomeWidget.updateWidget(qualifiedAndroidName: _proveedor); // Pide a Android redibujarlo
      _ultimo = clave; // Recuerda lo enviado
    } catch (error) { // Sin widget en la pantalla o en las pruebas automáticas (no hay Android)
      debugPrint('Widget del versículo: $error'); // Solo lo anota
    } // Fin del try
  } // Fin de actualizar
} // Fin de WidgetVersiculo
