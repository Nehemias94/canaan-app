import 'dart:async'; // Timer (actualizar cada 90 s)

import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../componentes/imagen_guardada.dart'; // Imágenes guardadas en el teléfono (no en la galería)
import 'package:flutter/services.dart'; // SystemUiOverlayStyle (colores de la barra de arriba del teléfono)
import 'package:url_launcher/url_launcher.dart'; // Abrir YouTube y Google Maps fuera de la app

import '../componentes/estados.dart'; // Vistas compartidas: Cargando, ErrorConexion
import '../componentes/carruseles.dart'; // Carruseles de ANUNCIOS y PRÓXIMOS EVENTOS
import '../componentes/carga_animada.dart'; // Pantalla de carga con el logo animado
import '../componentes/tarjeta.dart'; // Tarjeta con franja de color (diseño común)
import '../config.dart'; // intervaloActualizacion
import '../modelos/actividad.dart'; // Molde de una actividad (próximo culto)
import '../modelos/anuncio.dart'; // Molde de un anuncio
import '../modelos/evento.dart'; // Molde de un evento especial
import '../modelos/iglesia.dart'; // Molde de los datos de la iglesia
import '../servicios/api.dart'; // Llamadas a la API
import '../servicios/compartir.dart'; // Compartir (versículo, anuncios)
import '../servicios/geocerca.dart'; // Geocerca (anuncios "Solo área", Paso 10)
import '../servicios/geocerca_fondo.dart'; // Geocerca con la app cerrada (Paso 11): se actualiza si el panel cambió la ubicación
import '../servicios/recarga.dart'; // "Timbre" para recargar al instante (aviso urgente)
import '../servicios/registro.dart'; // Registro del teléfono (para las señales del en vivo)
import '../servicios/widget_versiculo.dart'; // Widget del versículo en la pantalla de inicio del teléfono
import '../tema.dart'; // Colores de Canaán
import 'horario.dart'; // Horario de cultos (acceso rápido)
import 'peticion.dart'; // Formulario de petición de oración (acceso rápido)
import 'radio.dart'; // Pantalla de la radio
import 'video.dart'; // Pantalla del video (transmisión en vivo)

class PantallaInicio extends StatefulWidget { // Pestaña "Inicio"; "Stateful" porque cambia (cargando → datos o error)
  const PantallaInicio({super.key, required this.api, required this.registro, this.alIrAPestana}); // Constructor: recibe la API (en pruebas, una falsa) y el registro

  final void Function(int pestana)? alIrAPestana; // Cambiar de pestaña desde los accesos rápidos (Biblia, Horario); lo da la pantalla principal

  final Api api; // De dónde se sacan los datos
  final RegistroDispositivo registro; // Para las señales del en vivo

  @override // Reemplaza createState
  State<PantallaInicio> createState() => _PantallaInicioState(); // Crea el estado de la pantalla
} // Fin de PantallaInicio

class _PantallaInicioState extends State<PantallaInicio> with WidgetsBindingObserver { // Estado de Inicio; "WidgetsBindingObserver" = se entera cuando la app vuelve a primer plano
  Iglesia? _iglesia; // Últimos datos de la iglesia (null hasta la primera respuesta)
  List<Anuncio> _anuncios = []; // Últimos anuncios recibidos
  List<Actividad> _actividades = []; // Horario (para la tarjeta "Próximo culto")
  List<Evento> _eventos = []; // Eventos especiales próximos
  bool _fallo = false; // true si la PRIMERA carga falló (luego, si falla, se conservan los datos anteriores)
  Timer? _reloj; // Reloj que vuelve a preguntar al panel cada 90 s
  Timer? _esperaAnimacion; // Espera para que la animación del logo se vea completa al abrir la app
  bool _animacionVista = false; // true cuando ya pasó el tiempo mínimo de la animación del logo
  late final Geocerca _geocerca = Geocerca(); // Revisa si el teléfono está en la iglesia ("late": se crea la primera vez que se usa)
  bool _revisandoGeocerca = false; // true mientras revisa (para no encimar dos revisiones)
  bool _avisoEnArea = false; // Aviso urgente "solo en un área": true si el teléfono está dentro

  @override // Reemplaza initState
  void initState() { // Se ejecuta una sola vez, al crear la pantalla
    super.initState(); // Lo que hace Flutter por defecto
    WidgetsBinding.instance.addObserver(this); // Empieza a escuchar si la app se minimiza o vuelve
    _cargar(); // Primera carga
    _reloj = Timer.periodic(intervaloActualizacion, (_) => _cargar()); // Luego, cada 90 s, en silencio
    _esperaAnimacion = Timer(const Duration(milliseconds: 4500), () { // Al abrir la app, el logo animado se ve al menos 4.5 s (se forma en 2.5 s y se queda completo 2 s más)...
      if (mounted) setState(() => _animacionVista = true); // ...aunque el panel responda antes
    }); // Fin de la espera
    recargarInicio.addListener(_cargar); // Y al instante cuando el panel cambia el aviso urgente (aviso silencioso de Firebase)
  } // Fin de initState

  @override // Reemplaza dispose
  void dispose() { // Al cerrar la pantalla
    recargarInicio.removeListener(_cargar); // Deja de escuchar el "timbre"
    _reloj?.cancel(); // Detiene el reloj
    _esperaAnimacion?.cancel(); // Y la espera de la animación
    WidgetsBinding.instance.removeObserver(this); // Deja de escuchar
    super.dispose(); // Lo de Flutter por defecto
  } // Fin de dispose

