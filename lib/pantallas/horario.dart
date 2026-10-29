import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../componentes/estados.dart'; // Vistas compartidas: Cargando, ErrorConexion, Vacio
import '../modelos/actividad.dart'; // Molde de una actividad
import '../servicios/api.dart'; // Llamadas a la API
import '../servicios/preferencias.dart'; // Lista de cultos con recordatorio
import '../servicios/recordatorios.dart'; // Recordatorio 30 min antes
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
    _peticion.then(Recordatorios.sincronizar).catchError((_) {}); // Reprograma los recordatorios con las horas nuevas (por si el panel las cambió)
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
            style: TextStyle(color: context.cc.azul, fontWeight: FontWeight.bold, letterSpacing: 1.2), // Azul, negrita, letras separadas
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
        title: Text(actividad.nombre, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.cc.titulo)), // Nombre en negrita marino, ej: "Culto general"
        subtitle: Text( // Detalles
          [detalles, if (actividad.descripcion != null) actividad.descripcion!].join('\n'), // Horario · lugar y, en otra línea, la descripción
        ), // Fin de los detalles
        trailing: Row( // A la derecha: "Ahora" y la campanita
          mainAxisSize: MainAxisSize.min, // Solo lo necesario
          children: [ // Elementos
            if (actividad.enCurso) // ¿Está ocurriendo ahora?
              const Chip( // Sí: etiqueta verde "Ahora"
                label: Text('Ahora', style: TextStyle(color: Colors.white)), // Texto blanco
                backgroundColor: Colors.green, // Fondo verde
                visualDensity: VisualDensity.compact, // Compacta
              ), // Fin de la etiqueta
            if (Recordatorios.soportado) _Campanita(actividad: actividad), // Recordatorio 30 min antes (solo en teléfonos)
          ], // Fin de los elementos
        ), // Fin de la fila
      ), // Fin de la fila
    ); // Fin de la tarjeta
  } // Fin de build
} // Fin de _FilaActividad

class _Campanita extends StatelessWidget { // Botón 🔔 de recordatorio de un culto (activo = campana dorada)
  const _Campanita({required this.actividad}); // Constructor

  final Actividad actividad; // El culto

  Future<void> _alternar(BuildContext context, bool activo) async { // Activa o quita el recordatorio
    final mensajero = ScaffoldMessenger.of(context); // Para avisar (se toma antes de esperar)
    if (activo) { // Si estaba activo...
      await Recordatorios.desactivar(actividad.id); // ...lo quita
      mensajero.showSnackBar(SnackBar(content: Text('Ya no te recordaremos "${actividad.nombre}".'))); // Aviso
      return; // Listo
    } // Fin del if
    final listo = await Recordatorios.activar(actividad); // Lo activa (pide permiso de notificaciones si hace falta)
    mensajero.showSnackBar(SnackBar(content: Text(listo // Aviso según el resultado
        ? 'Listo: te avisaremos ${Recordatorios.minutosAntes} minutos antes de "${actividad.nombre}", cada ${actividad.dia.toLowerCase()}.' // Activado
        : 'Para recordarte, permite las notificaciones de la app en Ajustes.'))); // Sin permiso
  } // Fin de _alternar

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return ValueListenableBuilder<Set<int>>( // Escucha la lista de recordatorios
      valueListenable: Preferencias.recordatorios, // Preferencia
      builder: (context, ids, _) { // Cada vez que cambia
        final activo = ids.contains(actividad.id); // ¿Este culto tiene recordatorio?
        return IconButton( // Botón
          tooltip: activo ? 'Quitar recordatorio' : 'Recordarme 30 minutos antes', // Texto de ayuda
          iconSize: 28, // Grande
          icon: Icon(activo ? Icons.notifications_active : Icons.notifications_none, color: activo ? context.cc.dorado : context.cc.suave), // Dorada si está activa
          onPressed: () => _alternar(context, activo), // Al tocar
        ); // Fin del botón
      }, // Fin del builder
    ); // Fin de la escucha
  } // Fin de build
} // Fin de _Campanita
