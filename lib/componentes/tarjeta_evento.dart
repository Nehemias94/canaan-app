import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../modelos/evento.dart'; // Molde de un evento
import '../pantallas/evento.dart'; // Pantalla con el detalle del evento
import '../servicios/compartir.dart'; // Botón Compartir
import 'campanita_evento.dart'; // Botón 🔔 (recordatorio)
import '../tema.dart'; // Colores de Canaán
import 'imagen_y_boton.dart'; // Imagen (flyer)
import 'tarjeta.dart'; // Tarjeta con franja de color

const Color moradoEvento = Color(0xFF6D28D9); // Morado: color de los eventos especiales (distinto de anuncios y cultos)

class TarjetaEvento extends StatelessWidget { // Tarjeta de un evento especial (franja MORADA); al tocarla abre el detalle
  const TarjetaEvento({super.key, required this.evento}); // Constructor

  final Evento evento; // Datos del evento

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return TarjetaCanaan( // Tarjeta con franja morada
      franja: moradoEvento, // Morado
      margen: const EdgeInsets.only(top: 10), // Separación
      alTocar: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PantallaEvento(evento: evento))), // Abre el detalle
      child: Column( // Uno debajo del otro
        crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
        children: [ // Elementos
          if (evento.imagenUrl != null) // Si tiene imagen...
            Padding(padding: const EdgeInsets.only(bottom: 10), child: ImagenRed(url: evento.imagenUrl!, altoMaximo: 220)), // ...arriba, más baja que en el detalle
          Text( // Cuándo
            evento.enCurso ? '● AHORA' : evento.cuandoTexto().toUpperCase(), // "● AHORA" o "SÁBADO, 20 DE NOVIEMBRE · 8:00 AM"
            style: TextStyle(color: evento.enCurso ? Colors.green.shade700 : context.cc.morado, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8), // Pequeño y en color
          ), // Fin del texto
          const SizedBox(height: 4), // Espacio
          Row( // Ícono y nombre
            children: [ // Elementos
              Icon(Icons.celebration_outlined, color: context.cc.morado, size: 24), // Ícono de celebración
              const SizedBox(width: 8), // Espacio
              Expanded(child: Text(evento.titulo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.cc.titulo))), // Nombre
              CampanitaEvento(evento: evento), // 🔔 Recordatorio (avisos que eligió el panel)
              IconButton( // Botón compartir (sin abrir el evento)
                tooltip: 'Compartir evento', // Texto de ayuda (y para lectores de pantalla)
                visualDensity: VisualDensity.compact, // Compacto
                icon: Icon(Icons.share, color: context.cc.morado), // Ícono compartir (morado de los eventos)
                onPressed: () => Compartir.conImagen(evento.textoParaCompartir(), evento.imagenUrl), // Comparte el flyer (si tiene) con los datos
              ), // Fin del botón
            ], // Fin de los elementos
          ), // Fin de la fila
          if (evento.lugar != null && evento.lugar!.isNotEmpty) // Si tiene lugar...
            Padding(padding: const EdgeInsets.only(top: 4), child: Text('📍 ${evento.lugar}', style: TextStyle(fontSize: 15, color: context.cc.suave))), // ...con pin
          if (evento.seTransmite) // Si se transmite...
            Padding(padding: const EdgeInsets.only(top: 4), child: Text('🔴 Se transmite en vivo en la app', style: TextStyle(fontSize: 14, color: Colors.red.shade700, fontWeight: FontWeight.w600))), // ...aviso rojo
        ], // Fin de los elementos
      ), // Fin de la columna
    ); // Fin de la tarjeta
  } // Fin de build
} // Fin de TarjetaEvento