  @override // Reemplaza didChangeAppLifecycleState
  void didChangeAppLifecycleState(AppLifecycleState estado) { // Se llama cuando la app cambia de estado (minimizada, de vuelta…)
    if (estado == AppLifecycleState.resumed) _cargar(); // Al volver a la app, actualiza enseguida (pudo empezar un en vivo)
  } // Fin de didChangeAppLifecycleState

  Future<void> _cargar() async { // Pide iglesia y anuncios al mismo tiempo y actualiza la pantalla
    try { // Intenta
      final iglesia = widget.api.obtenerIglesia(); // Arranca la petición de la iglesia...
      final anuncios = widget.api.obtenerAnuncios().catchError((_) => <Anuncio>[]); // ...y la de anuncios a la vez (si esta falla, sin anuncios: no tumba Inicio)
      final actividades = widget.api.obtenerActividades().catchError((_) => <Actividad>[]); // ...y el horario (para "Próximo culto"; si falla, sin tarjeta)
      final eventos = widget.api.obtenerEventos().catchError((_) => <Evento>[]); // ...y los eventos especiales (si falla, sin eventos)
      final datos = await iglesia; // Espera la iglesia
      final lista = await anuncios; // Espera los anuncios
      final horario = await actividades; // Espera el horario
      final proximosEventos = await eventos; // Espera los eventos
      if (!mounted) return; // Si la pantalla ya se cerró, no hace nada
      setState(() { // Redibuja con lo nuevo
        _iglesia = datos; // Datos de la iglesia
        _anuncios = lista.where((a) => a.esParaTodos && a.vigente(DateTime.now())).toList(); // Solo los de "Todos" que siguen vigentes
        _actividades = horario; // Horario
        _eventos = proximosEventos; // Eventos especiales
        _fallo = false; // Sin error
      }); // Fin de setState
      unawaited(WidgetVersiculo.actualizar(datos.versiculo)); // Pasa el versículo de hoy al widget de la pantalla de inicio (solo Android)
      await _revisarAvisoArea(datos.avisoUrgente); // Aviso urgente con área: ¿está dentro? (solo pide la ubicación si el aviso tiene área)
      await _revisarGeocerca(datos, lista); // Revisa si está en la iglesia (solo pide la ubicación si hay anuncios de área en su ventana)
      unawaited(GeocercaFondo.actualizar(datos, lista)); // Si la persona activó el aviso con la app cerrada: registra los círculos de la iglesia y de cada anuncio de área (si cambiaron)
    } catch (_) { // Falló (sin internet, servidor dormido)
      if (mounted && _iglesia == null) setState(() => _fallo = true); // Solo muestra el error si no había nada en pantalla
    } // Fin del try
  } // Fin de _cargar

  Future<void> _revisarAvisoArea(AvisoUrgente aviso) async { // Aviso urgente "solo en un área"
    if (!aviso.activo || aviso.area == null) return; // Para todos (o no hay): nada que revisar, NO pide la ubicación
    bool dentro = false; // Por defecto, no se muestra
    try { dentro = await _geocerca.estaDentro(aviso.area!); } catch (_) {} // Ubicación del teléfono (nunca sale de él)
    if (mounted && dentro != _avisoEnArea) setState(() => _avisoEnArea = dentro); // Redibuja si cambió
  } // Fin de _revisarAvisoArea

  Future<void> _revisarGeocerca(Iglesia iglesia, List<Anuncio> anuncios) async { // Geocerca: anuncios "Solo área"
    if (_revisandoGeocerca) return; // Ya hay una revisión en curso
    _revisandoGeocerca = true; // Marca que empezó
    try { // Intenta
      await _geocerca.guardarCopia(anuncios); // Guarda los anuncios "Solo área" en el teléfono: el aviso con la app cerrada los usa sin esperar al panel
      final nuevos = await _geocerca.revisar(iglesia, anuncios, DateTime.now()); // Anuncios nuevos por estar en la iglesia (vacío si no, o si ya se mostraron como notificación)
      if (!mounted) return; // Pantalla cerrada: nada
      final llegada = nuevos.where((a) => !a.alSalir).toList(); // Anuncios "al llegar"
      final salida = nuevos.where((a) => a.alSalir).toList(); // Anuncios "al salir"
      if (llegada.isNotEmpty) await _mostrarBienvenida(llegada); // Recién llegó: ventana de bienvenida UNA sola vez (luego ya no aparece en ningún lado)
      if (salida.isNotEmpty && mounted) await _mostrarBienvenida(salida, alSalir: true); // Se fue: ventana de despedida UNA sola vez
    } catch (_) { // Cualquier falla de ubicación: se ignora (la app sigue igual)
    } finally { // Pase lo que pase...
      _revisandoGeocerca = false; // ...termina la revisión
    } // Fin del try
  } // Fin de _revisarGeocerca

