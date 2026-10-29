import 'package:flutter/material.dart'; // Componentes visuales de Flutter
import 'package:url_launcher/url_launcher.dart'; // Abrir el PDF fuera de la app

import '../servicios/compartir.dart'; // Compartir el bosquejo
import '../tema.dart'; // Colores

class PantallaBosquejo extends StatefulWidget { // Bosquejo de la prédica (puntos y versículos) con letra grande, para seguirlo durante el culto
  const PantallaBosquejo({super.key, required this.titulo, this.texto, this.pdfUrl}); // Constructor

  final String titulo; // Título de la prédica
  final String? texto; // Bosquejo en texto (puede ser null)
  final String? pdfUrl; // Bosquejo en PDF (puede ser null)

  @override // Reemplaza createState
  State<PantallaBosquejo> createState() => _PantallaBosquejoState(); // Crea el estado
} // Fin de PantallaBosquejo

class _PantallaBosquejoState extends State<PantallaBosquejo> { // Estado: tamaño de la letra
  double _tamano = 19; // Tamaño de la letra (A− / A+)

  Future<void> _abrirPdf() async { // Abre el PDF (en el visor del teléfono o el navegador)
    final mensajero = ScaffoldMessenger.of(context); // Para avisar si falla
    final abrio = await launchUrl(Uri.parse(widget.pdfUrl!), mode: LaunchMode.externalApplication).catchError((_) => false); // Abre
    if (!abrio) mensajero.showSnackBar(const SnackBar(content: Text('No se pudo abrir el PDF. Revisa tu conexión a internet.'))); // Aviso
  } // Fin de _abrirPdf

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Scaffold( // Estructura
      appBar: AppBar( // Barra con flecha para volver
        title: const Text('Bosquejo'), // Título
        actions: [ // Botones
          IconButton(tooltip: 'Letra más chica', onPressed: _tamano > 15 ? () => setState(() => _tamano -= 2) : null, icon: const Icon(Icons.text_decrease)), // A−
          IconButton(tooltip: 'Letra más grande', onPressed: _tamano < 31 ? () => setState(() => _tamano += 2) : null, icon: const Icon(Icons.text_increase)), // A+
          if (widget.texto != null) IconButton(tooltip: 'Compartir bosquejo', onPressed: () => Compartir.texto('📝 ${widget.titulo}\n\n${widget.texto}'), icon: const Icon(Icons.share)), // Compartir
        ], // Fin de los botones
      ), // Fin de la barra
      body: ListView( // Desplazable
        padding: const EdgeInsets.all(20), // Márgenes
        children: [ // Elementos
          Text(widget.titulo, style: TextStyle(fontSize: _tamano + 4, fontWeight: FontWeight.bold, color: context.cc.titulo)), // Título
          const SizedBox(height: 16), // Espacio
          if (widget.texto != null) SelectableText(widget.texto!, style: TextStyle(fontSize: _tamano, height: 1.6, color: context.cc.texto)), // Puntos (se puede seleccionar y copiar)
          if (widget.pdfUrl != null) // Si hay PDF...
            Padding( // ...botón para abrirlo
              padding: const EdgeInsets.only(top: 20), // Separación
              child: FilledButton.icon( // Botón grande
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), // Todo el ancho
                onPressed: _abrirPdf, // Abre el PDF
                icon: const Icon(Icons.picture_as_pdf), // Ícono de PDF
                label: const Text('Abrir el bosquejo en PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), // Texto
              ), // Fin del botón
            ), // Fin del margen
        ], // Fin de los elementos
      ), // Fin de la lista
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de _PantallaBosquejoState
