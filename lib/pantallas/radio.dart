import 'dart:async'; // StreamSubscription (escuchar los cambios del reproductor)

import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../componentes/estados.dart'; // Vistas compartidas: Cargando, ErrorConexion
import '../modelos/iglesia.dart'; // Molde de los datos de la iglesia (bloque radio)
import '../servicios/api.dart'; // Llamadas a la API (para saber si la radio está al aire)
import '../servicios/radio.dart'; // Control de la radio (reproducir / detener)
import '../tema.dart'; // Colores de Canaán

class PantallaRadio extends StatefulWidget { // Pantalla "Radio en línea" (se abre desde Más o desde la etiqueta de Inicio)
  const PantallaRadio({super.key, required this.api}); // Constructor: recibe la API

  final Api api; // Para consultar si la radio está al aire y su enlace

  @override // Reemplaza createState
  State<PantallaRadio> createState() => _PantallaRadioState(); // Crea el estado
} // Fin de PantallaRadio

class _PantallaRadioState extends State<PantallaRadio> { // Estado de la pantalla de la radio
  late Future<Iglesia> _peticion; // Consulta al panel (¿está al aire?, ¿cuál es el enlace?)
  final ControlRadio _control = ControlRadio.crear(); // Reproductor (el real en la app; uno de mentira en las pruebas)
  StreamSubscription<EstadoRadio>? _escucha; // Escucha los cambios del reproductor
  EstadoRadio _estado = EstadoRadio.detenida; // Estado actual (para dibujar el botón)
  String? _error; // Mensaje si no se pudo reproducir

  @override // Reemplaza initState
  void initState() { // Al abrir la pantalla
    super.initState(); // Lo de Flutter por defecto
    _peticion = widget.api.obtenerIglesia(); // Pregunta al panel por la radio
    _escucha = _control.estados.listen((estado) { // Cada vez que cambia el reproductor...
      if (mounted) setState(() => _estado = estado); // ...redibuja con el estado nuevo
    }); // Fin de la escucha
  } // Fin de initState

  @override // Reemplaza dispose
  void dispose() { // Al salir de la pantalla
    _escucha?.cancel(); // Deja de escuchar
    _control.cerrar(); // Apaga y libera el reproductor al SALIR de esta pantalla (con el teléfono bloqueado la pantalla sigue abierta: la radio sigue sonando)
    super.dispose(); // Lo de Flutter por defecto
  } // Fin de dispose

  Future<void> _recargar() async { // Vuelve a preguntar al panel
    setState(() => _peticion = widget.api.obtenerIglesia()); // Nueva consulta y redibuja
    try { await _peticion; } catch (_) {} // Espera (el error lo muestra el FutureBuilder)
  } // Fin de _recargar

  Future<void> _alternar(RadioIglesia radio) async { // Botón grande: si suena, detiene; si no, reproduce
    setState(() => _error = null); // Borra errores anteriores
    if (_estado != EstadoRadio.detenida) return _control.detener(); // Sonando o cargando: detener
    try { // Detenida: intentar reproducir
      await _control.reproducir(radio.streamUrl!, titulo: radio.titulo ?? 'Radio Canaán'); // Conecta y suena (el título sale en la pantalla de bloqueo)
    } catch (_) { // No se pudo (enlace caído, sin internet, la cabina no está transmitiendo…)
      if (mounted) setState(() => _error = 'No pudimos conectar con la radio. Puede que la señal se haya cortado; intenta de nuevo en un momento.'); // Mensaje
    } // Fin del try
  } // Fin de _alternar

