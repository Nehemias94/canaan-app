import 'package:flutter/material.dart'; // Componentes visuales de Flutter
import 'package:url_launcher/url_launcher.dart'; // Abrir el enlace del botón fuera de la app

import '../servicios/compartir.dart'; // Compartir la foto que se está viendo

// Piezas que comparten los anuncios y los eventos especiales: la imagen (flyer) y el botón con enlace.

class ImagenRed extends StatelessWidget { // Imagen de internet con esquinas redondeadas; al tocarla se ve en grande
  const ImagenRed({super.key, required this.url, this.altoMaximo = 340}); // Constructor

  final String url; // Dirección de la imagen
  final double altoMaximo; // Para que un flyer muy alto no llene toda la pantalla

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Semantics( // Para lectores de pantalla
      label: 'Imagen. Toca para verla en grande', // Lo que leen
      button: true, // Se puede tocar
      child: GestureDetector( // Se puede tocar
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VisorImagen(url: url))), // Abre el visor
        child: ClipRRect( // Recorta las esquinas
          borderRadius: BorderRadius.circular(12), // Redondeadas
          child: ConstrainedBox( // Límite de alto
            constraints: BoxConstraints(maxHeight: altoMaximo), // Máximo
            child: Image.network( // Descarga la imagen
              url, // Dirección
              width: double.infinity, // Todo el ancho
              fit: BoxFit.cover, // Llena el espacio (recorta lo que sobre)
              loadingBuilder: (context, hijo, progreso) => progreso == null // Mientras descarga...
                  ? hijo // ...ya terminó: la imagen
                  : Container(height: 180, color: Colors.black12, alignment: Alignment.center, child: const CircularProgressIndicator(strokeWidth: 2)), // ...recuadro gris con rueda
              errorBuilder: (context, error, pila) => const SizedBox.shrink(), // Si no carga (sin internet), no muestra nada: el texto sigue
            ), // Fin de la imagen
          ), // Fin del límite
        ), // Fin del recorte
      ), // Fin de GestureDetector
    ); // Fin de Semantics
  } // Fin de build
} // Fin de ImagenRed

class VisorImagen extends StatelessWidget { // Pantalla negra con la imagen en grande (se puede acercar con dos dedos)
  const VisorImagen({super.key, required this.url}); // Constructor

  final String url; // Dirección de la imagen

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Scaffold( // Estructura
      backgroundColor: Colors.black, // Fondo negro
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('Imagen')), // Barra con flecha para volver
      body: InteractiveViewer( // Permite acercar y mover con los dedos
        maxScale: 5, // Hasta 5 veces
        child: Center(child: Image.network(url, fit: BoxFit.contain)), // Imagen completa
      ), // Fin del visor
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de VisorImagen

class BotonEnlace extends StatelessWidget { // Botón grande que abre un enlace (formulario, mapa, WhatsApp…)
  const BotonEnlace({super.key, required this.texto, required this.url, this.color = const Color(0xFF004B82)}); // Constructor (azul Canaán por defecto)

  final String texto; // Ej: "Inscríbete"
  final String url; // Enlace
  final Color color; // Color del botón

  Future<void> _abrir(BuildContext context) async { // Abre el enlace fuera de la app
    final mensajero = ScaffoldMessenger.of(context); // Para avisar si falla (se toma antes de esperar)
    final abrio = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false); // Navegador o la app que corresponda
    if (!abrio) mensajero.showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace. Revisa tu conexión a internet.'))); // Aviso amable
  } // Fin de _abrir

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return FilledButton.icon( // Botón relleno
      style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)), // Todo el ancho, alto 48
      icon: const Icon(Icons.open_in_new, size: 20), // Ícono "abrir afuera"
      label: Text(texto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), // Texto
      onPressed: () => _abrir(context), // Abre
    ); // Fin del botón
  } // Fin de build
} // Fin de BotonEnlace

class VisorGaleria extends StatefulWidget { // Fotos de un evento en pantalla completa: se pasan deslizando, se acercan con dos dedos y se comparten
  const VisorGaleria({super.key, required this.fotos, required this.titulo, this.inicial = 0}); // Constructor

  final List<String> fotos; // Direcciones de las fotos
  final String titulo; // Nombre del evento (para compartir)
  final int inicial; // Foto que se abre primero

  @override // Reemplaza createState
  State<VisorGaleria> createState() => _VisorGaleriaState(); // Crea el estado
} // Fin de VisorGaleria

class _VisorGaleriaState extends State<VisorGaleria> { // Estado: foto actual
  late final _paginas = PageController(initialPage: widget.inicial); // Control de las páginas
  late int _actual = widget.inicial; // Foto que se ve

  @override // Reemplaza dispose
  void dispose() { // Al cerrar
    _paginas.dispose(); // Libera el control
    super.dispose(); // Lo de Flutter por defecto
  } // Fin de dispose

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Scaffold( // Estructura
      backgroundColor: Colors.black, // Fondo negro
      appBar: AppBar( // Barra con flecha para volver
        backgroundColor: Colors.black, foregroundColor: Colors.white, // Negra
        title: Text('${_actual + 1} / ${widget.fotos.length}'), // "3 / 20"
        actions: [IconButton(tooltip: 'Compartir foto', icon: const Icon(Icons.share), onPressed: () => Compartir.conImagen('📷 ${widget.titulo}', widget.fotos[_actual]))], // Compartir esta foto
      ), // Fin de la barra
      body: PageView.builder( // Una foto por página
        controller: _paginas, // Control
        itemCount: widget.fotos.length, // Cuántas
        onPageChanged: (i) => setState(() => _actual = i), // Actualiza el contador
        itemBuilder: (context, i) => InteractiveViewer( // Acercar con dos dedos
          maxScale: 5, // Hasta 5 veces
          child: Center(child: Image.network(widget.fotos[i], fit: BoxFit.contain, errorBuilder: (c, e, p) => const Icon(Icons.broken_image, color: Colors.white54, size: 64))), // Foto (o ícono si no carga)
        ), // Fin de la página
      ), // Fin de PageView
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de _VisorGaleriaState