  Future<void> _mostrarBienvenida(List<Anuncio> anuncios, {bool alSalir = false}) { // Ventana "¡Qué bueno que estás aquí!" (o "¡Gracias por venir!" al salir) con los anuncios del área
    return showDialog<void>( // Ventana
      context: context, // Dónde mostrarla
      builder: (context) => AlertDialog( // Contenido
        icon: Icon(alSalir ? Icons.waving_hand : Icons.place, color: doradoCanaan, size: 40), // Pin dorado (o mano que saluda al salir)
        title: Text(alSalir ? '¡Gracias por venir!' : '¡Qué bueno que estás aquí!'), // Título
        content: SingleChildScrollView( // Desplazable si son varios
          child: Column( // Uno debajo del otro
            mainAxisSize: MainAxisSize.min, // Solo lo necesario
            crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
            children: [ // Elementos
              for (final a in anuncios) ...[ // Por cada anuncio:
                Text(a.titulo, style: const TextStyle(fontWeight: FontWeight.bold)), // Título en negrita
                const SizedBox(height: 4), // Espacio
                Text(a.mensaje), // Mensaje
                const SizedBox(height: 12), // Espacio
              ], // Fin del anuncio
            ], // Fin de los elementos
          ), // Fin de la columna
        ), // Fin del desplazable
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))], // Botón para cerrar
      ), // Fin de la ventana
    ); // Fin de showDialog
  } // Fin de _mostrarBienvenida

  Future<void> _reintentar() async { // Botón "Reintentar"
    setState(() => _fallo = false); // Vuelve a mostrar "Conectando…"
    await _cargar(); // Intenta otra vez
  } // Fin de _reintentar

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    final enPresentacion = !_fallo && (_iglesia == null || !_animacionVista); // ¿Se está viendo la presentación del logo?
    if (presentacionEnCurso.value != enPresentacion) { // Si cambió...
      WidgetsBinding.instance.addPostFrameCallback((_) => presentacionEnCurso.value = enPresentacion); // ...avisa al menú de abajo (después de dibujar: no se puede cambiar durante el dibujo)
    } // Fin del if
    return AnnotatedRegion<SystemUiOverlayStyle>( // Estilo de la barra de arriba del teléfono (hora, batería) mientras se ve Inicio
      value: barraSuperiorClara, // Íconos en blanco: arriba siempre hay marino
      child: AnimatedSwitcher( // Cambio SUAVE entre el logo animado e Inicio (uno se desvanece mientras aparece el otro)
        duration: const Duration(milliseconds: 600), // Medio segundo y un poco más
        child: _fallo || _iglesia == null || !_animacionVista // ¿Falló la primera carga, todavía no hay datos o la animación del logo no ha terminado?
          ? Container( // Pantalla completa en degradado mientras carga (o si falló)
              key: const ValueKey('carga'), // Nombre para que AnimatedSwitcher sepa que cambió de pantalla
              decoration: const BoxDecoration( // Fondo
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [marinoCanaan, azulCanaan]), // Marino → azul
              ), // Fin del fondo
              child: SafeArea( // Evita la cámara y la barra del teléfono
                child: _fallo // ¿Falló?
                    ? ErrorConexion(alReintentar: _reintentar, claro: true) // Sí: mensaje y Reintentar
                    : CargaAnimada(datosListos: _iglesia != null), // No: logo animado (arca + "Canaán" letra por letra)
              ), // Fin de SafeArea
            ) // Fin de la pantalla de carga
          : Stack( // Hay datos: la lista y, encima, una franja fija detrás de la hora y la batería
              key: const ValueKey('datos'), // Nombre para AnimatedSwitcher
              children: [ // Capas
                RefreshIndicator( // Permite "jalar hacia abajo" para actualizar
                  onRefresh: _cargar, // Qué hacer al jalar
                  child: _DatosIglesia(iglesia: _iglesia!, avisoEnArea: _avisoEnArea, anuncios: _anuncios, actividades: _actividades, eventos: _eventos, api: widget.api, registro: widget.registro, alIrAPestana: widget.alIrAPestana), // Los datos
                ), // Fin de RefreshIndicator
                Positioned( // Franja marino arriba (al bajar, las tarjetas blancas pasan por DEBAJO y la hora y la batería se siguen viendo)
                  top: 0, left: 0, right: 0, // Arriba, todo el ancho
                  height: MediaQuery.paddingOf(context).top, // Alto de la barra del teléfono
                  child: const ColoredBox(color: marinoCanaan), // Marino
                ), // Fin de la franja
              ], // Fin de las capas
            ), // Fin de Stack
      ), // Fin de AnimatedSwitcher
    ); // Fin de AnnotatedRegion
  } // Fin de build
} // Fin de _PantallaInicioState

class _DatosIglesia extends StatelessWidget { // Contenido de Inicio cuando llegaron los datos
  const _DatosIglesia({required this.iglesia, this.avisoEnArea = false, required this.anuncios, required this.actividades, this.eventos = const [], required this.api, required this.registro, this.alIrAPestana}); // Constructor

  final List<Actividad> actividades; // Horario (para "Próximo culto")
  final List<Evento> eventos; // Eventos especiales (se muestran los 3 más cercanos)

  final void Function(int pestana)? alIrAPestana; // Cambiar de pestaña (accesos rápidos)

  final Iglesia iglesia; // Datos de la iglesia
  final bool avisoEnArea; // El aviso urgente tiene área y el teléfono está dentro
  final List<Anuncio> anuncios; // Anuncios vigentes (solo "Todos")
  final Api api; // Se pasa a la pantalla del video
  final RegistroDispositivo registro; // Se pasa a la pantalla del video

  Future<void> _abrirAfuera(BuildContext context, String enlace) async { // Abre YouTube o Google Maps (fuera de la app)
    final mensajero = ScaffoldMessenger.of(context); // Para avisar si falla (se toma antes de esperar)
    final abrio = await launchUrl(Uri.parse(enlace), mode: LaunchMode.externalApplication).catchError((_) => false); // Abre la app (YouTube/Maps) o el navegador
    if (!abrio) mensajero.showSnackBar(const SnackBar(content: Text('No se pudo abrir. Revisa tu conexión a internet.'))); // Aviso amable
  } // Fin de _abrirAfuera

