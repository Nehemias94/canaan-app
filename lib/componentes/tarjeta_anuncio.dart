import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../modelos/anuncio.dart'; // Molde de un anuncio
import '../servicios/compartir.dart'; // Botón Compartir
import '../tema.dart'; // Colores y fechas de Canaán
import 'imagen_y_boton.dart'; // Imagen (flyer) y botón con enlace
import 'tarjeta.dart'; // Tarjeta con franja de color

// Tarjeta COMPLETA de un anuncio (título, texto, flyer, botón y fechas).
// Se usa en el detalle del anuncio y en "Ver todo" (en Inicio va el carrusel de tarjetas pequeñas).

String fechasDeAnuncio(Anuncio anuncio) { // "5 oct 2026" o "5 oct 2026 – 12 oct 2026" (según el rango del panel)
  final inicio = fechaCorta(anuncio.fechaInicio); // Primer día
  final fin = fechaCorta(anuncio.fechaFin); // Último día
  if (inicio.isEmpty) return fin; // Sin inicio: solo el fin (o nada)
  if (fin.isEmpty || fin == inicio) return inicio; // Un solo día
  return '$inicio – $fin'; // Rango
} // Fin de fechasDeAnuncio

class TarjetaAnuncio extends StatelessWidget { // Tarjeta de un anuncio (franja AZUL)
  const TarjetaAnuncio({super.key, required this.anuncio}); // Constructor

  final Anuncio anuncio; // Datos del anuncio

  String _fechas() => fechasDeAnuncio(anuncio); // Texto de las fechas (función compartida con el carrusel)

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    final fechas = _fechas(); // Texto de las fechas
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
                onPressed: () => Compartir.conImagen('📢 ${anuncio.titulo}\n\n${anuncio.mensaje}${anuncio.botonUrl != null ? '\n\n${anuncio.botonTexto}: ${anuncio.botonUrl}' : ''}', anuncio.imagenUrl), // Comparte el flyer (si tiene) con título, mensaje y enlace
              ), // Fin del botón
            ], // Fin de los elementos
          ), // Fin de la fila
          const SizedBox(height: 6), // Espacio
          Text(anuncio.mensaje, style: TextStyle(fontSize: 16, color: context.cc.texto, height: 1.35)), // Texto del anuncio
          if (anuncio.imagenUrl != null) // Si tiene imagen (flyer)...
            Padding(padding: const EdgeInsets.only(top: 10), child: ImagenRed(url: anuncio.imagenUrl!)), // ...grande, debajo del texto (al tocarla se ve en pantalla completa)
          if (anuncio.botonTexto != null && anuncio.botonUrl != null) // Si tiene botón...
            Padding(padding: const EdgeInsets.only(top: 10), child: BotonEnlace(texto: anuncio.botonTexto!, url: anuncio.botonUrl!)), // ...abre el enlace (formulario, mapa…)
          if (fechas.isNotEmpty) // Si hay fechas...
            Padding( // ...las muestra en gris
              padding: const EdgeInsets.only(top: 8), // Separación
              child: Text(fechas, style: TextStyle(color: context.cc.suave, fontSize: 13)), // Gris pequeño
            ), // Fin de las fechas
        ], // Fin de los elementos
      ), // Fin de la columna
    ); // Fin de la tarjeta
  } // Fin de build
} // Fin de TarjetaAnuncio
