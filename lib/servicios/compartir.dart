import 'package:http/http.dart' as http; // Descargar la imagen (flyer) antes de compartirla
import 'package:share_plus/share_plus.dart'; // Ventana "Compartir" del teléfono (WhatsApp, Facebook, mensajes…)

// Compartir textos (prédicas, anuncios, versículo del día, eventos) con la ventana del teléfono; si hay imagen, también la imagen.
// "compartir" y "compartirImagen" son variables para que las pruebas automáticas puedan cambiarlas por unas de mentira.
class Compartir { // Todo lo de compartir
  static const firma = 'Ministerio Cristiano Canaán'; // Se agrega al final de lo que se comparte

  static Future<void> Function(String texto) compartir = (texto) async { // Abre la ventana de compartir con el texto
    await SharePlus.instance.share(ShareParams(text: texto)); // Ventana del teléfono
  }; // Fin de compartir

  static Future<void> Function(String texto, String imagenUrl) compartirImagen = (texto, imagenUrl) async { // Comparte la imagen CON el texto (en WhatsApp, el texto va como pie de la foto)
    try { // Descarga la imagen
      final respuesta = await http.get(Uri.parse(imagenUrl)).timeout(const Duration(seconds: 15)); // Máximo 15 s
      if (respuesta.statusCode != 200) throw Exception('imagen ${respuesta.statusCode}'); // No se pudo
      final tipo = respuesta.headers['content-type'] ?? 'image/jpeg'; // Tipo de imagen (jpg, png, webp)
      final extension = tipo.contains('png') ? 'png' : (tipo.contains('webp') ? 'webp' : 'jpg'); // Extensión del archivo
      await SharePlus.instance.share(ShareParams( // Ventana del teléfono...
        text: texto, // ...con el texto...
        files: [XFile.fromData(respuesta.bodyBytes, mimeType: tipo, name: 'canaan.$extension')], // ...y la imagen
      )); // Fin
    } catch (_) { // Sin internet o la imagen no está: solo el texto (mejor que nada)
      await compartir(texto); // Texto solo
    } // Fin del try
  }; // Fin de compartirImagen

  static Future<void> texto(String contenido) => compartir('$contenido\n\n— $firma'); // Comparte agregando la firma de la iglesia

  static Future<void> conImagen(String contenido, String? imagenUrl) => imagenUrl == null // ¿Hay imagen?
      ? texto(contenido) // No: solo texto
      : compartirImagen('$contenido\n\n— $firma', imagenUrl); // Sí: imagen + texto con la firma
} // Fin de Compartir
