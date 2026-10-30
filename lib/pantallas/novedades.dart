import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../componentes/tarjeta_anuncio.dart'; // Tarjeta completa del anuncio
import '../componentes/tarjeta_evento.dart'; // Tarjeta del evento especial
import '../modelos/anuncio.dart'; // Molde de un anuncio
import '../modelos/evento.dart'; // Molde de un evento
import '../tema.dart'; // Colores de Canaán

class PantallaNovedades extends StatelessWidget { // "Ver todo" del carrusel: anuncios y eventos con sus tarjetas completas
  const PantallaNovedades({super.key, required this.anuncios, required this.eventos}); // Constructor

  final List<Anuncio> anuncios; // Anuncios vigentes
  final List<Evento> eventos; // Próximos eventos

  Widget _titulo(String texto, Color color) => Padding( // Encabezado de cada sección
        padding: const EdgeInsets.only(top: 20, left: 4), // Separación
        child: Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 1.5)), // Mayúsculas en color
      ); // Fin del encabezado

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Scaffold( // Estructura
      appBar: AppBar(title: const Text('Novedades')), // Barra con flecha para volver
      body: ListView( // Desplazable
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), // Márgenes
        children: [ // Elementos
          if (anuncios.isNotEmpty) _titulo('ANUNCIOS', context.cc.dorado), // Sección de anuncios
          for (final anuncio in anuncios) TarjetaAnuncio(anuncio: anuncio), // Cada anuncio completo
          if (eventos.isNotEmpty) _titulo('PRÓXIMOS EVENTOS', context.cc.morado), // Sección de eventos
          for (final evento in eventos) TarjetaEvento(evento: evento), // Cada evento (al tocarlo, su detalle)
        ], // Fin de los elementos
      ), // Fin de la lista
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de PantallaNovedades
