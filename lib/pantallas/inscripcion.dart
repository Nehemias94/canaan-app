import 'package:flutter/material.dart'; // Componentes visuales de Flutter
import 'package:flutter/services.dart'; // Teclado de números para el teléfono

import '../modelos/evento.dart'; // Evento e InscripcionEvento
import '../servicios/api.dart'; // ErrorApi (mensajes del panel)
import '../servicios/preferencias.dart'; // Recordar nombre y teléfono para la próxima vez
import '../servicios/servicios_app.dart'; // API y llave del teléfono
import '../tema.dart'; // Colores

class PantallaInscripcion extends StatefulWidget { // Formulario para inscribirse a un evento (o cambiar los datos de la inscripción)
  const PantallaInscripcion({super.key, required this.evento, this.actual}); // Constructor

  final Evento evento; // Evento
  final InscripcionEvento? actual; // Inscripción que ya tiene (null = nueva)

  @override // Reemplaza createState
  State<PantallaInscripcion> createState() => _PantallaInscripcionState(); // Crea el estado
} // Fin de PantallaInscripcion

class _PantallaInscripcionState extends State<PantallaInscripcion> { // Estado del formulario
  final _formulario = GlobalKey<FormState>(); // Para validar los campos
  late final _nombre = TextEditingController(text: widget.actual?.nombre ?? Preferencias.nombreInscripcion); // Nombre (el de su inscripción o el último que usó)
  late final _telefono = TextEditingController(text: widget.actual?.telefono ?? Preferencias.telefonoInscripcion); // Teléfono
  late final _nota = TextEditingController(text: widget.actual?.nota ?? ''); // Comentario
  late int _personas = widget.actual?.personas ?? 1; // Cuántas personas
  bool _enviando = false; // true mientras se envía (botón con rueda)

  @override // Reemplaza dispose
  void dispose() { // Al cerrar
    _nombre.dispose(); _telefono.dispose(); _nota.dispose(); // Libera los campos
    super.dispose(); // Lo de Flutter por defecto
  } // Fin de dispose

