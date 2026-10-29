import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../tema.dart'; // Colores de Canaán

// Tarjeta blanca con una FRANJA de color a la izquierda según el tipo (diseño común de la app):
// rojo = urgente / en vivo, dorado = radio / importante, azul = anuncio / informativo.
class TarjetaCanaan extends StatelessWidget { // Tarjeta con franja de color
  const TarjetaCanaan({super.key, required this.franja, required this.child, this.alTocar, this.margen = const EdgeInsets.only(top: 12)}); // Constructor

  final Color franja; // Color de la franja de la izquierda
  final Widget child; // Contenido de la tarjeta
  final VoidCallback? alTocar; // Qué hacer al tocarla (null = no se puede tocar)
  final EdgeInsets margen; // Separación por fuera

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Padding( // Separación por fuera
      padding: margen, // Margen indicado
      child: Material( // Fondo blanco con esquinas redondeadas (permite el efecto al tocar)
        color: context.cc.tarjeta, // Blanca
        borderRadius: BorderRadius.circular(16), // Esquinas redondeadas
        elevation: 1.5, // Sombra muy suave
        shadowColor: marinoCanaan.withValues(alpha: 0.25), // Sombra azulada (como el panel)
        clipBehavior: Clip.antiAlias, // Recorta la franja a las esquinas redondeadas
        child: InkWell( // Efecto al tocar
          onTap: alTocar, // Qué hacer al tocar
          child: Container( // Caja con la franja
            decoration: BoxDecoration(border: Border(left: BorderSide(color: franja, width: 6))), // Franja de 6 px a la izquierda
            padding: const EdgeInsets.fromLTRB(14, 14, 16, 14), // Margen interno
            child: child, // Contenido
          ), // Fin de la caja
        ), // Fin del efecto
      ), // Fin del fondo
    ); // Fin de la separación
  } // Fin de build
} // Fin de TarjetaCanaan

Color colorDeNivel(String? nivel) { // Color de la franja del aviso urgente según su nivel (igual que el panel)
  switch (nivel) { // Según el nivel...
    case 'urgente': return Colors.red.shade700; // Rojo
    case 'importante': return doradoCanaan; // Dorado (ámbar)
    default: return azulCanaan; // Informativo: azul
  } // Fin del switch
} // Fin de colorDeNivel
