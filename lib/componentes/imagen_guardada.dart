import 'package:cached_network_image/cached_network_image.dart'; // Imagen de internet que se guarda en el teléfono
import 'package:flutter/material.dart'; // Componentes visuales de Flutter
import 'package:flutter_cache_manager/flutter_cache_manager.dart'; // Reglas del guardado

// Imágenes de internet (flyers, miniaturas, fotos, logo, QR) GUARDADAS en la carpeta privada de la app ("caché"):
// NO van a la galería del teléfono; la segunda vez se ven al instante, sin gastar datos y aunque no haya internet.
// Máximo 300 imágenes (unos 60 MB con flyers normales); las que no se usan en 30 días se borran solas.
// Si cambian la imagen en el panel, tiene otra dirección: se descarga la nueva.

class ImagenGuardada extends StatelessWidget { // Reemplaza a Image.network en toda la app
  const ImagenGuardada(this.url, {super.key, this.fit, this.width, this.height, this.alError, this.cargando}); // Constructor

  final String url; // Dirección de la imagen
  final BoxFit? fit; // Cómo llena su espacio (cover, contain…)
  final double? width; // Ancho (opcional)
  final double? height; // Alto (opcional)
  final Widget Function(BuildContext context)? alError; // Qué mostrar si no se puede cargar (null = nada)
  final Widget Function(BuildContext context)? cargando; // Qué mostrar mientras descarga (null = nada)

  static bool usarGuardado = true; // false en las pruebas (el guardado necesita el almacenamiento real del teléfono)

  static final CacheManager guardado = CacheManager(Config( // Reglas del guardado
    'canaan_imagenes', // Nombre de la carpeta privada
    stalePeriod: const Duration(days: 30), // Las que no se usan en 30 días se borran solas
    maxNrOfCacheObjects: 300, // Máximo de imágenes guardadas (las más viejas se borran primero)
  )); // Fin de las reglas

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    if (!usarGuardado) { // En las pruebas: imagen normal de internet
      return Image.network( // Sin guardar
        url, fit: fit, width: width, height: height, // Mismos tamaños
        errorBuilder: (c, e, p) => alError?.call(c) ?? const SizedBox.shrink(), // Si falla
      ); // Fin de la imagen
    } // Fin del if
    return CachedNetworkImage( // Imagen guardada en el teléfono
      imageUrl: url, // Dirección
      cacheManager: guardado, // Con nuestras reglas (300 imágenes, 30 días)
      fit: fit, width: width, height: height, // Tamaños
      fadeInDuration: const Duration(milliseconds: 200), // Aparece suave al descargar (la guardada sale al instante)
      placeholder: cargando == null ? null : (c, _) => cargando!(c), // Mientras descarga
      errorWidget: (c, _, _) => alError?.call(c) ?? const SizedBox.shrink(), // Si no carga (sin internet y sin copia): nada, o lo indicado
    ); // Fin de la imagen
  } // Fin de build
} // Fin de ImagenGuardada
