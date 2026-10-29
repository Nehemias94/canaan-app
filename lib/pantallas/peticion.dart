import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../servicios/api.dart'; // Llamadas a la API (enviarPeticion, ErrorApi)
import '../servicios/registro.dart'; // Registro del teléfono (para la llave)
import '../tema.dart'; // Colores de Canaán

class PantallaPeticion extends StatefulWidget { // Formulario "Petición de oración" (se abre desde Más)
  const PantallaPeticion({super.key, required this.api, required this.registro}); // Constructor

  final Api api; // Para enviar la petición
  final RegistroDispositivo registro; // Para obtener la llave del teléfono

  @override // Reemplaza createState
  State<PantallaPeticion> createState() => _PantallaPeticionState(); // Crea el estado
} // Fin de PantallaPeticion

class _PantallaPeticionState extends State<PantallaPeticion> { // Estado del formulario
  final _formulario = GlobalKey<FormState>(); // "Llave" del formulario: permite validar todos los campos a la vez
  final _nombre = TextEditingController(); // Controla el texto del campo Nombre
  final _peticion = TextEditingController(); // Controla el texto del campo Petición
  bool _enviando = false; // true mientras se está enviando (para desactivar el botón y mostrar la rueda)
  String? _error; // Mensaje de error para mostrar arriba del botón (null = sin error)

  @override // Reemplaza dispose
  void dispose() { // Al cerrar la pantalla
    _nombre.dispose(); // Libera la memoria del campo Nombre
    _peticion.dispose(); // Libera la memoria del campo Petición
    super.dispose(); // Lo de Flutter por defecto
  } // Fin de dispose

  Future<RespuestaPeticion> _enviarConLlave() => widget.registro.conLlave( // Envía con la llave del teléfono (si la rechazan, se registra de nuevo y reenvía una vez)
        (token) => widget.api.enviarPeticion(token: token, nombre: _nombre.text, peticion: _peticion.text), // La llamada a hacer
      ); // Fin de conLlave

