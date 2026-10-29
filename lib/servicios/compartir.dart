import 'package:share_plus/share_plus.dart'; // Ventana "Compartir" del teléfono (WhatsApp, Facebook, mensajes…)

// Compartir textos (prédicas, anuncios, versículo del día) con la ventana del teléfono.
// "compartir" es una variable para que las pruebas automáticas puedan cambiarla por una de mentira.
class Compartir { // Todo lo de compartir
  static const firma = 'Ministerio Cristiano Canaán'; // Se agrega al final de lo que se comparte

  static Future<void> Function(String texto) compartir = (texto) async { // Abre la ventana de compartir con el texto
    await SharePlus.instance.share(ShareParams(text: texto)); // Ventana del teléfono
  }; // Fin de compartir

  static Future<void> texto(String contenido) => compartir('$contenido\n\n— $firma'); // Comparte agregando la firma de la iglesia
} // Fin de Compartir
