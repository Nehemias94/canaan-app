import 'package:flutter/material.dart'; // Componentes visuales de Flutter
import 'package:url_launcher/url_launcher.dart'; // Abrir WhatsApp

import '../componentes/estados.dart'; // Cargando, ErrorConexion, Vacio
import '../componentes/imagen_y_boton.dart'; // Foto del grupo
import '../servicios/api.dart'; // Llamadas a la API
import '../tema.dart'; // Colores

class Ministerio { // Un ministerio del directorio (GET /api/ministerios)
  const Ministerio({required this.id, required this.nombre, this.descripcion, this.lider, this.horario, this.whatsapp, this.imagenUrl}); // Constructor

  final int id; // Número
  final String nombre; // Nombre
  final String? descripcion; // Qué hacen
  final String? lider; // Líder
  final String? horario; // Cuándo se reúnen
  final String? whatsapp; // Número para wa.me (solo dígitos)
  final String? imagenUrl; // Foto

  factory Ministerio.desdeJson(Map<String, dynamic> json) => Ministerio( // Desde el JSON
        id: json['id'] as int, nombre: json['nombre'] as String? ?? '', descripcion: json['descripcion'] as String?, // Datos
        lider: json['lider'] as String?, horario: json['horario'] as String?, whatsapp: json['whatsapp'] as String?, imagenUrl: json['imagen_url'] as String?, // Datos
      ); // Fin
} // Fin de Ministerio

class PantallaMinisterios extends StatefulWidget { // Directorio de ministerios (se abre desde Servicios)
  const PantallaMinisterios({super.key, required this.api}); // Constructor

  final Api api; // De dónde se piden

  @override // Reemplaza createState
  State<PantallaMinisterios> createState() => _PantallaMinisteriosState(); // Crea el estado
} // Fin de PantallaMinisterios

class _PantallaMinisteriosState extends State<PantallaMinisterios> { // Estado
  late Future<List<Ministerio>> _peticion = widget.api.obtenerMinisterios(); // Pide la lista al abrir

  Future<void> _recargar() async { // Vuelve a pedir la lista
    setState(() => _peticion = widget.api.obtenerMinisterios()); // Nueva petición
    try { await _peticion; } catch (_) {} // Espera
  } // Fin de _recargar

  Future<void> _escribir(Ministerio m) async { // Abre WhatsApp con un mensaje listo
    final mensajero = ScaffoldMessenger.of(context); // Para avisar si falla
    final texto = Uri.encodeComponent('Hola${m.lider != null ? ' ${m.lider}' : ''}, me interesa el ${m.nombre.toLowerCase().startsWith('ministerio') ? m.nombre : 'ministerio ${m.nombre}'}. ¿Me das más información?'); // Mensaje
    final abrio = await launchUrl(Uri.parse('https://wa.me/${m.whatsapp}?text=$texto'), mode: LaunchMode.externalApplication).catchError((_) => false); // Abre WhatsApp
    if (!abrio) mensajero.showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp.'))); // Aviso
  } // Fin de _escribir

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Scaffold( // Estructura
      appBar: AppBar(title: const Text('Ministerios')), // Barra con flecha para volver
      body: FutureBuilder<List<Ministerio>>( // Dibuja según la petición
        future: _peticion, // Petición
        builder: (context, estado) { // Según el estado
          if (estado.connectionState != ConnectionState.done) return const Cargando(); // Esperando
          if (estado.hasError) return ErrorConexion(alReintentar: _recargar); // Falló
          final lista = estado.data!; // Ministerios
          if (lista.isEmpty) return const Vacio(icono: Icons.groups_outlined, mensaje: 'Pronto publicaremos los ministerios de la iglesia.'); // Vacío
          return RefreshIndicator( // Jalar para actualizar
            onRefresh: _recargar, // Qué hacer
            child: ListView( // Lista
              padding: const EdgeInsets.all(16), // Márgenes
              children: [ // Tarjetas
                for (final m in lista) // Cada ministerio
                  Card( // Tarjeta
                    margin: const EdgeInsets.only(bottom: 12), // Separación
                    clipBehavior: Clip.antiAlias, // Recorta la foto
                    child: Padding( // Relleno
                      padding: const EdgeInsets.all(14), // 14 por lado
                      child: Column( // Uno debajo del otro
                        crossAxisAlignment: CrossAxisAlignment.stretch, // Todo el ancho
                        children: [ // Elementos
                          if (m.imagenUrl != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: ImagenRed(url: m.imagenUrl!, altoMaximo: 200)), // Foto
                          Row(children: [Icon(Icons.groups, color: context.cc.azul, size: 26), const SizedBox(width: 8), Expanded(child: Text(m.nombre, style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: context.cc.titulo)))]), // Nombre
                          if (m.horario != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('🕒 ${m.horario}', style: TextStyle(fontSize: 15, color: context.cc.texto))), // Horario
                          if (m.lider != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text('👤 Líder: ${m.lider}', style: TextStyle(fontSize: 15, color: context.cc.texto))), // Líder
                          if (m.descripcion != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(m.descripcion!, style: TextStyle(fontSize: 15, height: 1.4, color: context.cc.suave))), // Descripción
                          if (m.whatsapp != null) // Si tiene WhatsApp...
                            Padding( // ...botón verde
                              padding: const EdgeInsets.only(top: 12), // Separación
                              child: FilledButton.icon( // Botón
                                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1FA855), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)), // Verde WhatsApp
                                onPressed: () => _escribir(m), // Abre WhatsApp
                                icon: const Icon(Icons.chat), // Ícono
                                label: const Text('Escribir por WhatsApp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), // Texto
                              ), // Fin del botón
                            ), // Fin del margen
                        ], // Fin de los elementos
                      ), // Fin de la columna
                    ), // Fin del relleno
                  ), // Fin de la tarjeta
              ], // Fin de las tarjetas
            ), // Fin de la lista
          ); // Fin de RefreshIndicator
        }, // Fin de builder
      ), // Fin de FutureBuilder
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de _PantallaMinisteriosState