  void _abrirEnVivo(BuildContext context) { // Abre la transmisión en vivo
    Navigator.push( // Abre el video encima
      context, // Desde aquí
      MaterialPageRoute(builder: (context) => PantallaVideo( // Pantalla del video
        api: api, // API
        registro: registro, // Registro del teléfono
        youtubeId: iglesia.enVivo.youtubeId!, // Video de la transmisión
        titulo: iglesia.enVivo.titulo ?? 'Transmisión en vivo', // Título (o uno genérico)
        subtitulo: iglesia.nombre, // Nombre de la iglesia
        enVivo: true, // Es en vivo: manda señales y muestra cuántos ven
        acciones: true, // Botones Pedir oración · Ofrendar · Compartir
        ofrendas: iglesia.ofrendas, // Para el botón Ofrendar
      )), // Fin de la ruta
    ); // Fin de Navigator.push
  } // Fin de _abrirEnVivo

  void _abrirHorario(BuildContext context) => Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaHorario(api: api))); // Horario de cultos (con flecha para volver)

  void _abrirRepeticion(BuildContext context, Repeticion repeticion) { // Abre la repetición del culto de hoy
    Navigator.push( // Abre el video encima
      context, // Desde aquí
      MaterialPageRoute(builder: (context) => PantallaVideo( // Pantalla del video
        api: api, // API
        registro: registro, // Registro del teléfono
        youtubeId: repeticion.youtubeId, // Video de la transmisión que terminó
        titulo: repeticion.titulo, // Título
        subtitulo: 'Repetición · ${iglesia.nombre}', // Aclara que ya no es en vivo
        acciones: true, // También con los botones
        ofrendas: iglesia.ofrendas, // Para el botón Ofrendar
      )), // Fin de la ruta
    ); // Fin de Navigator.push
  } // Fin de _abrirRepeticion

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    final aviso = iglesia.avisoUrgente; // Atajo
    final hayVideo = iglesia.enVivo.activo && iglesia.enVivo.youtubeId != null; // ¿Hay en vivo con video?
    return ListView( // Lista desplazable (necesaria para "jalar hacia abajo")
      padding: EdgeInsets.zero, // Sin margen: el encabezado llega hasta arriba (detrás de la hora)
      children: [ // Elementos
        _Encabezado(iglesia: iglesia), // Franja marino con logo, saludo, nombre y fecha
        Padding( // Contenido sobre el fondo claro
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), // Márgenes
          child: Column( // Uno debajo del otro
            crossAxisAlignment: CrossAxisAlignment.stretch, // Todo el ancho
            children: [ // Elementos
              if (aviso.activo && (aviso.area == null || avisoEnArea)) _AlertaAviso(aviso: aviso), // Aviso urgente: PRIMERO y con aspecto de alerta (fondo de color, borde e ícono)
              if (iglesia.enVivo.activo) // Si hay transmisión en vivo... (va ARRIBA, justo después de la alerta: se ve de inmediato)
                TarjetaCanaan( // ...tarjeta con franja ROJA
                  franja: context.vivo(Colors.red.shade700), // Rojo
                  alTocar: hayVideo ? () => _abrirEnVivo(context) : null, // Al tocar, abre el video
                  child: Column( // Uno debajo del otro
                    crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
                    children: [ // Elementos
                      Row( // Etiqueta "EN VIVO" y título
                        children: [ // Elementos
                          Container( // Etiqueta roja
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // Relleno
                            decoration: BoxDecoration(color: Colors.red.shade700, borderRadius: BorderRadius.circular(20)), // Roja redondeada
                            child: const Text('● EN VIVO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), // Texto
                          ), // Fin de la etiqueta
                          const SizedBox(width: 10), // Espacio
                          Expanded(child: Text(iglesia.enVivo.titulo ?? 'Transmisión en vivo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.cc.titulo))), // Título
                        ], // Fin de los elementos
                      ), // Fin de la fila
                      if (hayVideo) // Si tiene video...
                        Padding( // ...botón grande dorado
                          padding: const EdgeInsets.only(top: 12), // Separación
                          child: FilledButton.icon( // Botón relleno
                            style: FilledButton.styleFrom(backgroundColor: doradoCanaan, foregroundColor: marinoCanaan, minimumSize: const Size.fromHeight(52)), // Dorado, todo el ancho, alto 52
                            icon: const Icon(Icons.play_circle_fill, size: 26), // Ícono de reproducir
                            label: const Text('Ver transmisión', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), // Texto
                            onPressed: () => _abrirEnVivo(context), // Abre el video
                          ), // Fin del botón
                        ), // Fin del margen
                    ], // Fin de los elementos
                  ), // Fin de la columna
                ), // Fin de la tarjeta en vivo
              _AccesosRapidos( // Botones grandes con lo que NO está en el menú de abajo (Horario, Radio, Oración, YouTube, Cómo llegar)
                alHorario: () => _abrirHorario(context), // Abre el horario de cultos
                alRadio: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaRadio(api: api))), // Abre la radio
                alOracion: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaPeticion(api: api, registro: registro))), // Abre el formulario de petición
                alYoutube: iglesia.youtubeCanal == null ? null : () => _abrirAfuera(context, iglesia.youtubeCanal!), // Canal de YouTube (si el panel lo tiene)
                alComoLlegar: !iglesia.tieneUbicacion ? null : () => _abrirAfuera( // Google Maps con la ubicación del templo (si el panel la tiene)
                  context, // Para el mensaje de error
                  'https://www.google.com/maps/search/?api=1&query=${iglesia.latitud},${iglesia.longitud}', // Enlace universal de Google Maps (abre la app de Maps si está)
                ), // Fin de cómo llegar
              ), // Fin de los accesos rápidos
              _ProximoCulto(actividades: actividades, enVivoActivo: iglesia.enVivo.activo, mostrarCuenta: iglesia.cuentaRegresivaMostrar, horasCuenta: iglesia.cuentaRegresivaHoras, alTocar: () => _abrirHorario(context)), // Tarjeta "Próximo culto" con cuenta regresiva si se transmite (al tocar, abre Horario)
              if (iglesia.versiculo != null) _TarjetaVersiculo(versiculo: iglesia.versiculo!), // Versículo del día (se puede compartir)
              if (!iglesia.enVivo.activo && iglesia.repeticion != null && iglesia.repeticion!.youtubeId.isNotEmpty) // Si no hay en vivo pero hubo transmisión hace poco...
                _TarjetaRepeticion(repeticion: iglesia.repeticion!, alTocar: () => _abrirRepeticion(context, iglesia.repeticion!)), // ..."¿Te lo perdiste?"
              if (iglesia.radioDisponible) // Si la radio está al aire...
                TarjetaCanaan( // ...tarjeta con franja DORADA
                  franja: doradoCanaan, // Dorado
                  alTocar: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaRadio(api: api))), // Al tocar, abre la radio
                  child: Row( // Ícono y textos
                    children: [ // Elementos
                      Icon(Icons.headphones, color: context.cc.dorado, size: 30), // Audífonos
                      SizedBox(width: 12), // Espacio
                      Expanded(child: Text('🎧 Radio al aire · Escuchar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: context.cc.titulo))), // Texto
                      Icon(Icons.chevron_right, color: context.cc.tenue), // Flechita: se puede tocar
                    ], // Fin de los elementos
                  ), // Fin de la fila
                ), // Fin de la tarjeta de la radio
              if (!iglesia.enVivo.activo && !iglesia.radioDisponible && !aviso.activo && anuncios.isEmpty && eventos.isEmpty) // Si no hay nada que mostrar...
                Padding( // ...confirma que la conexión funciona
                  padding: EdgeInsets.only(top: 24), // Separación
                  child: Text('✓ Conectado con el panel', textAlign: TextAlign.center, style: TextStyle(color: context.cc.suave)), // Gris
                ), // Fin del texto
              CarruselAnuncios(anuncios: anuncios), // ANUNCIOS: tarjetas pequeñas que se deslizan de lado (al tocar, se abren completos)
              CarruselEventos(eventos: eventos, alVerTodos: alIrAPestana == null ? null : () => alIrAPestana!(3)), // PRÓXIMOS EVENTOS: su propia fila ("Ver todos" abre la pestaña Eventos)
            ], // Fin de los elementos
          ), // Fin de la columna
        ), // Fin del contenido
      ], // Fin de los elementos
    ); // Fin de la lista
  } // Fin de build
} // Fin de _DatosIglesia

