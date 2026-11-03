import 'dart:async'; // Timer (para mandar la señal del en vivo cada 30 s) y StreamSubscription

import 'package:flutter/material.dart'; // Componentes visuales de Flutter
import 'package:youtube_player_iframe/youtube_player_iframe.dart'; // Reproductor de YouTube dentro de la app

import '../modelos/iglesia.dart'; // Ofrendas (botón Ofrendar)
import '../servicios/api.dart'; // Llamadas a la API (vistas y señales)
import '../servicios/compartir.dart'; // Botón Compartir
import '../servicios/registro.dart'; // Llave del teléfono
import '../servicios/ventana_flotante.dart'; // Ventana flotante del video (Android)
import '../tema.dart'; // Colores de Canaán
import '../modelos/predica.dart'; // Prédica (bosquejo y siguiente parte)
import 'bosquejo.dart'; // Pantalla del bosquejo
import 'ofrendas.dart'; // Pantalla de ofrendas (botón Ofrendar)
import 'peticion.dart'; // Formulario de petición (botón Pedir oración)

class PantallaVideo extends StatefulWidget { // Pantalla con el video de YouTube (prédica o transmisión en vivo)
  const PantallaVideo({ // Constructor
    super.key, // Llave interna de Flutter
    required this.api, // API
    required this.registro, // Registro del teléfono
    required this.youtubeId, // Código del video
    required this.titulo, // Título
    this.subtitulo, // Ej: "Pastor Juan · 5 oct 2026"
    this.descripcion, // Texto debajo del video
    this.predicaId, // Número de la prédica (para contar la vista); null en el en vivo
    this.enVivo = false, // true = transmisión en vivo (manda señales y muestra cuántos ven)
    this.acciones = false, // true = muestra los botones Pedir oración · Ofrendar · Compartir (en vivo y repetición del culto)
    this.ofrendas, // Datos de ofrendas (el botón Ofrendar sale solo si el panel las muestra)
    this.predica, // Prédica completa (para el bosquejo y la siguiente parte de la serie)
  }); // Fin del constructor

  final Api api; // De dónde se envían vistas y señales
  final RegistroDispositivo registro; // Para la llave del teléfono
  final String youtubeId; // Código del video de YouTube
  final String titulo; // Título
  final String? subtitulo; // Línea gris bajo el título
  final String? descripcion; // Descripción
  final int? predicaId; // Prédica a la que se le cuenta la vista
  final bool enVivo; // ¿Es la transmisión en vivo?
  final bool acciones; // ¿Mostrar los botones bajo el video?
  final Ofrendas? ofrendas; // Ofrendas del panel (null = sin botón Ofrendar)
  final Predica? predica; // Prédica (null en el en vivo)

  static Widget? reproductorDePrueba; // Solo en pruebas automáticas: reemplaza al reproductor real (YouTube no carga ahí). En la app siempre es null

  @override // Reemplaza createState
  State<PantallaVideo> createState() => _PantallaVideoState(); // Crea el estado
} // Fin de PantallaVideo

class _PantallaVideoState extends State<PantallaVideo> { // Estado de la pantalla del video
  YoutubePlayerController? _control; // Control del reproductor (pausar, cerrar…); null en las pruebas
  StreamSubscription<YoutubePlayerValue>? _escucha; // Escucha los cambios del reproductor (para saber cuándo empieza a sonar)
  bool _vistaContada = false; // true cuando ya se avisó al panel de esta vista (solo una vez por pantalla)
  Timer? _temporizador; // Reloj que manda la siguiente señal del en vivo
  int? _viendoAhora; // Personas viendo el en vivo (null hasta la primera señal)
  bool _transmisionTerminada = false; // true si el panel avisa que el en vivo terminó