  Future<void> _enviar() async { // Envía la inscripción al panel
    if (!_formulario.currentState!.validate()) return; // Algún campo está mal: se marca en rojo
    setState(() => _enviando = true); // Rueda en el botón
    final mensajero = ScaffoldMessenger.of(context); // Para avisar (se toma antes de esperar)
    final navegador = Navigator.of(context); // Para volver
    try { // Intenta
      final mensaje = await ServiciosApp.conLlave((t) => ServiciosApp.api.inscribirEvento(token: t, eventoId: widget.evento.id, nombre: _nombre.text.trim(), telefono: _telefono.text.trim(), personas: _personas, nota: _nota.text.trim())); // Envía
      await Preferencias.guardarDatosInscripcion(_nombre.text.trim(), _telefono.text.trim()); // Recuerda nombre y teléfono para la próxima vez
      mensajero.showSnackBar(SnackBar(content: Text(mensaje))); // "¡Listo! Quedaste inscrito."
      navegador.pop(true); // Vuelve (true = hubo cambios)
    } on ErrorApi catch (error) { // El panel respondió con un problema (cerradas, sin cupo, dato mal)
      mensajero.showSnackBar(SnackBar(content: Text(error.mensaje ?? 'No se pudo completar la inscripción.'))); // Mensaje del panel
    } catch (_) { // Sin internet
      mensajero.showSnackBar(const SnackBar(content: Text('No hay conexión. Intenta de nuevo cuando tengas internet.'))); // Aviso
    } finally { // Siempre
      if (mounted) setState(() => _enviando = false); // Quita la rueda
    } // Fin del try
  } // Fin de _enviar

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    final restantes = widget.evento.inscripcionesRestantes; // Lugares libres (null = sin límite)
    final maximo = restantes == null ? 10 : (restantes + (widget.actual?.personas ?? 0)).clamp(1, 10); // Máximo de personas que puede poner
    return Scaffold( // Estructura
      appBar: AppBar(title: Text(widget.actual == null ? 'Inscribirme' : 'Cambiar mi inscripción')), // Barra con flecha para volver
      body: Form( // Formulario
        key: _formulario, // Llave para validar
        child: ListView( // Desplazable (el teclado no tapa los campos)
          padding: const EdgeInsets.all(16), // Márgenes
          children: [ // Elementos
            Text(widget.evento.titulo, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.cc.titulo)), // Evento
            Text(widget.evento.cuandoTexto(), style: TextStyle(color: context.cc.suave)), // Fecha
            const SizedBox(height: 20), // Espacio
            TextFormField( // Nombre
              controller: _nombre, // Valor
              decoration: const InputDecoration(labelText: 'Nombre completo', border: OutlineInputBorder()), // Apariencia
              textCapitalization: TextCapitalization.words, // Mayúscula al inicio de cada palabra
              maxLength: 80, // Máximo
              validator: (v) => (v ?? '').trim().length < 2 ? 'Escribe tu nombre.' : null, // Obligatorio
            ), // Fin del nombre
            const SizedBox(height: 8), // Espacio
            TextFormField( // Teléfono
              controller: _telefono, // Valor
              decoration: const InputDecoration(labelText: 'Teléfono (WhatsApp)', hintText: 'Ej: 7000-1234', border: OutlineInputBorder()), // Apariencia
              keyboardType: TextInputType.phone, // Teclado de números
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]'))], // Solo números, +, -, espacios
              maxLength: 20, // Máximo
              validator: (v) => RegExp(r'\d').allMatches(v ?? '').length < 7 ? 'Escribe un número de teléfono válido.' : null, // Al menos 7 números
            ), // Fin del teléfono
            const SizedBox(height: 8), // Espacio
            Row( // Cuántas personas, con botones − y +
              children: [ // Elementos
                Expanded(child: Text('¿Cuántas personas van? (contándote)', style: TextStyle(fontSize: 16, color: context.cc.texto))), // Pregunta
                IconButton.filledTonal(tooltip: 'Menos', onPressed: _personas > 1 ? () => setState(() => _personas--) : null, icon: const Icon(Icons.remove)), // −
                SizedBox(width: 44, child: Text('$_personas', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: context.cc.titulo))), // Número
                IconButton.filledTonal(tooltip: 'Más', onPressed: _personas < maximo ? () => setState(() => _personas++) : null, icon: const Icon(Icons.add)), // +
              ], // Fin de los elementos
            ), // Fin de la fila
            if (restantes != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Quedan $restantes lugar(es).', style: TextStyle(color: context.cc.suave))), // Cupo
            const SizedBox(height: 16), // Espacio
            TextFormField( // Nota
              controller: _nota, // Valor
              decoration: const InputDecoration(labelText: 'Comentario (opcional)', hintText: 'Ej: llevo a mis 2 hijos', border: OutlineInputBorder()), // Apariencia
              maxLength: 200, // Máximo
              maxLines: 2, // Dos renglones
            ), // Fin de la nota
            const SizedBox(height: 12), // Espacio
            FilledButton.icon( // Enviar
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)), // Grande, todo el ancho
              onPressed: _enviando ? null : _enviar, // Desactivado mientras envía
              icon: _enviando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.how_to_reg), // Rueda o ícono
              label: Text(widget.actual == null ? 'Inscribirme' : 'Guardar cambios', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), // Texto
            ), // Fin del botón
            const SizedBox(height: 10), // Espacio
            Text('Tus datos solo los ve la iglesia para organizar el evento.', textAlign: TextAlign.center, style: TextStyle(color: context.cc.suave, fontSize: 13)), // Privacidad
          ], // Fin de los elementos
        ), // Fin de la lista
      ), // Fin del formulario
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de _PantallaInscripcionState