class _Encabezado extends StatelessWidget { // Franja marino de arriba: logo, saludo, nombre y fecha (bordes de abajo redondeados)
  const _Encabezado({required this.iglesia}); // Constructor

  final Iglesia iglesia; // Datos de la iglesia

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Container( // Caja con degradado
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 22), // Deja espacio para la hora del teléfono
      decoration: const BoxDecoration( // Fondo
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [marinoCanaan, azulCanaan]), // Marino → azul
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)), // Bordes de abajo redondeados
      ), // Fin del fondo
      child: Row( // Logo a la izquierda y textos a la derecha
        children: [ // Elementos
          if (iglesia.logoUrl != null) // Si la iglesia subió un logo en el panel...
            ImagenGuardada(iglesia.logoUrl!, height: 52) // ...lo muestra (pequeño; guardado en el teléfono)
          else // Si no...
            Image.asset('assets/imagenes/canaan-icono.png', height: 52), // ...el ícono oficial dorado de Canaán (va dentro de la app)
          const SizedBox(width: 14), // Espacio
          Expanded( // El texto ocupa el resto del ancho
            child: Column( // Uno debajo del otro
              crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
              children: [ // Elementos
                Text(saludoSegunHora(DateTime.now()), style: const TextStyle(color: doradoCanaan, fontSize: 16, fontWeight: FontWeight.bold)), // "Buenos días"…
                Text(iglesia.nombre, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.2)), // Nombre de la iglesia
                Text(fechaLarga(DateTime.now()), style: const TextStyle(color: Colors.white70, fontSize: 15)), // "Jueves, 29 de octubre"
              ], // Fin de los elementos
            ), // Fin de la columna
          ), // Fin del Expanded
        ], // Fin de los elementos
      ), // Fin de la fila
    ); // Fin de la caja
  } // Fin de build
} // Fin de _Encabezado


class _AccesosRapidos extends StatelessWidget { // Tarjeta con botones grandes debajo del saludo (pensado para adultos mayores)
  const _AccesosRapidos({required this.alHorario, required this.alRadio, required this.alOracion, this.alYoutube, this.alComoLlegar}); // Constructor

  final VoidCallback alHorario; // Qué hacer al tocar Horario

