import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../componentes/estados.dart'; // Cargando, ErrorConexion, Vacio
import '../componentes/tarjeta_evento.dart'; // Tarjeta de un evento especial
import '../modelos/evento.dart'; // Molde de un evento
import '../servicios/api.dart'; // Llamadas a la API

class PantallaEventos extends StatefulWidget { // Pestaña "Eventos" (menú de abajo): eventos especiales del panel
  const PantallaEventos({super.key, required this.api}); // Constructor

  final Api api; // De dónde se piden los eventos

  @override // Reemplaza createState
  State<PantallaEventos> createState() => _PantallaEventosState(); // Crea el estado
} // Fin de PantallaEventos

class _PantallaEventosState extends State<PantallaEventos> { // Estado de la pestaña Eventos
  late Future<List<Evento>> _peticion; // Petición en curso

  @override // Reemplaza initState
  void initState() { // Al abrir la pestaña por primera vez
    super.initState(); // Lo de Flutter por defecto
    _peticion = widget.api.obtenerEventos(); // Pide los eventos
  } // Fin de initState

  Future<void> _recargar() async { // Vuelve a pedir los eventos ("jalar hacia abajo" o Reintentar)
    setState(() => _peticion = widget.api.obtenerEventos()); // Nueva petición y redibuja
    try { await _peticion; } catch (_) {} // Espera a que termine
  } // Fin de _recargar

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Scaffold( // Estructura de la pantalla
      appBar: AppBar(title: const Text('Eventos especiales')), // Barra de título
      body: FutureBuilder<List<Evento>>( // Dibuja según el estado de la petición
        future: _peticion, // Petición que vigila
        builder: (context, estado) { // Se llama cada vez que cambia
          if (estado.connectionState != ConnectionState.done) return const Cargando(); // Esperando
          if (estado.hasError) return ErrorConexion(alReintentar: _recargar); // Falló
          final eventos = estado.data!; // Lista recibida (del más cercano al más lejano)
          return RefreshIndicator( // "Jalar hacia abajo" para actualizar
            onRefresh: _recargar, // Qué hacer al jalar
            child: eventos.isEmpty // ¿Está vacía?
                ? const Vacio(icono: Icons.celebration_outlined, mensaje: 'Por ahora no hay eventos especiales.\nPronto anunciaremos nuevos.') // Sí: mensaje amable
                : ListView( // No: una tarjeta por evento
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24), // Márgenes
                    children: [for (final evento in eventos) TarjetaEvento(evento: evento)], // Tarjetas (al tocar, abren el detalle)
                  ), // Fin de la lista
          ); // Fin de RefreshIndicator
        }, // Fin de builder
      ), // Fin de FutureBuilder
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de _PantallaEventosState
