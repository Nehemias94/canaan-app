import 'dart:async'; // Timer (actualizar cada 90 s)

import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../componentes/estados.dart'; // Cargando, ErrorConexion, Vacio
import '../componentes/tarjeta_evento.dart'; // Tarjeta de un evento especial
import '../config.dart'; // intervaloActualizacion (90 s)
import '../modelos/evento.dart'; // Molde de un evento
import '../servicios/api.dart'; // Llamadas a la API
import '../servicios/recarga.dart'; // Timbre "recargarEventos" (al tocar la pestaña)
import '../servicios/recordatorios.dart'; // Reprogramar las 🔔 si el panel cambió algo

class PantallaEventos extends StatefulWidget { // Pestaña "Eventos" (menú de abajo): eventos especiales del panel
  const PantallaEventos({super.key, required this.api}); // Constructor

  final Api api; // De dónde se piden los eventos

  @override // Reemplaza createState
  State<PantallaEventos> createState() => _PantallaEventosState(); // Crea el estado
} // Fin de PantallaEventos

class _PantallaEventosState extends State<PantallaEventos> with WidgetsBindingObserver { // Estado; "WidgetsBindingObserver" = se entera cuando la app vuelve a primer plano
  List<Evento>? _eventos; // Eventos recibidos (null = todavía no llegan)
  bool _fallo = false; // true si la PRIMERA carga falló (luego se conserva lo que ya se veía)
  Timer? _reloj; // Reloj que vuelve a preguntar cada 90 s

  @override // Reemplaza initState
  void initState() { // Al abrir la app (la pestaña se crea junto con las demás)
    super.initState(); // Lo de Flutter por defecto
    WidgetsBinding.instance.addObserver(this); // Escucha cuando la app vuelve a primer plano
    recargarEventos.addListener(_cargar); // Al tocar la pestaña Eventos, actualiza
    _reloj = Timer.periodic(intervaloActualizacion, (_) => _cargar()); // Cada 90 s, en silencio
    _cargar(); // Primera carga
  } // Fin de initState

  @override // Reemplaza dispose
  void dispose() { // Al cerrar
    WidgetsBinding.instance.removeObserver(this); // Deja de escuchar la app
    recargarEventos.removeListener(_cargar); // Deja de escuchar el timbre
    _reloj?.cancel(); // Detiene el reloj
    super.dispose(); // Lo de Flutter por defecto
  } // Fin de dispose

  @override // Reemplaza didChangeAppLifecycleState
  void didChangeAppLifecycleState(AppLifecycleState estado) { // La app cambió de estado
    if (estado == AppLifecycleState.resumed) _cargar(); // Volvió a primer plano: actualiza
  } // Fin de didChangeAppLifecycleState

  Future<void> _cargar() async { // Pide los eventos sin mostrar "cargando" (la lista se cambia cuando llegan)
    try { // Intenta
      final eventos = await widget.api.obtenerEventos(); // Petición
      if (mounted) setState(() { _eventos = eventos; _fallo = false; }); // Redibuja con lo nuevo
      await Recordatorios.sincronizarEventos(eventos); // Reprograma las 🔔 (fecha u opciones cambiadas; olvida los borrados)
    } catch (_) { // Sin internet, servidor dormido…
      if (mounted && _eventos == null) setState(() => _fallo = true); // Solo muestra el error si no había nada en pantalla
    } // Fin del try
  } // Fin de _cargar

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    final eventos = _eventos; // Atajo
    return Scaffold( // Estructura de la pantalla
      appBar: AppBar(title: const Text('Eventos especiales')), // Barra de título
      body: eventos == null // ¿Todavía no hay datos?
          ? (_fallo ? ErrorConexion(alReintentar: _cargar) : const Cargando()) // Error o esperando
          : RefreshIndicator( // "Jalar hacia abajo" para actualizar
              onRefresh: _cargar, // Qué hacer al jalar
              child: eventos.isEmpty // ¿Está vacía?
                  ? const Vacio(icono: Icons.celebration_outlined, mensaje: 'Por ahora no hay eventos especiales.\nPronto anunciaremos nuevos.') // Sí: mensaje amable
                  : ListView( // No: una tarjeta por evento
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24), // Márgenes
                      children: [for (final evento in eventos) TarjetaEvento(key: ValueKey('evento-${evento.id}'), evento: evento)], // Tarjetas (al tocar, abren el detalle)
                    ), // Fin de la lista
            ), // Fin de RefreshIndicator
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de _PantallaEventosState