  final VoidCallback alRadio; // Qué hacer al tocar Radio
  final VoidCallback alOracion; // Qué hacer al tocar Oración
  final VoidCallback? alYoutube; // Qué hacer al tocar YouTube (null = el panel no tiene canal: no se muestra)
  final VoidCallback? alComoLlegar; // Qué hacer al tocar Cómo llegar (null = sin ubicación del templo: no se muestra)

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    Widget boton(String texto, IconData icono, Color color, VoidCallback alTocar, {String? leer}) => Expanded( // Un botón (reparte el ancho); "leer" = lo que dicen los lectores de pantalla si es distinto del texto
          child: Semantics( // Para lectores de pantalla
          label: leer, // Texto más claro (si se dio)
          button: true, // Se puede tocar
          excludeSemantics: leer != null, // Si hay "leer", no repite el texto corto
          child: InkWell( // Efecto al tocar
            onTap: alTocar, // Qué hace
            borderRadius: BorderRadius.circular(12), // Efecto con esquinas redondeadas
            child: Padding( // Margen interno
              padding: const EdgeInsets.symmetric(vertical: 12), // Alto cómodo para tocar
              child: Column( // Ícono arriba, texto abajo
                children: [ // Elementos
                  Container( // Burbuja de color detrás del ícono
                    padding: const EdgeInsets.all(10), // Tamaño de la burbuja
                    decoration: BoxDecoration(color: context.vivo(color).withValues(alpha: context.alfaBurbuja), shape: BoxShape.circle), // Círculo del color, suave (más visible en modo oscuro)
                    child: Icon(icono, color: context.vivo(color), size: 28), // Ícono grande (más claro en modo oscuro)
                  ), // Fin de la burbuja
                  const SizedBox(height: 6), // Espacio
                  FittedBox( // Si no cabe (ej. letra grande), se achica un poco en vez de partirse: los 5 botones quedan parejos
                    fit: BoxFit.scaleDown, // Solo achica, nunca agranda
                    child: Text(texto, textAlign: TextAlign.center, maxLines: 1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.cc.titulo, height: 1.15)), // Texto en UN renglón
                  ), // Fin del ajuste
                ], // Fin de los elementos
              ), // Fin de la columna
            ), // Fin del margen
          ), // Fin del efecto
          ), // Fin de Semantics
        ); // Fin de boton
    return Card( // Tarjeta blanca
      margin: const EdgeInsets.only(top: 14), // Separación del encabezado
      child: Padding( // Margen interno
        padding: const EdgeInsets.symmetric(horizontal: 4), // Poco a los lados
        child: Row( // Los botones en fila
          children: [ // Botones
            boton('Horario', Icons.calendar_month, const Color(0xFF15803D), alHorario), // Horario de cultos (verde)
            boton('Radio', Icons.headphones, doradoOscuro, alRadio), // Radio (dorado)
            boton('Oración', Icons.volunteer_activism, const Color(0xFFB4235A), alOracion), // Petición de oración (vino)
            if (alYoutube != null) boton('YouTube', Icons.smart_display, const Color(0xFFDC2626), alYoutube!), // Canal de la iglesia (rojo YouTube)
            if (alComoLlegar != null) boton('Mapa', Icons.place, const Color(0xFF0E7490), alComoLlegar!, leer: 'Cómo llegar a la iglesia (mapa)'), // Google Maps (verde azulado: el verde es del Horario); "Mapa" cabe en un renglón ("Cómo llegar" se partía en dos)
          ], // Fin de los botones
        ), // Fin de la fila
      ), // Fin del margen
    ); // Fin de la tarjeta
  } // Fin de build
} // Fin de _AccesosRapidos

class _ProximoCulto extends StatefulWidget { // Tarjeta "Próximo culto": lo que está ocurriendo AHORA o lo siguiente del horario (con cuenta regresiva si se transmite)
  const _ProximoCulto({required this.actividades, required this.enVivoActivo, this.mostrarCuenta = true, this.horasCuenta = 2, required this.alTocar}); // Constructor

  final bool mostrarCuenta; // Configuración del panel: ¿mostrar la línea de la transmisión?
  final int horasCuenta; // Configuración del panel: la cuenta regresiva sale desde estas horas antes

  final List<Actividad> actividades; // Horario completo
  final bool enVivoActivo; // ¿Ya hay transmisión en vivo? (entonces no hace falta la cuenta regresiva)
  final VoidCallback alTocar; // Al tocar: abre la pestaña Horario

  @override // Reemplaza createState
  State<_ProximoCulto> createState() => _ProximoCultoState(); // Crea el estado
} // Fin de _ProximoCulto

class _ProximoCultoState extends State<_ProximoCulto> { // Estado: un reloj redibuja la cuenta regresiva
  static const _verde = Color(0xFF15803D); // Verde (igual que "Ahora" en Horario)
  Timer? _reloj; // Redibuja cada 30 s (para que "faltan 15 min" baje sola)

  @override // Reemplaza initState
  void initState() { // Al aparecer
    super.initState(); // Lo de Flutter por defecto
    _reloj = Timer.periodic(const Duration(seconds: 30), (_) { if (mounted) setState(() {}); }); // Cada 30 s, vuelve a calcular
  } // Fin de initState

  @override // Reemplaza dispose
  void dispose() { // Al quitarse
    _reloj?.cancel(); // Detiene el reloj
    super.dispose(); // Lo de Flutter por defecto
  } // Fin de dispose

  String? _cuentaRegresiva(Actividad actividad) { // Texto rojo de la transmisión; null si no se transmite o ya está en vivo
    if (!actividad.seTransmite || widget.enVivoActivo || !widget.mostrarCuenta) return null; // Sin transmisión, ya en vivo (la tarjeta roja lo muestra) o el panel no la quiere
    if (actividad.enCurso) return 'La transmisión aparecerá aquí al empezar'; // Ya es la hora, pero YouTube aún no empieza
    final falta = actividad.proxima!.difference(DateTime.now()); // Tiempo que falta
    if (falta.inMinutes >= widget.horasCuenta * 60) return 'Se transmite en vivo en la app'; // Todavía lejos (según Configuración): solo avisa que se transmite
    if (falta.inMinutes < 1) return 'En vivo en un momento'; // Ya casi
    final horas = falta.inHours; // Horas completas
    final minutos = falta.inMinutes % 60; // Minutos sobrantes
    const nb = '\u00A0'; // Espacio que NO se corta (así "5 h 12 min" nunca se parte en dos renglones)
    final texto = horas > 0 ? '$horas${nb}h${minutos > 0 ? '$nb$minutos${nb}min' : ''}' : '$minutos${nb}min'; // "2 h 15 min" o "15 min"
    return 'En vivo en la app · faltan $texto'; // Ej: "En vivo en la app · faltan 2 h 15 min"
  } // Fin de _cuentaRegresiva