  @override // Reemplaza initState
  void initState() { // Al abrir la pantalla
    super.initState(); // Lo de Flutter por defecto
    if (PantallaVideo.reproductorDePrueba == null) { // Con el reproductor real (no en pruebas)...
      _control = YoutubePlayerController.fromVideoId( // ...crea el control del video
        videoId: widget.youtubeId, // Video a reproducir
        autoPlay: true, // Empieza solo (algunos navegadores lo bloquean hasta que se toca la pantalla)
        params: const YoutubePlayerParams( // Opciones del reproductor
          showFullscreenButton: true, // Botón de pantalla completa
          strictRelatedVideos: true, // Al terminar, solo sugiere videos del mismo canal
        ), // Fin de las opciones
      ); // Fin del control
      _escucha = _control!.stream.listen((valor) { // Cada vez que el reproductor cambia de estado...
        if (valor.playerState == PlayerState.playing) _contarVista(); // ...si empezó a reproducirse, cuenta la vista
      }); // Fin de la escucha
      VentanaFlotante.permitir(true); // Si la persona sale de la app, el video sigue en una ventanita (Android)
      VentanaFlotante.alCerrarla = () => _control?.pauseVideo(); // Si cierra la ventanita con la X, el video se pausa (que no siga sonando sin verse)
      VentanaFlotante.activa.addListener(_alCambiarVentana); // Redibuja al entrar o salir de la ventanita
    } // Fin del if
    if (widget.enVivo) _enviarSenal(); // En vivo: primera señal apenas se abre (luego cada 30 s)
  } // Fin de initState

  void _alCambiarVentana() { if (mounted) setState(() {}); } // Entró o salió de la ventanita: redibuja (en la ventanita solo se ve el video)

  Future<void> _entrarVentana() async { // Botón de la barra: pasar a la ventanita ahora
    final mensajero = ScaffoldMessenger.of(context); // Para avisar si no se pudo
    if (!await VentanaFlotante.entrar()) { // Android no aceptó...
      mensajero.showSnackBar(const SnackBar(content: Text('No se pudo abrir la ventana flotante. Revisa en los ajustes del teléfono que "Pantalla en pantalla" esté permitido para Canaán.'))); // ...explica cómo activarla
    } // Fin del if
  } // Fin de _entrarVentana

  Future<void> _contarVista() async { // Avisa al panel que se está viendo la prédica (una sola vez)
    if (_vistaContada || widget.predicaId == null) return; // Ya contada, o no es una prédica: nada que hacer
    _vistaContada = true; // Marca como contada (antes de enviar, para no repetir si llegan varios "playing")
    try { // Intenta avisar
      await widget.registro.conLlave((token) => widget.api.registrarReproduccion(token: token, predicaId: widget.predicaId!)); // POST de la vista
    } catch (_) {} // Si falla (sin internet), no importa: el video sigue
  } // Fin de _contarVista

  Future<void> _enviarSenal() async { // Manda "sigo viendo" y programa la siguiente
    try { // Intenta enviar
      final senal = await widget.registro.conLlave(widget.api.senalEnVivo); // POST de la señal con la llave
      if (!mounted) return; // Si ya se cerró la pantalla, no hace nada más
      if (!senal.enVivo) { // El panel dice que terminó la transmisión...
        _control?.stopVideo(); // ...detiene el video (si no, seguiría sonando lo que YouTube aún tenga)...
        VentanaFlotante.permitir(false); // ...ya no hay video para la ventanita...
        setState(() => _transmisionTerminada = true); // ...cambia el reproductor por el aviso de "terminó"...
        return; // ...y deja de mandar señales
      } // Fin del if
      setState(() => _viendoAhora = senal.viendoAhora); // Actualiza "N personas viendo"
      _temporizador = Timer(Duration(seconds: senal.siguienteSegundos), _enviarSenal); // Programa la siguiente señal
    } catch (_) { // Falló (sin internet, servidor ocupado)...
      if (mounted) _temporizador = Timer(const Duration(seconds: 30), _enviarSenal); // ...reintenta en 30 s
    } // Fin del try
  } // Fin de _enviarSenal

