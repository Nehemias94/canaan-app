import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../componentes/contar_vista.dart'; // Avisa al panel que se abrió (vistas anónimas)
import '../componentes/imagen_y_boton.dart'; // Flyer grande y botón con enlace
import '../componentes/tarjeta_anuncio.dart'; // Tarjeta completa (lista "Ver todo") y texto para compartir
import '../modelos/anuncio.dart'; // Molde de un anuncio
import '../servicios/compartir.dart'; // Botón Compartir
import '../tema.dart'; // Colores de Canaán

class PantallaAnuncio extends StatelessWidget { // Detalle de un anuncio (se abre al tocarlo en el carrusel de Inicio)
  const PantallaAnuncio({super.key, required this.anuncio}); // Constructor

  final Anuncio anuncio; // Datos del anuncio

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    final hayBoton = anuncio.botonTexto != null && anuncio.botonUrl != null; // ¿Tiene botón con enlace?
    return ContarVista(tipo: 'anuncios', id: anuncio.id, child: Scaffold( // Al abrirlo, avisa al panel (vistas anónimas); estructura
      appBar: AppBar(title: const Text('Anuncio')), // Barra con flecha para volver
      body: ListView( // Desplazable (por si el texto o el flyer son largos)
        padding: const EdgeInsets.all(16), // Márgenes
        children: [ // Elementos (mismo orden que el detalle de un evento)
          if (anuncio.imagenUrl != null) ...[ // Si tiene flyer...
            ImagenRed(url: anuncio.imagenUrl!, altoMaximo: 480), // ...grande arriba (al tocarlo, en pantalla completa)
            const SizedBox(height: 16), // Espacio
          ], // Fin del flyer
          Row( // Etiqueta "ANUNCIO"
            children: [ // Elementos
              Icon(Icons.campaign_outlined, color: context.vivo(azulCanaan), size: 22), // Megáfono
              const SizedBox(width: 6), // Espacio
              Text('ANUNCIO', style: TextStyle(color: context.vivo(azulCanaan), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)), // Etiqueta
            ], // Fin de los elementos
          ), // Fin de la etiqueta
          const SizedBox(height: 6), // Espacio
          Text(anuncio.titulo, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.cc.titulo, height: 1.2)), // Título grande
          const SizedBox(height: 12), // Espacio
          SelectableText(anuncio.mensaje, style: TextStyle(fontSize: 17, color: context.cc.texto, height: 1.45)), // Mensaje (se puede seleccionar y copiar)
          const SizedBox(height: 20), // Espacio
          if (hayBoton) ...[ // Si tiene botón...
            BotonEnlace(texto: anuncio.botonTexto!, url: anuncio.botonUrl!), // ...a todo el ancho (formulario, mapa, WhatsApp…)
            const SizedBox(height: 10), // Espacio
          ], // Fin del botón
          OutlinedButton.icon( // Compartir
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: context.cc.titulo), // Todo el ancho
            icon: const Icon(Icons.share), // Ícono
            label: const Text('Compartir', style: TextStyle(fontSize: 16)), // Texto
            onPressed: () => Compartir.conImagen(textoParaCompartirAnuncio(anuncio), anuncio.imagenUrl), // Comparte el flyer (si tiene) con título, mensaje y enlace
          ), // Fin del botón
        ], // Fin de los elementos
      ), // Fin de la lista
    )); // Fin del Scaffold y de ContarVista
  } // Fin de build
} // Fin de PantallaAnuncio

class PantallaListaAnuncios extends StatelessWidget { // "Ver todo" de ANUNCIOS en Inicio: todos los anuncios con su tarjeta completa
  const PantallaListaAnuncios({super.key, required this.anuncios}); // Constructor

  final List<Anuncio> anuncios; // Anuncios vigentes

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Scaffold( // Estructura
      appBar: AppBar(title: const Text('Anuncios')), // Barra con flecha para volver
      body: ListView( // Desplazable
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24), // Márgenes
        children: [for (final anuncio in anuncios) TarjetaAnuncio(anuncio: anuncio)], // Cada anuncio completo
      ), // Fin de la lista
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de PantallaListaAnuncios