  String _cuando(DateTime fecha) { // "Hoy", "Mañana" o el día de la semana, ej: "Domingo"
    final hoy = DateTime.now(); // Ahora
    final dias = DateTime(fecha.year, fecha.month, fecha.day).difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays; // Días de diferencia (solo fechas)
    if (dias == 0) return 'Hoy'; // Hoy
    if (dias == 1) return 'Mañana'; // Mañana
    return fechaLarga(fecha).split(',').first; // Ej: "Domingo" (de "Domingo, 1 de noviembre")
  } // Fin de _cuando

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    final actividades = widget.actividades; // Atajo
    final ahora = actividades.where((a) => a.enCurso).toList(); // Las que están ocurriendo
    final siguientes = actividades.where((a) => !a.enCurso && a.proxima != null).toList()..sort((a, b) => a.proxima!.compareTo(b.proxima!)); // Las demás, de la más cercana a la más lejana
    final actividad = ahora.isNotEmpty ? ahora.first : (siguientes.isNotEmpty ? siguientes.first : null); // La que se muestra
    if (actividad == null) return const SizedBox.shrink(); // Sin horario: no se muestra la tarjeta
    final enCurso = actividad.enCurso; // ¿Es ahora?
    final cuando = enCurso ? 'Ahora' : _cuando(actividad.proxima!); // "Ahora", "Hoy", "Mañana" o el día
    final regresiva = _cuentaRegresiva(actividad); // Cuenta regresiva (o null)
    final detalle = [actividad.horario, actividad.lugar].where((t) => t != null && t.isNotEmpty).join(' · '); // "7:00 pm – 8:30 pm · Templo principal"
    return TarjetaCanaan( // Tarjeta con franja verde
      franja: context.vivo(_verde), // Verde
      alTocar: widget.alTocar, // Abre Horario
      child: Row( // Ícono, textos y flechita
        children: [ // Elementos
          Icon(Icons.event_available, color: context.vivo(_verde), size: 30), // Calendario con palomita
          const SizedBox(width: 12), // Espacio
          Expanded( // Textos
            child: Column( // Uno debajo del otro
              crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
              children: [ // Elementos
                Text(enCurso ? 'AHORA EN LA IGLESIA' : 'PRÓXIMO CULTO', style: TextStyle(color: context.vivo(_verde), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)), // Encabezado pequeño
                const SizedBox(height: 2), // Espacio
                Text('$cuando · ${actividad.nombre}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.cc.titulo)), // "Hoy · Culto de oración"
                if (detalle.isNotEmpty) Text(detalle, style: TextStyle(fontSize: 15, color: context.cc.suave)), // Hora y lugar
                if (regresiva != null) // Si se transmite...
                  Padding( // ...línea roja con la cuenta regresiva
                    padding: const EdgeInsets.only(top: 6), // Separación
                    child: Row( // Ícono rojo y texto
                      children: [ // Elementos
                        Icon(Icons.live_tv, color: context.vivo(Colors.red.shade700), size: 18), // Televisor rojo
                        const SizedBox(width: 6), // Espacio
                        Expanded(child: Text(regresiva, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.vivo(Colors.red.shade700)))), // "En vivo en la app · faltan 2 h"
                      ], // Fin de los elementos
                    ), // Fin de la fila
                  ), // Fin del margen
              ], // Fin de los elementos
            ), // Fin de la columna
          ), // Fin de los textos
          Icon(Icons.chevron_right, color: context.cc.tenue), // Flechita: se puede tocar
        ], // Fin de los elementos
      ), // Fin de la fila
    ); // Fin de la tarjeta
  } // Fin de build
} // Fin de _ProximoCultoState

class _TarjetaRepeticion extends StatelessWidget { // "¿Te lo perdiste? Mira el culto de hoy" (después del en vivo, por 12 h)
  const _TarjetaRepeticion({required this.repeticion, required this.alTocar}); // Constructor

  final Repeticion repeticion; // Transmisión que terminó
  final VoidCallback alTocar; // Abre el video

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return TarjetaCanaan( // Tarjeta con franja AZUL
      franja: azulCanaan, // Azul
      alTocar: alTocar, // Abre el video
      child: Column( // Uno debajo del otro
        crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
        children: [ // Elementos
          Text('¿TE LO PERDISTE?', style: TextStyle(color: context.cc.azul, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)), // Encabezado pequeño
          const SizedBox(height: 2), // Espacio
          Text('Mira el culto de hoy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.cc.titulo)), // Invitación
          Text(repeticion.titulo, style: TextStyle(fontSize: 15, color: context.cc.suave)), // Título de la transmisión
          const SizedBox(height: 12), // Espacio
          FilledButton.icon( // Botón grande
            style: FilledButton.styleFrom(backgroundColor: azulCanaan, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(50)), // Azul, todo el ancho
            icon: const Icon(Icons.replay, size: 24), // Ícono de repetir
            label: const Text('Ver repetición', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), // Texto
            onPressed: alTocar, // Abre el video
          ), // Fin del botón
        ], // Fin de los elementos
      ), // Fin de la columna
    ); // Fin de la tarjeta
  } // Fin de build
} // Fin de _TarjetaRepeticion

class _AlertaAviso extends StatelessWidget { // Aviso urgente con aspecto de ALERTA (no de anuncio): fondo de color, borde, ícono fuerte y etiqueta
  const _AlertaAviso({required this.aviso}); // Constructor