  Future<void> _enviar() async { // Al pulsar "Enviar petición"
    if (!_formulario.currentState!.validate()) return; // Revisa los campos; si alguno está mal, muestra el error bajo el campo y no envía
    FocusScope.of(context).unfocus(); // Esconde el teclado
    setState(() { _enviando = true; _error = null; }); // Muestra la rueda y borra errores anteriores
    try { // Intenta enviar
      final respuesta = await _enviarConLlave(); // Envía y espera la respuesta
      if (!mounted) return; // Si la persona cerró la pantalla mientras tanto, no hace nada más
      setState(() => _enviando = false); // Quita la rueda del botón ANTES de la ventana (si no, seguiría girando detrás)
      await showDialog<void>( // Ventana de confirmación
        context: context, // Dónde mostrarla
        builder: (context) => AlertDialog( // Ventana
          icon: const Icon(Icons.volunteer_activism, color: doradoCanaan, size: 48), // Manos doradas
          title: const Text('¡Petición enviada!'), // Título
          content: Text( // Texto
            '${respuesta.mensaje}\n\n${respuesta.restantesHoy > 0 ? 'Puedes enviar ${respuesta.restantesHoy} más hoy.' : 'Ya no puedes enviar más peticiones hoy.'}', // Mensaje del panel + cuántas le quedan
            textAlign: TextAlign.center, // Centrado
          ), // Fin del texto
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Amén'))], // Botón para cerrar la ventana
        ), // Fin de la ventana
      ); // Fin de showDialog
      if (mounted) Navigator.pop(context); // Cierra el formulario y vuelve a Más
    } on ErrorApi catch (error) { // El panel respondió con error
      setState(() => _error = switch (error.codigo) { // Elige el mensaje según el código ("switch" de Dart 3)
            429 => error.mensaje ?? 'Ya enviaste el máximo de peticiones por hoy.', // Límite de 3 por día: muestra el mensaje del panel
            422 => 'Revisa tu petición: debe tener entre 5 y 1000 letras.', // Datos inválidos
            _ => 'No pudimos enviar tu petición. Intenta de nuevo en un momento.', // Cualquier otro error
          }); // Fin del switch
    } catch (_) { // Sin internet, servidor dormido que no respondió, etc.
      setState(() => _error = 'No pudimos conectar con la iglesia. Revisa tu internet e intenta de nuevo.'); // Mensaje
    } finally { // Pase lo que pase...
      if (mounted) setState(() => _enviando = false); // ...quita la rueda (si la pantalla sigue abierta)
    } // Fin del try
  } // Fin de _enviar

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Scaffold( // Estructura de la pantalla
      appBar: AppBar(title: const Text('Petición de oración')), // Barra con flecha para volver
      body: Form( // Formulario (agrupa los campos para validarlos juntos)
        key: _formulario, // Su llave
        child: ListView( // Desplazable (el teclado ocupa media pantalla)
          padding: const EdgeInsets.all(20), // Margen
          children: [ // Elementos
            Container( // Recuadro de confidencialidad
              padding: const EdgeInsets.all(14), // Relleno
              decoration: BoxDecoration( // Apariencia
                color: azulCanaan.withValues(alpha: 0.07), // Azul muy suave
                borderRadius: BorderRadius.circular(12), // Esquinas redondeadas
              ), // Fin de la apariencia
              child: Row( // Ícono y texto en fila
                crossAxisAlignment: CrossAxisAlignment.start, // Alineados arriba
                children: [ // Elementos
                  Icon(Icons.lock_outline, color: context.cc.azul), // Candado
                  SizedBox(width: 10), // Espacio
                  Expanded( // El texto ocupa el resto del ancho
                    child: Text('Tu petición es confidencial: solo la verá el equipo pastoral. El nombre es opcional.'), // Aclaración (sugerida en API.md)
                  ), // Fin de Expanded
                ], // Fin de los elementos
              ), // Fin de la fila
            ), // Fin del recuadro
            const SizedBox(height: 20), // Espacio
            TextFormField( // Campo Nombre
              controller: _nombre, // Su controlador
              maxLength: 60, // Máximo 60 letras (como el panel); muestra el contador
              textCapitalization: TextCapitalization.words, // En el teléfono, mayúscula al inicio de cada palabra
              decoration: const InputDecoration( // Apariencia
                labelText: 'Tu nombre (opcional)', // Etiqueta
                hintText: 'Déjalo vacío para enviarla como anónima', // Ayuda gris
                prefixIcon: Icon(Icons.person_outline), // Ícono de persona
                border: OutlineInputBorder(), // Borde
              ), // Fin de la apariencia
            ), // Fin del campo Nombre
            const SizedBox(height: 8), // Espacio
            TextFormField( // Campo Petición
              controller: _peticion, // Su controlador
              maxLength: 1000, // Máximo 1000 letras (como el panel)
              minLines: 5, // Alto inicial: 5 renglones
              maxLines: 10, // Crece hasta 10 renglones (después se desplaza)
              textCapitalization: TextCapitalization.sentences, // Mayúscula al inicio de cada oración
              decoration: const InputDecoration( // Apariencia
                labelText: 'Tu petición', // Etiqueta
                hintText: '¿Por qué quieres que oremos?', // Ayuda gris
                alignLabelWithHint: true, // Etiqueta arriba (en campos de varios renglones)
                border: OutlineInputBorder(), // Borde
              ), // Fin de la apariencia
              validator: (texto) { // Revisa el campo antes de enviar
                final largo = (texto ?? '').trim().length; // Cuántas letras tiene (sin espacios de los extremos)
                if (largo == 0) return 'Escribe tu petición.'; // Vacío
                if (largo < 5) return 'Escribe al menos 5 letras.'; // Muy corta (el panel pide mínimo 5)
                return null; // null = está bien
              }, // Fin del validador
            ), // Fin del campo Petición
            if (_error != null) // Si hay un error...
              Padding( // ...lo muestra en rojo
                padding: const EdgeInsets.only(top: 8), // Separación
                child: Text(_error!, style: const TextStyle(color: Colors.red)), // Texto rojo
              ), // Fin del error
            const SizedBox(height: 16), // Espacio
            FilledButton.icon( // Botón Enviar
              onPressed: _enviando ? null : _enviar, // Desactivado mientras envía (null = no se puede pulsar)
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), // Todo el ancho y 52 de alto
              icon: _enviando // ¿Enviando?
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) // Sí: rueda pequeña
                  : const Icon(Icons.send), // No: avión de papel
              label: Text(_enviando ? 'Enviando…' : 'Enviar petición'), // Texto según el estado
            ), // Fin del botón
          ], // Fin de los elementos
        ), // Fin de la lista
      ), // Fin del formulario
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de _PantallaPeticionState
