import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../componentes/estados.dart'; // Vistas compartidas: Cargando, ErrorConexion, Vacio
import '../modelos/actividad.dart'; // Molde de una actividad
import '../servicios/api.dart'; // Llamadas a la API
import '../tema.dart'; // Colores de Canaán

class PantallaHorario extends StatefulWidget { // Pestaña "Horario"
  const PantallaHorario({super.key, required this.api}); // Constructor: recibe la API

  final Api api; // De dónde se sacan los datos

  @override // Reemplaza createState
  State<PantallaHorario> createState() => _PantallaHorarioState(); // Crea el estado
} // Fin de PantallaHorario

class _PantallaHorarioState extends State<PantallaHorario> { // Estado de la pestaña Horario
  late Future<List<Actividad>> _peticion; // Petición en curso

  @override // Reemplaza initState
  void initState() { // Al abrir la pestaña por primera vez
    super.initState(); // Lo de Flutter por defecto
    _peticion = widget.api.obtenerActividades(); // Pide el horario
  } // Fin de initState

  Future<void> _recargar() async { // Vuelve a pedir el horario
    setState(() => _peticion = widget.api.obtenerActividades()); // Nueva petición y redibuja
    try { await _peticion; } catch (_) {} // Espera a que termine
  } // Fin de _recargar

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Scaffold( // Estructura de la pantalla
      appBar: AppBar(title: const Text('Horario de cultos')), // Barra de título
      body: FutureBuilder<List<Actividad>>( // Dibuja según el estado de la petición
        future: _peticion, // Petición que vigila
        builder: (context, estado) { // Se llama cada vez que cambia
          if (estado.connectionState != ConnectionState.done) return const Cargando(); // Esperando
          if (estado.hasError) return ErrorConexion(alReintentar: _recargar); // Falló
          final actividades = estado.data!; // Lista recibida (ya viene ordenada por día y hora)
          return RefreshIndicator( // "Jalar hacia abajo" para actualizar
            onRefresh: _recargar, // Qué hacer al jalar
            child: actividades.isEmpty // ¿Está vacía?
                ? const Vacio(icono: Icons.event_busy, mensaje: 'Aún no hay actividades en el horario.') // Sí: mensaje
                : ListView( // No: lista agrupada por día
                    padding: const EdgeInsets.only(bottom: 16), // Margen abajo
                    children: _armarLista(actividades), // Encabezados de día + actividades
                  ), // Fin de la lista
          ); // Fin de RefreshIndicator
        }, // Fin de builder
      ), // Fin de FutureBuilder
    ); // Fin del Scaffold
  } // Fin de build

  List<Widget> _armarLista(List<Actividad> actividades) { // Intercala un encabezado cada vez que cambia el día
    final elementos = <Widget>[]; // Lista que se va llenando
    int? diaAnterior; // Día de la actividad anterior (null al principio)
    for (final actividad in actividades) { // Recorre las actividades en orden
      if (actividad.diaSemana != diaAnterior) { // Si empieza un día nuevo...
        elementos.add(Padding( // ...agrega el encabezado del día
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 6), // Margen
          child: Text( // Nombre del día
            actividad.dia.toUpperCase(), // En mayúsculas, ej: "DOMINGO"
            style: const TextStyle(color: azulCanaan, fontWeight: FontWeight.bold, letterSpacing: 1.2), // Azul, negrita, letras separadas
          ), // Fin del texto
        )); // Fin del encabezado
        diaAnterior = actividad.diaSemana; // Recuerda el día actual
      } // Fin del if
      elementos.add(_FilaActividad(actividad: actividad)); // Agrega la actividad
    } // Fin del for
    return elementos; // Devuelve todo
  } // Fin de _armarLista
} // Fin de _PantallaHorarioState

class _FilaActividad extends StatelessWidget { // Una actividad dentro del horario
  const _FilaActividad({required this.actividad}); // Constructor

  final Actividad actividad; // Datos de la actividad

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    final detalles = [actividad.horario, actividad.lugar] // Horario y lugar...
        .where((parte) => parte != null && parte.isNotEmpty) // ...sin los vacíos...
        .join(' · '); // ...unidos con un punto medio
    return Card( // Tarjeta
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // Separación
      child: ListTile( // Fila con ícono, título y detalles
        leading: Icon( // Ícono a la izquierda
          actividad.seTransmite ? Icons.live_tv : Icons.event, // Televisor si se transmite; calendario si no
          color: actividad.seTransmite ? Colors.red : azulCanaan, // Rojo o azul
        ), // Fin del ícono
        title: Text(actividad.nombre), // Nombre, ej: "Culto general"
        subtitle: Text( // Detalles
          [detalles, if (actividad.descripcion != null) actividad.descripcion!].join('\n'), // Horario · lugar y, en otra línea, la descripción
        ), // Fin de los detalles
        trailing: actividad.enCurso // ¿Está ocurriendo ahora?
            ? const Chip( // Sí: etiqueta verde "Ahora"
                label: Text('Ahora', style: TextStyle(color: Colors.white)), // Texto blanco
                backgroundColor: Colors.green, // Fondo verde
                visualDensity: VisualDensity.compact, // Compacta
              ) // Fin de la etiqueta
            : null, // No: nada
      ), // Fin de la fila
    ); // Fin de la tarjeta
  } // Fin de build
} // Fin de _FilaActividad
