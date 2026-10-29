import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../componentes/campanita_evento.dart'; // Activar/quitar el recordatorio
import '../componentes/imagen_y_boton.dart'; // Imagen (flyer) y botón con enlace
import '../modelos/evento.dart'; // Molde de un evento
import '../servicios/compartir.dart'; // Compartir
import '../servicios/preferencias.dart'; // Eventos con recordatorio
import '../tema.dart'; // Colores de Canaán

class PantallaEvento extends StatelessWidget { // Detalle de un evento especial
  const PantallaEvento({super.key, required this.evento}); // Constructor

  final Evento evento; // Datos del evento

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    final hayBoton = evento.botonTexto != null && evento.botonUrl != null; // ¿Tiene botón?
    return Scaffold( // Estructura
      appBar: AppBar(title: const Text('Evento especial')), // Barra con flecha para volver
      body: ListView( // Desplazable
        padding: const EdgeInsets.all(16), // Márgenes
        children: [ // Elementos
          if (evento.imagenUrl != null) ImagenRed(url: evento.imagenUrl!, altoMaximo: 480), // Flyer grande (al tocarlo, en pantalla completa)
          const SizedBox(height: 14), // Espacio
          Text(evento.titulo, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.cc.titulo)), // Nombre
          const SizedBox(height: 10), // Espacio
          _Dato(icono: Icons.event, texto: evento.enCurso ? 'Ahora · ${evento.cuandoTexto()}' : evento.cuandoTexto()), // Cuándo
          if (evento.lugar != null && evento.lugar!.isNotEmpty) _Dato(icono: Icons.place_outlined, texto: evento.lugar!), // Dónde
          if (evento.seTransmite) _Dato(icono: Icons.live_tv, texto: 'Se transmite en vivo en la app', color: Colors.red.shade700), // En vivo
          if (evento.descripcion != null && evento.descripcion!.isNotEmpty) // Si tiene detalle...
            Padding(padding: const EdgeInsets.only(top: 14), child: Text(evento.descripcion!, style: const TextStyle(fontSize: 17, height: 1.4))), // ...texto
          const SizedBox(height: 20), // Espacio
          if (hayBoton) BotonEnlace(texto: evento.botonTexto!, url: evento.botonUrl!, color: context.cc.morado), // Botón del panel (ej: Inscríbete)
          const SizedBox(height: 10), // Espacio
          ValueListenableBuilder<Set<int>>( // Se redibuja cuando cambian los recordatorios
            valueListenable: Preferencias.recordatoriosEventos, // Eventos con recordatorio
            builder: (context, ids, _) { // Botón según el estado
              final activo = ids.contains(evento.id); // ¿Ya tiene recordatorio?
              return OutlinedButton.icon( // Botón con borde
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: activo ? context.cc.dorado : context.cc.titulo), // Todo el ancho
                icon: Icon(activo ? Icons.notifications_active : Icons.notifications_none), // Campana
                label: Text(activo ? 'Recordatorio activado (toca para quitar)' : 'Recordarme', style: const TextStyle(fontSize: 16)), // Texto
                onPressed: () => alternarRecordatorioEvento(context, evento), // Activa o quita (igual que la 🔔 de la tarjeta)
              ); // Fin del botón
            }, // Fin de builder
          ), // Fin de ValueListenableBuilder
          const SizedBox(height: 10), // Espacio
          OutlinedButton.icon( // Compartir
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: context.cc.titulo), // Todo el ancho
            icon: const Icon(Icons.share), // Ícono
            label: const Text('Compartir', style: TextStyle(fontSize: 16)), // Texto
            onPressed: () => Compartir.conImagen(evento.textoParaCompartir(), evento.imagenUrl), // Comparte el flyer (si tiene) con nombre, fecha, lugar y enlace
          ), // Fin del botón
        ], // Fin de los elementos
      ), // Fin de la lista
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de PantallaEvento

class _Dato extends StatelessWidget { // Renglón con ícono y texto (cuándo, dónde…)
  const _Dato({required this.icono, required this.texto, this.color}); // Constructor

  final IconData icono; // Ícono
  final String texto; // Texto
  final Color? color; // Color (null = el normal del modo)

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Padding( // Separación
      padding: const EdgeInsets.only(top: 6), // Arriba
      child: Row( // Ícono y texto
        crossAxisAlignment: CrossAxisAlignment.start, // Arriba
        children: [ // Elementos
          Icon(icono, color: color ?? context.cc.morado, size: 22), // Ícono (morado por defecto)
          const SizedBox(width: 10), // Espacio
          Expanded(child: Text(texto, style: TextStyle(fontSize: 17, color: color ?? context.cc.texto))), // Texto
        ], // Fin de los elementos
      ), // Fin de la fila
    ); // Fin del margen
  } // Fin de build
} // Fin de _Dato
