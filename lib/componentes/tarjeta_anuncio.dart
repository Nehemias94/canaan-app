import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../modelos/anuncio.dart'; // Molde de un anuncio
import '../servicios/compartir.dart'; // Botón Compartir
import '../tema.dart'; // Colores y fechas de Canaán
import 'imagen_y_boton.dart'; // Imagen (flyer) y botón con enlace
import 'tarjeta.dart'; // Tarjeta con franja de color

// Tarjeta COMPLETA de un anuncio (título, texto, flyer y botón). Sin fechas: la del envío confundía con la del flyer (30 oct 2026).
// Se usa en el detalle del anuncio y en "Ver todo" (en Inicio va el carrusel de tarjetas pequeñas).

String textoParaCompartirAnuncio(Anuncio anuncio) => // Lo que se comparte: título, mensaje y enlace del botón (si tiene)
    '📢 ${anuncio.titulo}\n\n${anuncio.mensaje}${anuncio.botonUrl != null ? '\n\n${anuncio.botonTexto}: ${anuncio.botonUrl}' : ''}';

class TarjetaAnuncio extends StatelessWidget { // Tarjeta de un anuncio (franja AZUL)
  const TarjetaAnuncio({super.key, required this.anuncio}); // Constructor

  final Anuncio anuncio; // Datos del anuncio

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return TarjetaCanaan( // Tarjeta con franja azul
      franja: azulCanaan, // Azul
      margen: const EdgeInsets.only(top: 10), // Separación
      child: Column( // Elementos uno debajo del otro
        crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
        children: [ // Elementos
          Row( // Ícono y título en fila
            crossAxisAlignment: CrossAxisAlignment.start, // Arriba
            children: [ // Elementos
              Icon(Icons.campaign_outlined, color: context.cc.azul, size: 26), // Megáfono azul
              const SizedBox(width: 10), // Espacio
              Expanded(child: Text(anuncio.titulo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.cc.titulo))), // Título (ocupa el resto)
              IconButton( // Botón compartir
                tooltip: 'Compartir anuncio', // Texto de ayuda
                visualDensity: VisualDensity.compact, // Compacto
                icon: Icon(Icons.share, color: context.cc.azul), // Ícono compartir
                onPressed: () => Compartir.conImagen(textoParaCompartirAnuncio(anuncio), anuncio.imagenUrl), // Comparte el flyer (si tiene) con título, mensaje y enlace
              ), // Fin del botón
            ], // Fin de los elementos
          ), // Fin de la fila
          const SizedBox(height: 6), // Espacio
          Text(anuncio.mensaje, style: TextStyle(fontSize: 16, color: context.cc.texto, height: 1.35)), // Texto del anuncio
          if (anuncio.imagenUrl != null) // Si tiene imagen (flyer)...
            Padding(padding: const EdgeInsets.only(top: 10), child: ImagenRed(url: anuncio.imagenUrl!)), // ...grande, debajo del texto (al tocarla se ve en pantalla completa)
          if (anuncio.botonTexto != null && anuncio.botonUrl != null) // Si tiene botón...
            Padding(padding: const EdgeInsets.only(top: 10), child: BotonEnlace(texto: anuncio.botonTexto!, url: anuncio.botonUrl!)), // ...abre el enlace (formulario, mapa…)
        ], // Fin de los elementos
      ), // Fin de la columna
    ); // Fin de la tarjeta
  } // Fin de build
} // Fin de TarjetaAnuncio
