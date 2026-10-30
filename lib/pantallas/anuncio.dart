import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../componentes/tarjeta_anuncio.dart'; // Tarjeta completa del anuncio
import '../modelos/anuncio.dart'; // Molde de un anuncio

class PantallaAnuncio extends StatelessWidget { // Detalle de un anuncio (se abre al tocarlo en el carrusel de Inicio)
  const PantallaAnuncio({super.key, required this.anuncio}); // Constructor

  final Anuncio anuncio; // Datos del anuncio

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Scaffold( // Estructura
      appBar: AppBar(title: const Text('Anuncio')), // Barra con flecha para volver
      body: ListView( // Desplazable (por si el texto o el flyer son largos)
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24), // Márgenes
        children: [TarjetaAnuncio(anuncio: anuncio)], // La tarjeta completa: título, texto, flyer, botón, fechas y Compartir
      ), // Fin de la lista
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de PantallaAnuncio