  final AvisoUrgente aviso; // Datos del aviso

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    final (Color fuerte, Color fondo, IconData icono, String etiqueta) = switch (aviso.nivel) { // Estilo según el nivel (igual que el panel)
      'urgente' => (const Color(0xFFC62828), const Color(0xFFFDECEC), Icons.warning_rounded, 'AVISO URGENTE'), // Rojo
      'importante' => (const Color(0xFFB45309), const Color(0xFFFFF4DB), Icons.priority_high_rounded, 'IMPORTANTE'), // Ámbar
      _ => (azulCanaan, const Color(0xFFE8F1FA), Icons.info_rounded, 'AVISO'), // Informativo: azul
    }; // Fin del estilo
    final oscuro = Theme.of(context).brightness == Brightness.dark; // ¿Modo oscuro?
    final borde = oscuro ? context.vivo(fuerte) : fuerte; // En oscuro, el color más vivo (se distingue sobre el fondo oscuro)
    final fondoCaja = oscuro ? Color.alphaBlend(fuerte.withValues(alpha: 0.28), context.cc.tarjeta) : fondo; // En oscuro: fondo oscuro teñido del color (antes era claro y encandilaba)
    final colorTitulo = oscuro ? context.cc.titulo : const Color(0xFF1F2937); // Título: claro en oscuro, casi negro en claro
    final colorMensaje = oscuro ? context.cc.texto : const Color(0xFF374151); // Mensaje: igual
    return Semantics( // Para lectores de pantalla: se anuncia como alerta
      liveRegion: true, // Lo lee en voz alta al aparecer
      label: '$etiqueta: ${aviso.titulo ?? ''}. ${aviso.mensaje ?? ''}', // Texto completo
      excludeSemantics: true, // No repite cada parte
      child: Container( // Caja de la alerta
        margin: const EdgeInsets.only(top: 14), // Separación del encabezado
        padding: const EdgeInsets.all(16), // Margen interno
        decoration: BoxDecoration( // Aspecto
          color: fondoCaja, // Fondo de color suave (oscuro teñido en modo oscuro)
          borderRadius: BorderRadius.circular(16), // Esquinas redondeadas
          border: Border.all(color: borde, width: 2), // Borde del color fuerte
          boxShadow: [BoxShadow(color: fuerte.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4))], // Sombra del mismo color (resalta)
        ), // Fin del aspecto
        child: Row( // Ícono a la izquierda y textos a la derecha
          crossAxisAlignment: CrossAxisAlignment.start, // Arriba
          children: [ // Elementos
            Container( // Círculo de color fuerte con el ícono blanco
              padding: const EdgeInsets.all(10), // Tamaño del círculo
              decoration: BoxDecoration(color: fuerte, shape: BoxShape.circle), // Círculo
              child: Icon(icono, color: Colors.white, size: 30), // Ícono grande blanco
            ), // Fin del círculo
            const SizedBox(width: 14), // Espacio
            Expanded( // Textos
              child: Column( // Uno debajo del otro
                crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
                children: [ // Elementos
                  Text(etiqueta, style: TextStyle(color: borde, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.3)), // "AVISO URGENTE"
                  const SizedBox(height: 2), // Espacio
                  Text(aviso.titulo ?? 'Aviso', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorTitulo, height: 1.2)), // Título grande
                  if ((aviso.mensaje ?? '').isNotEmpty) ...[ // Si tiene mensaje...
                    const SizedBox(height: 6), // Espacio
                    Text(aviso.mensaje!, style: TextStyle(fontSize: 16, color: colorMensaje, height: 1.35)), // ...el mensaje
                  ], // Fin del mensaje
                ], // Fin de los elementos
              ), // Fin de la columna
            ), // Fin de los textos
          ], // Fin de los elementos
        ), // Fin de la fila
      ), // Fin de la caja
    ); // Fin de Semantics
  } // Fin de build
} // Fin de _AlertaAviso

class _TarjetaVersiculo extends StatelessWidget { // Versículo del día (franja dorada, letra un poco más grande, botón Compartir)
  const _TarjetaVersiculo({required this.versiculo}); // Constructor

  final VersiculoDia versiculo; // Texto y cita

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return TarjetaCanaan( // Tarjeta con franja dorada
      franja: doradoCanaan, // Dorado
      child: Column( // Uno debajo del otro
        crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
        children: [ // Elementos
          Row( // Encabezado
            children: [ // Elementos
              Icon(Icons.auto_stories, color: context.cc.dorado, size: 22), // Libro abierto
              SizedBox(width: 8), // Espacio
              Text('VERSÍCULO DEL DÍA', style: TextStyle(color: context.cc.dorado, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)), // Título pequeño
            ], // Fin de los elementos
          ), // Fin del encabezado
          const SizedBox(height: 8), // Espacio
          Text('“${versiculo.texto}”', style: TextStyle(fontSize: 18, height: 1.45, fontStyle: FontStyle.italic, color: context.cc.texto)), // Texto entre comillas
          const SizedBox(height: 6), // Espacio
          Row( // Cita y botón
            children: [ // Elementos
              Expanded(child: Text(versiculo.referencia, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.cc.titulo))), // "Juan 3:16"
              TextButton.icon( // Compartir
                onPressed: () => Compartir.texto('📖 “${versiculo.texto}”\n${versiculo.referencia}'), // Comparte
                icon: const Icon(Icons.share, size: 20), // Ícono
                label: const Text('Compartir', style: TextStyle(fontSize: 15)), // Texto
              ), // Fin del botón
            ], // Fin de los elementos
          ), // Fin de la fila
        ], // Fin de los elementos
      ), // Fin de la columna
    ); // Fin de la tarjeta
  } // Fin de build
} // Fin de _TarjetaVersiculo