  String _horario(RadioIglesia radio) { // Texto bajo el título: "Las 24 horas" o "Al aire hasta las 1:00 pm"
    if (radio.modo == 'siempre') return 'Al aire las 24 horas'; // Modo 24/7
    final hasta = radio.hasta; // Hora de apagado
    if (hasta == null) return 'Al aire ahora'; // Sin hora: genérico
    final hora = hasta.hour % 12 == 0 ? 12 : hasta.hour % 12; // Hora en formato de 12 (0 y 12 → 12)
    final minutos = hasta.minute.toString().padLeft(2, '0'); // Minutos con dos cifras (5 → "05")
    return 'Al aire hasta las $hora:$minutos ${hasta.hour < 12 ? 'am' : 'pm'}'; // Ej: "Al aire hasta las 1:00 pm"
  } // Fin de _horario

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Scaffold( // Estructura de la pantalla
      appBar: AppBar(title: const Text('Radio en línea')), // Barra con flecha para volver
      body: Container( // Fondo
        decoration: const BoxDecoration( // Degradado marino → azul (como Inicio)
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [marinoCanaan, azulCanaan]), // Colores
        ), // Fin del fondo
        child: FutureBuilder<Iglesia>( // Dibuja según la consulta al panel
          future: _peticion, // Consulta que vigila
          builder: (context, consulta) { // Se llama cada vez que cambia
            if (consulta.connectionState != ConnectionState.done) return const Cargando(claro: true); // Esperando
            if (consulta.hasError) return ErrorConexion(alReintentar: _recargar, claro: true); // Falló
            final radio = consulta.data!.radio; // Datos de la radio
            if (!radio.disponible || radio.streamUrl == null) return _fueraDelAire(); // No está al aire
            return _reproductor(radio); // Al aire: muestra el reproductor
          }, // Fin de builder
        ), // Fin de FutureBuilder
      ), // Fin del fondo
    ); // Fin del Scaffold
  } // Fin de build

  Widget _fueraDelAire() { // Vista cuando la radio no está al aire
    return Center( // Centrado
      child: Padding( // Margen
        padding: const EdgeInsets.all(32), // 32 por lado
        child: Column( // Elementos uno debajo del otro
          mainAxisSize: MainAxisSize.min, // Ocupa solo lo necesario
          children: [ // Elementos
            const Icon(Icons.radio, size: 72, color: Colors.white38), // Radio gris
            const SizedBox(height: 16), // Espacio
            const Text( // Mensaje
              'La radio no está al aire en este momento.\nVuelve durante los cultos.', // Texto en dos líneas
              textAlign: TextAlign.center, // Centrado
              style: TextStyle(color: Colors.white, fontSize: 16), // Blanco
            ), // Fin del mensaje
            const SizedBox(height: 20), // Espacio
            OutlinedButton.icon( // Botón de contorno
              onPressed: _recargar, // Vuelve a preguntar
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)), // Blanco
              icon: const Icon(Icons.refresh), // Ícono de recargar
              label: const Text('Revisar de nuevo'), // Texto
            ), // Fin del botón
          ], // Fin de los elementos
        ), // Fin de la columna
      ), // Fin del margen
    ); // Fin del centrado
  } // Fin de _fueraDelAire

  Widget _reproductor(RadioIglesia radio) { // Vista con el botón grande de reproducir
    final sonando = _estado == EstadoRadio.sonando; // ¿Está sonando?
    final cargando = _estado == EstadoRadio.cargando; // ¿Está conectando?
    return Center( // Centrado
      child: Padding( // Margen
        padding: const EdgeInsets.all(32), // 32 por lado
        child: Column( // Elementos uno debajo del otro
          mainAxisSize: MainAxisSize.min, // Ocupa solo lo necesario
          children: [ // Elementos
            Image.asset('assets/imagenes/canaan-icono.png', height: 96), // Ícono dorado de Canaán
            const SizedBox(height: 20), // Espacio
            Text( // Título de la radio
              radio.titulo ?? 'Radio Canaán', // Título (o uno genérico)
              textAlign: TextAlign.center, // Centrado
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), // Blanco, grande, negrita
            ), // Fin del título
            const SizedBox(height: 6), // Espacio
            Text(_horario(radio), style: const TextStyle(color: Colors.white70)), // "Al aire hasta las…"
            const SizedBox(height: 36), // Espacio
            SizedBox( // Botón redondo grande
              width: 96, // Ancho
              height: 96, // Alto
              child: FilledButton( // Botón relleno
                onPressed: () => _alternar(radio), // Al tocar: reproducir o detener
                style: FilledButton.styleFrom( // Apariencia
                  backgroundColor: doradoCanaan, // Dorado
                  foregroundColor: marinoCanaan, // Ícono marino
                  shape: const CircleBorder(), // Redondo
                  padding: EdgeInsets.zero, // Sin relleno extra
                ), // Fin de la apariencia
                child: cargando // ¿Conectando?
                    ? const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(color: marinoCanaan, strokeWidth: 3)) // Sí: rueda
                    : Icon(sonando ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 56, semanticLabel: sonando ? 'Detener' : 'Escuchar'), // No: detener o reproducir
              ), // Fin del botón
            ), // Fin del tamaño
            const SizedBox(height: 16), // Espacio
            Text( // Estado en palabras
              cargando ? 'Conectando…' : (sonando ? 'Escuchando en vivo' : 'Toca para escuchar'), // Según el estado
              style: const TextStyle(color: Colors.white), // Blanco
            ), // Fin del estado
            if (_error != null) // Si hubo un error...
              Padding( // ...lo muestra
                padding: const EdgeInsets.only(top: 16), // Separación
                child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFB4AB))), // Rojo claro (legible sobre azul)
              ), // Fin del error
            const SizedBox(height: 24), // Espacio
            const Text( // Aviso temporal
              'Por ahora la radio suena mientras esta pantalla esté abierta.', // Lo de pantalla bloqueada llega en el Paso 11
              textAlign: TextAlign.center, // Centrado
              style: TextStyle(color: Colors.white54, fontSize: 12), // Gris claro pequeño
            ), // Fin del aviso
          ], // Fin de los elementos
        ), // Fin de la columna
      ), // Fin del margen
    ); // Fin del centrado
  } // Fin de _reproductor
} // Fin de _PantallaRadioState