  @override // Reemplaza dispose
  void dispose() { // Al cerrar la pantalla
    _temporizador?.cancel(); // Detiene las señales ("?." = solo si existe)
    if (_control != null) { // Si se había permitido la ventanita (reproductor real)...
      VentanaFlotante.permitir(false); // ...al salir de la app ya no se achica
      VentanaFlotante.alCerrarla = null; // ...nada que pausar
      VentanaFlotante.activa.removeListener(_alCambiarVentana); // ...deja de escuchar
    } // Fin del if
    _escucha?.cancel(); // Deja de escuchar al reproductor
    _control?.close(); // Cierra el reproductor (libera memoria)
    if (widget.enVivo && !_transmisionTerminada) { // Si estaba viendo un en vivo activo...
      widget.registro.conLlave(widget.api.salirEnVivo).catchError((_) {}); // ...avisa "dejé de ver" (baja el contador al instante; si falla, se ignora)
    } // Fin del if
    super.dispose(); // Lo de Flutter por defecto
  } // Fin de dispose

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    final flotante = VentanaFlotante.activa.value && _control != null; // ¿Se está viendo como ventanita? (entonces solo el video, sin barra ni textos)
    return Scaffold( // Estructura de la pantalla
      backgroundColor: flotante ? Colors.black : null, // En la ventanita, fondo negro
      appBar: flotante ? null : AppBar( // Barra con flecha para volver (oculta en la ventanita)
        title: Text(widget.enVivo ? 'En vivo' : 'Prédica'), // Título
        actions: [ // Botones a la derecha
          if (VentanaFlotante.soportada && _control != null && !_transmisionTerminada) // Solo en Android y con video
            IconButton( // Botón de ventana flotante
              tooltip: 'Ver en ventana flotante', // Explicación (también para lectores de pantalla)
              icon: const Icon(Icons.picture_in_picture_alt), // Ícono de ventanita
              onPressed: _entrarVentana, // Pasa a la ventanita
            ), // Fin del botón
        ], // Fin de los botones
      ), // Fin de la barra
      body: Column( // El video SIEMPRE es el primer elemento (así no se recarga al entrar o salir de la ventanita)
        children: [ // Elementos
          if (_transmisionTerminada) // Si el en vivo terminó...
            _videoTerminado() // ...recuadro negro con el aviso (el reproductor se quita para que no siga sonando)
          else // Si no...
            PantallaVideo.reproductorDePrueba ?? YoutubePlayer(controller: _control!, aspectRatio: 16 / 9), // ...el video (16:9) o el de reemplazo en pruebas
          if (!flotante) Expanded(child: ListView( // Debajo del video, lo demás (desplazable); en la ventanita no se muestra
            children: [ // Elementos
          if (widget.enVivo) _barraEnVivo(), // En vivo: franja con "EN VIVO · N viendo" o "terminó"
          if (widget.acciones) _botonesAcciones(), // Botones grandes: Pedir oración · Ofrendar · Compartir
          Padding( // Margen de los textos
            padding: const EdgeInsets.all(16), // 16 por lado
            child: Column( // Textos uno debajo del otro
              crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
              children: [ // Elementos
                Text(widget.titulo, style: Theme.of(context).textTheme.titleLarge), // Título grande
                if (widget.subtitulo != null && widget.subtitulo!.isNotEmpty) // Si hay subtítulo...
                  Padding( // ...con un poco de espacio arriba
                    padding: const EdgeInsets.only(top: 4), // Espacio
                    child: Text(widget.subtitulo!, style: TextStyle(color: context.cc.suave)), // Gris
                  ), // Fin del subtítulo
                if (widget.predica?.tieneBosquejo == true) // Si la prédica tiene bosquejo...
                  Padding( // ...botón para verlo
                    padding: const EdgeInsets.only(top: 14), // Separación
                    child: OutlinedButton.icon( // Botón con borde
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)), // Todo el ancho
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PantallaBosquejo(titulo: widget.titulo, texto: widget.predica!.bosquejo, pdfUrl: widget.predica!.bosquejoPdfUrl))), // Abre el bosquejo
                      icon: const Icon(Icons.list_alt), // Ícono de lista
                      label: const Text('📝 Ver bosquejo', style: TextStyle(fontSize: 16)), // Texto
                    ), // Fin del botón
                  ), // Fin del margen
                if (widget.predica?.siguienteId != null) // Si hay siguiente parte en la serie...
                  Card( // ...tarjeta para abrirla
                    margin: const EdgeInsets.only(top: 14), // Separación
                    child: ListTile( // Renglón
                      leading: Icon(Icons.skip_next, color: context.cc.azul, size: 32), // Ícono de "siguiente"
                      title: Text('SIGUIENTE EN LA SERIE${widget.predica!.siguienteParte != null ? ' · Parte ${widget.predica!.siguienteParte}' : ''}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.cc.azul, letterSpacing: 1)), // Encabezado
                      subtitle: Text(widget.predica!.siguienteTitulo ?? '', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: context.cc.titulo)), // Título
                      trailing: const Icon(Icons.chevron_right), // Flechita
                      onTap: _abrirSiguiente, // Abre la siguiente parte
                    ), // Fin del renglón
                  ), // Fin de la tarjeta
                if (widget.descripcion != null && widget.descripcion!.isNotEmpty) // Si hay descripción...
                  Padding( // ...separada
                    padding: const EdgeInsets.only(top: 16), // Espacio
                    child: Text(widget.descripcion!), // Texto
                  ), // Fin de la descripción
              ], // Fin de los elementos
            ), // Fin de la columna
          ), // Fin del margen
            ], // Fin de los elementos de la lista
          )), // Fin de la lista y de Expanded
        ], // Fin de los elementos
      ), // Fin de la columna
    ); // Fin del Scaffold
  } // Fin de build

  Future<void> _abrirSiguiente() async { // Abre la siguiente parte de la serie (pide la serie al panel para tener todos sus datos)
    final p = widget.predica!; // Esta prédica
    final mensajero = ScaffoldMessenger.of(context); // Para avisar si falla
    final navegador = Navigator.of(context); // Para cambiar de pantalla
    try { // Intenta
      final serie = await widget.api.obtenerPredicas(serieId: p.serieId); // Prédicas de la serie
      final siguiente = serie.firstWhere((x) => x.id == p.siguienteId); // La siguiente
      if (siguiente.youtubeId == null) throw StateError('sin video'); // Sin video: no se puede abrir aquí
      navegador.pushReplacement(MaterialPageRoute(builder: (_) => PantallaVideo( // Reemplaza esta pantalla por la siguiente parte
        api: widget.api, registro: widget.registro, // API y registro
        youtubeId: siguiente.youtubeId!, titulo: siguiente.titulo, // Video y título
        subtitulo: [siguiente.predicador, fechaCorta(siguiente.fecha)].where((t) => t != null && t.isNotEmpty).join(' · '), // Predicador · fecha
        descripcion: siguiente.descripcion, predicaId: siguiente.id, predica: siguiente, // Descripción, vista y bosquejo
      ))); // Fin
    } catch (_) { // Sin internet o no la encontró
      mensajero.showSnackBar(const SnackBar(content: Text('No se pudo abrir la siguiente parte. Revisa tu conexión.'))); // Aviso
    } // Fin del try
  } // Fin de _abrirSiguiente

  Widget _botonesAcciones() { // Fila de botones grandes bajo el video (pensados para adultos mayores)
    final conOfrendas = widget.ofrendas?.mostrar ?? false; // ¿El panel muestra ofrendas?
    return Container( // Fondo blanco con línea abajo
      decoration: BoxDecoration(color: context.cc.tarjeta, border: Border(bottom: BorderSide(color: context.cc.borde))), // Blanco
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), // Relleno
      child: Row( // Botones en fila
        children: [ // Elementos
          _botonAccion(Icons.volunteer_activism, 'Pedir oración', const Color(0xFFB4235A), () => Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaPeticion(api: widget.api, registro: widget.registro)))), // Abre el formulario de petición
          if (conOfrendas) _botonAccion(Icons.favorite, 'Ofrendar', doradoOscuro, () => Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaOfrendas(ofrendas: widget.ofrendas!)))), // Abre ofrendas y diezmos
          _botonAccion(Icons.share, 'Compartir', azulCanaan, _compartir), // Comparte el enlace
        ], // Fin de los elementos
      ), // Fin de la fila
    ); // Fin del contenedor
  } // Fin de _botonesAcciones

  Widget _botonAccion(IconData icono, String texto, Color color, VoidCallback alTocar) { // Un botón: burbuja de color con ícono y texto debajo
    return Expanded( // Todos del mismo ancho
      child: InkWell( // Se puede tocar (con efecto)
        onTap: alTocar, // Acción
        borderRadius: BorderRadius.circular(12), // Efecto redondeado
        child: Padding( // Relleno
          padding: const EdgeInsets.symmetric(vertical: 6), // Arriba y abajo
          child: Column( // Ícono arriba, texto abajo
            children: [ // Elementos
              CircleAvatar(radius: 24, backgroundColor: context.vivo(color).withValues(alpha: context.alfaBurbuja), child: Icon(icono, color: context.vivo(color), size: 26)), // Burbuja de color
              const SizedBox(height: 6), // Espacio
              Text(texto, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.cc.titulo)), // Texto
            ], // Fin de los elementos
          ), // Fin de la columna
        ), // Fin del relleno
      ), // Fin de InkWell
    ); // Fin de Expanded
  } // Fin de _botonAccion

  void _compartir() { // Comparte el video (en vivo: invita a verlo; repetición: el culto)
    final enlace = 'https://youtu.be/${widget.youtubeId}'; // Enlace corto de YouTube (abre la app de YouTube o el navegador)
    final invitacion = widget.enVivo ? '🔴 ¡Estamos en vivo! ${widget.titulo}\nAcompáñanos:' : '${widget.titulo}\nMíralo aquí:'; // Texto según el caso
    Compartir.texto('$invitacion $enlace'); // Abre la ventana de compartir (con la firma de la iglesia)
  } // Fin de _compartir

  Widget _videoTerminado() { // Recuadro que reemplaza al video cuando el en vivo terminó
    return AspectRatio( // Mismo tamaño que el video (16:9)
      aspectRatio: 16 / 9, // Ancho : alto
      child: Container( // Fondo
        color: marinoCanaan, // Marino
        alignment: Alignment.center, // Contenido centrado
        child: Column( // Elementos uno debajo del otro
          mainAxisSize: MainAxisSize.min, // Ocupa solo lo necesario
          children: [ // Elementos
            const Icon(Icons.tv_off, color: Colors.white70, size: 48), // Televisor apagado
            const SizedBox(height: 8), // Espacio
            const Text('La transmisión terminó', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), // Mensaje
            const SizedBox(height: 12), // Espacio
            OutlinedButton( // Botón para volver
              onPressed: () => Navigator.pop(context), // Cierra esta pantalla
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)), // Blanco
              child: const Text('Volver al inicio'), // Texto
            ), // Fin del botón
          ], // Fin de los elementos
        ), // Fin de la columna
      ), // Fin del fondo
    ); // Fin de AspectRatio
  } // Fin de _videoTerminado

  Widget _barraEnVivo() { // Franja bajo el video del en vivo
    if (_transmisionTerminada) { // Si terminó...
      return Container( // ...franja gris
        color: Colors.black87, // Casi negro
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Relleno
        child: const Text('La transmisión terminó. ¡Gracias por acompañarnos!', style: TextStyle(color: Colors.white)), // Mensaje
      ); // Fin de la franja
    } // Fin del if
    return Container( // Transmisión activa: franja marino
      color: marinoCanaan, // Fondo marino
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Relleno
      child: Row( // Elementos en fila
        children: [ // Elementos
          Container( // Etiqueta roja "● EN VIVO"
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // Relleno
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)), // Rojo con esquinas suaves
            child: const Text('● EN VIVO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)), // Texto
          ), // Fin de la etiqueta
          const Spacer(), // Empuja lo siguiente a la derecha
          const Icon(Icons.visibility, color: Colors.white70, size: 18), // Ojo
          const SizedBox(width: 6), // Espacio
          Text( // Cuántos ven
            _viendoAhora == null ? '…' : '$_viendoAhora ${_viendoAhora == 1 ? 'persona viendo' : 'personas viendo'}', // "…" hasta la primera señal; singular o plural
            style: const TextStyle(color: Colors.white), // Blanco
          ), // Fin del texto
        ], // Fin de los elementos
      ), // Fin de la fila
    ); // Fin de la franja
  } // Fin de _barraEnVivo
} // Fin de _PantallaVideoState
