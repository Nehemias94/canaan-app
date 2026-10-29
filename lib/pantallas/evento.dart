import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../componentes/campanita_evento.dart'; // Activar/quitar el recordatorio
import '../componentes/imagen_y_boton.dart'; // Imagen (flyer) y botón con enlace
import '../modelos/evento.dart'; // Molde de un evento
import '../servicios/api.dart'; // ErrorApi
import '../servicios/compartir.dart'; // Compartir
import '../servicios/servicios_app.dart'; // API y llave del teléfono (inscripciones)
import 'inscripcion.dart'; // Formulario de inscripción
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
          if (evento.seTransmite) _Dato(icono: Icons.live_tv, texto: 'Se transmite en vivo en la app', color: context.vivo(Colors.red.shade700)), // En vivo
          if (evento.descripcion != null && evento.descripcion!.isNotEmpty) // Si tiene detalle...
            Padding(padding: const EdgeInsets.only(top: 14), child: Text(evento.descripcion!, style: const TextStyle(fontSize: 17, height: 1.4))), // ...texto
          if (evento.inscripcionesActivas) _RecuadroInscripcion(evento: evento), // Inscripción desde la app
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

class _RecuadroInscripcion extends StatefulWidget { // Recuadro "Inscripción" del detalle: estado, botón Inscribirme / Cambiar / Cancelar
  const _RecuadroInscripcion({required this.evento}); // Constructor

  final Evento evento; // Evento

  @override // Reemplaza createState
  State<_RecuadroInscripcion> createState() => _RecuadroInscripcionState(); // Crea el estado
} // Fin de _RecuadroInscripcion

class _RecuadroInscripcionState extends State<_RecuadroInscripcion> { // Estado del recuadro
  EstadoInscripcion? _estado; // Lo que dijo el panel (null = cargando)
  bool _fallo = false; // true si no se pudo consultar

  @override // Reemplaza initState
  void initState() { // Al abrir el detalle
    super.initState(); // Lo de Flutter por defecto
    _cargar(); // Pregunta al panel
  } // Fin de initState

  Future<void> _cargar() async { // ¿Está inscrito? ¿Hay lugar?
    try { // Intenta
      final estado = await ServiciosApp.conLlave((t) => ServiciosApp.api.miInscripcion(token: t, eventoId: widget.evento.id)); // Pregunta
      if (mounted) setState(() { _estado = estado; _fallo = false; }); // Redibuja
    } catch (_) { // Sin internet
      if (mounted) setState(() => _fallo = true); // Mensaje con "Reintentar"
    } // Fin del try
  } // Fin de _cargar

  Future<void> _abrirFormulario() async { // Abre el formulario (nuevo o para cambiar)
    final cambio = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => PantallaInscripcion(evento: widget.evento, actual: _estado?.mia))); // Espera a que vuelva
    if (cambio == true) _cargar(); // Si se inscribió o cambió: actualiza
  } // Fin de _abrirFormulario

  Future<void> _cancelar() async { // Cancelar la inscripción (con confirmación)
    final si = await showDialog<bool>(context: context, builder: (c) => AlertDialog( // Pregunta
      title: const Text('¿Cancelar tu inscripción?'), // Título
      content: Text('Ya no estarás en la lista de "${widget.evento.titulo}".'), // Explicación
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sí, cancelar'))], // Botones
    )); // Fin de la ventana
    if (si != true || !mounted) return; // Dijo que no
    final mensajero = ScaffoldMessenger.of(context); // Para avisar
    try { // Intenta
      final mensaje = await ServiciosApp.conLlave((t) => ServiciosApp.api.cancelarInscripcion(token: t, eventoId: widget.evento.id)); // Cancela
      mensajero.showSnackBar(SnackBar(content: Text(mensaje))); // "Cancelamos tu inscripción."
      _cargar(); // Actualiza
    } on ErrorApi catch (error) { // El panel respondió con un problema
      mensajero.showSnackBar(SnackBar(content: Text(error.mensaje ?? 'No se pudo cancelar.'))); // Mensaje
    } catch (_) { // Sin internet
      mensajero.showSnackBar(const SnackBar(content: Text('No hay conexión. Intenta de nuevo cuando tengas internet.'))); // Aviso
    } // Fin del try
  } // Fin de _cancelar

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    final estado = _estado; // Atajo
    final verde = context.vivo(const Color(0xFF15803D)); // Verde (más claro en modo oscuro)
    return Card( // Tarjeta
      margin: const EdgeInsets.only(top: 16), // Separación
      child: Padding( // Relleno
        padding: const EdgeInsets.all(16), // 16 por lado
        child: Column( // Uno debajo del otro
          crossAxisAlignment: CrossAxisAlignment.stretch, // Todo el ancho
          children: [ // Elementos
            Text('📝 INSCRIPCIÓN', style: TextStyle(color: context.cc.morado, fontWeight: FontWeight.bold, letterSpacing: 1.2)), // Título
            const SizedBox(height: 10), // Espacio
            if (estado == null && !_fallo) const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())), // Cargando
            if (_fallo) ...[ // Sin conexión
              Text('No pudimos revisar tu inscripción (sin conexión).', style: TextStyle(color: context.cc.suave)), // Mensaje
              TextButton(onPressed: () { setState(() => _fallo = false); _cargar(); }, child: const Text('Reintentar')), // Reintentar
            ], // Fin
            if (estado?.mia != null) ...[ // Ya está inscrito
              Text('✅ Estás inscrito', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: verde)), // Confirmación
              Text('${estado!.mia!.nombre} · ${estado.mia!.personas} persona(s)', style: TextStyle(fontSize: 16, color: context.cc.texto)), // Datos
              const SizedBox(height: 10), // Espacio
              OutlinedButton.icon(onPressed: _abrirFormulario, icon: const Icon(Icons.edit), label: const Text('Cambiar datos')), // Cambiar
              TextButton.icon(onPressed: _cancelar, icon: const Icon(Icons.cancel_outlined), label: const Text('Cancelar inscripción')), // Cancelar
            ] else if (estado != null && estado.abiertas) ...[ // No inscrito y hay lugar
              if (estado.restantes != null) Text('Quedan ${estado.restantes} lugar(es).', style: TextStyle(color: context.cc.suave)), // Cupo
              const SizedBox(height: 8), // Espacio
              FilledButton.icon( // Botón grande
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: verde, foregroundColor: Colors.white), // Verde, todo el ancho
                onPressed: _abrirFormulario, // Abre el formulario
                icon: const Icon(Icons.how_to_reg), // Ícono
                label: const Text('Inscribirme', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), // Texto
              ), // Fin del botón
            ] else if (estado != null) // No inscrito y no hay lugar o ya cerró
              Text(estado.restantes == 0 ? 'Cupo lleno. Ya no hay lugares disponibles.' : 'Las inscripciones están cerradas.', style: TextStyle(fontSize: 16, color: context.cc.suave)), // Mensaje
          ], // Fin de los elementos
        ), // Fin de la columna
      ), // Fin del relleno
    ); // Fin de la tarjeta
  } // Fin de build
} // Fin de _RecuadroInscripcionState
