import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../tema.dart'; // Colores de Canaán

class Cargando extends StatelessWidget { // Vista "Conectando…" mientras llegan los datos
  const Cargando({super.key, this.claro = false}); // Constructor; claro = true para fondos oscuros (letras blancas)

  final bool claro; // ¿Se dibuja sobre fondo oscuro?

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    final colorTexto = claro ? Colors.white : context.cc.texto; // Letras blancas sobre fondo oscuro, negras sobre fondo claro
    return Center( // Centrado
      child: Padding( // Margen
        padding: const EdgeInsets.all(24), // 24 puntos por lado
        child: Column( // Elementos uno debajo del otro
          mainAxisSize: MainAxisSize.min, // Ocupa solo lo necesario
          children: [ // Elementos
            CircularProgressIndicator(color: claro ? doradoCanaan : azulCanaan), // Rueda girando
            const SizedBox(height: 16), // Espacio
            Text('Conectando…', style: TextStyle(color: colorTexto, fontSize: 18)), // Mensaje corto (el panel ya no "duerme": cron-job.org lo visita cada minuto)
          ], // Fin de los elementos
        ), // Fin de la columna
      ), // Fin del margen
    ); // Fin del centrado
  } // Fin de build
} // Fin de Cargando

class ErrorConexion extends StatelessWidget { // Vista cuando no se pudo conectar
  const ErrorConexion({super.key, required this.alReintentar, this.claro = false}); // Constructor

  final VoidCallback alReintentar; // Qué hacer al pulsar "Reintentar"
  final bool claro; // ¿Se dibuja sobre fondo oscuro?

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    final colorTexto = claro ? Colors.white : context.cc.texto; // Color de las letras según el fondo
    return Center( // Centrado
      child: Padding( // Margen
        padding: const EdgeInsets.all(24), // 24 puntos por lado
        child: Column( // Elementos uno debajo del otro
          mainAxisSize: MainAxisSize.min, // Ocupa solo lo necesario
          children: [ // Elementos
            Icon(Icons.wifi_off, size: 64, color: colorTexto.withValues(alpha: 0.7)), // Ícono "sin conexión"
            const SizedBox(height: 16), // Espacio
            Text( // Mensaje
              'No pudimos conectar con la iglesia.\nRevisa tu internet e intenta de nuevo.', // Texto en dos líneas
              textAlign: TextAlign.center, // Centrado
              style: TextStyle(color: colorTexto, fontSize: 16), // Color según el fondo
            ), // Fin del mensaje
            const SizedBox(height: 20), // Espacio
            FilledButton.icon( // Botón relleno con ícono
              onPressed: alReintentar, // Al pulsarlo, vuelve a intentar
              style: FilledButton.styleFrom(backgroundColor: doradoCanaan, foregroundColor: marinoCanaan), // Dorado con letras marino
              icon: const Icon(Icons.refresh), // Ícono de recargar
              label: const Text('Reintentar'), // Texto
            ), // Fin del botón
          ], // Fin de los elementos
        ), // Fin de la columna
      ), // Fin del margen
    ); // Fin del centrado
  } // Fin de build
} // Fin de ErrorConexion

class Vacio extends StatelessWidget { // Vista cuando la lista no tiene nada (ej: aún no hay prédicas)
  const Vacio({super.key, required this.icono, required this.mensaje}); // Constructor

  final IconData icono; // Ícono grande
  final String mensaje; // Texto explicativo

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return ListView( // Lista (y no Column) para que "jalar hacia abajo para actualizar" funcione aunque esté vacía
      padding: const EdgeInsets.all(32), // Margen
      children: [ // Elementos
        const SizedBox(height: 60), // Espacio arriba
        Icon(icono, size: 64, color: Colors.black26), // Ícono gris claro
        const SizedBox(height: 12), // Espacio
        Text(mensaje, textAlign: TextAlign.center, style: TextStyle(color: context.cc.suave, fontSize: 16)), // Mensaje gris
      ], // Fin de los elementos
    ); // Fin de la lista
  } // Fin de build
} // Fin de Vacio
