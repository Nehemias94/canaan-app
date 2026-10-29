import 'dart:async'; // Timer (actualizar cada 90 s)

import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../componentes/estados.dart'; // Vistas compartidas: Cargando, ErrorConexion, Vacio
import '../modelos/predica.dart'; // Molde de una prédica
import '../config.dart'; // intervaloActualizacion (90 s)
import '../servicios/api.dart'; // Llamadas a la API
import '../servicios/recarga.dart'; // Timbre "recargarPredicas" (al tocar la pestaña)
import '../servicios/registro.dart'; // Registro del teléfono (para contar las vistas)
import '../servicios/compartir.dart'; // Compartir la prédica
import '../tema.dart'; // Colores y fechaCorta()
import 'video.dart'; // Pantalla del video

class PantallaPredicas extends StatefulWidget { // Pestaña "Prédicas"
  const PantallaPredicas({super.key, required this.api, required this.registro}); // Constructor: recibe la API y el registro

  final Api api; // De dónde se sacan los datos
  final RegistroDispositivo registro; // Para contar las vistas

  @override // Reemplaza createState
  State<PantallaPredicas> createState() => _PantallaPredicasState(); // Crea el estado
} // Fin de PantallaPredicas

class _PantallaPredicasState extends State<PantallaPredicas> with WidgetsBindingObserver { // Estado; "WidgetsBindingObserver" = se entera cuando la app vuelve a primer plano
  List<Predica>? _predicas; // Prédicas recibidas (null = cargando: primera vez o búsqueda nueva)
  bool _fallo = false; // true si falló y no hay nada que mostrar
  String _buscar = ''; // Texto escrito en el buscador
  List<SerieResumen> _series = []; // Series para los botones de filtro
  int? _serie; // Serie elegida (null = todas)
  Timer? _reloj; // Reloj que vuelve a preguntar cada 90 s

  @override // Reemplaza initState
  void initState() { // Al abrir la app (la pestaña se crea junto con las demás)
    super.initState(); // Lo de Flutter por defecto
    WidgetsBinding.instance.addObserver(this); // Escucha cuando la app vuelve a primer plano
    recargarPredicas.addListener(_cargar); // Al tocar la pestaña Prédicas, actualiza
    _reloj = Timer.periodic(intervaloActualizacion, (_) => _cargar()); // Cada 90 s, en silencio
    _cargar(); // Primera carga
  } // Fin de initState

  @override // Reemplaza dispose
  void dispose() { // Al cerrar
    WidgetsBinding.instance.removeObserver(this); // Deja de escuchar la app
    recargarPredicas.removeListener(_cargar); // Deja de escuchar el timbre
    _reloj?.cancel(); // Detiene el reloj
    super.dispose(); // Lo de Flutter por defecto
  } // Fin de dispose

  @override // Reemplaza didChangeAppLifecycleState
  void didChangeAppLifecycleState(AppLifecycleState estado) { // La app cambió de estado
    if (estado == AppLifecycleState.resumed) _cargar(); // Volvió a primer plano: actualiza
  } // Fin de didChangeAppLifecycleState

  Future<void> _cargar() async { // Pide las prédicas (con lo buscado) sin mostrar "cargando": la lista se cambia cuando llegan
    final buscado = _buscar; // Texto de esta petición (si la persona busca otra cosa mientras tanto, esta respuesta se descarta)
    final serie = _serie; // Serie de esta petición (igual)
    widget.api.obtenerSeries().then((s) { if (mounted) setState(() => _series = s); }).catchError((_) {}); // Series para los filtros (si falla, sin botones)
    try { // Intenta
      final predicas = await widget.api.obtenerPredicas(buscar: buscado, serieId: serie); // Petición
      if (mounted && buscado == _buscar && serie == _serie) setState(() { _predicas = predicas; _fallo = false; }); // Redibuja con lo nuevo
    } catch (_) { // Sin internet, servidor dormido…
      if (mounted && _predicas == null) setState(() => _fallo = true); // Solo muestra el error si no había nada en pantalla
    } // Fin del try
  } // Fin de _cargar

  void _elegirSerie(int? serie) { // Toca un botón de serie ("Todas" = null)
    setState(() { _serie = serie; _predicas = null; _fallo = false; }); // Limpia la lista y guarda la serie
    _cargar(); // Pide la lista de esa serie
  } // Fin de _elegirSerie

  void _buscarTexto(String texto) { // Búsqueda nueva: aquí SÍ se muestra "cargando" (la persona lo pidió)
    setState(() { _buscar = texto.trim(); _predicas = null; _fallo = false; }); // Limpia la lista y guarda el texto
    _cargar(); // Pide la lista filtrada
  } // Fin de _buscarTexto

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Scaffold( // Estructura de la pantalla
      appBar: AppBar(title: const Text('Prédicas')), // Barra de título marino
      body: Column( // Buscador arriba y lista abajo
        children: [ // Elementos
          Padding( // Margen alrededor del buscador
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), // Izquierda, arriba, derecha, abajo
            child: TextField( // Caja de texto para buscar
              decoration: const InputDecoration( // Apariencia
                hintText: 'Buscar por título, predicador o tema', // Texto de ayuda gris
                prefixIcon: Icon(Icons.search), // Lupa a la izquierda
                border: OutlineInputBorder(), // Borde alrededor
                isDense: true, // Un poco más compacta
              ), // Fin de la apariencia
              textInputAction: TextInputAction.search, // En el teclado del teléfono sale el botón "Buscar"
              onSubmitted: _buscarTexto, // Al pulsar Enter / Buscar: pide la lista filtrada
            ), // Fin del buscador
          ), // Fin del margen
          if (_series.isNotEmpty) // Si hay series...
            SizedBox( // ...fila de botones de filtro
              height: 48, // Alto
              child: ListView( // Se desliza de lado
                scrollDirection: Axis.horizontal, // Horizontal
                padding: const EdgeInsets.symmetric(horizontal: 12), // Márgenes
                children: [ // Botones
                  Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: const Text('Todas'), selected: _serie == null, onSelected: (_) => _elegirSerie(null))), // Todas
                  for (final s in _series) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text('📚 ${s.nombre}'), selected: _serie == s.id, onSelected: (_) => _elegirSerie(s.id))), // Una por serie
                ], // Fin de los botones
              ), // Fin de la fila
            ), // Fin del filtro
          Expanded( // La lista ocupa el resto del alto
            child: _predicas == null // ¿Todavía no hay datos?
                ? (_fallo ? ErrorConexion(alReintentar: () => _buscarTexto(_buscar)) : const Cargando()) // Error o esperando
                : RefreshIndicator( // "Jalar hacia abajo" para actualizar
                    onRefresh: _cargar, // Qué hacer al jalar
                    child: _predicas!.isEmpty // ¿Está vacía?
                        ? Vacio( // Sí: mensaje
                            icono: Icons.video_library_outlined, // Ícono de videos
                            mensaje: _buscar.isEmpty ? 'Aún no hay prédicas publicadas.' : 'No encontramos prédicas con “$_buscar”.', // Mensaje según si buscó
                          ) // Fin de Vacio
                        : ListView.builder( // No: lista (builder = solo dibuja las que se ven, más rápido)
                            padding: const EdgeInsets.all(12), // Margen
                            itemCount: _predicas!.length, // Cuántas hay
                            itemBuilder: (context, i) => _TarjetaPredica(key: ValueKey('predica-${_predicas![i].id}'), predica: _predicas![i], api: widget.api, registro: widget.registro), // Dibuja la tarjeta número i
                          ), // Fin de la lista
                  ), // Fin de RefreshIndicator
          ), // Fin de Expanded
        ], // Fin de los elementos
      ), // Fin de la columna
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de _PantallaPredicasState

class _TarjetaPredica extends StatelessWidget { // Tarjeta de una prédica en la lista
  const _TarjetaPredica({super.key, required this.predica, required this.api, required this.registro}); // Constructor

  final Predica predica; // Datos de la prédica
  final Api api; // Se pasa a la pantalla del video
  final RegistroDispositivo registro; // Se pasa a la pantalla del video

  void _abrir(BuildContext context) { // Al tocar la tarjeta
    if (predica.youtubeId == null) return _verDetalle(context); // Sin video: solo muestra la descripción
    Navigator.push( // Con video: abre el reproductor encima
      context, // Desde aquí
      MaterialPageRoute(builder: (context) => PantallaVideo( // Pantalla del video
        api: api, // API
        registro: registro, // Registro del teléfono
        youtubeId: predica.youtubeId!, // Video
        titulo: predica.titulo, // Título
        subtitulo: _subtitulo(), // Predicador · fecha
        descripcion: predica.descripcion, // Descripción
        predicaId: predica.id, // Para contar la vista
        predica: predica, // Bosquejo y siguiente parte de la serie
      )), // Fin de la ruta
    ); // Fin de Navigator.push
  } // Fin de _abrir

  void _verDetalle(BuildContext context) { // Muestra el detalle en una hoja que sube desde abajo
    showModalBottomSheet( // Hoja inferior
      context: context, // Dónde mostrarla
      isScrollControlled: true, // Puede ocupar más de media pantalla si el texto es largo
      showDragHandle: true, // Rayita arriba para arrastrar y cerrar
      builder: (context) => Padding( // Contenido de la hoja
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), // Margen
        child: Column( // Elementos uno debajo del otro
          mainAxisSize: MainAxisSize.min, // Ocupa solo lo necesario
          crossAxisAlignment: CrossAxisAlignment.start, // Alineados a la izquierda
          children: [ // Elementos
            Text(predica.titulo, style: Theme.of(context).textTheme.titleLarge), // Título grande
            const SizedBox(height: 4), // Espacio
            Text(_subtitulo(), style: TextStyle(color: context.cc.suave)), // Predicador · fecha
            const SizedBox(height: 16), // Espacio
            Text(predica.descripcion ?? 'Sin descripción.'), // Descripción
          ], // Fin de los elementos
        ), // Fin de la columna
      ), // Fin del contenido
    ); // Fin de la hoja
  } // Fin de _verDetalle

  String _subtitulo() { // Arma "Predicador · 5 oct 2026" con lo que haya
    return [predica.predicador, fechaCorta(predica.fecha)] // Las dos partes...
        .where((parte) => parte != null && parte.isNotEmpty) // ...quita las vacías...
        .join(' · '); // ...y las une con un punto medio
  } // Fin de _subtitulo

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Card( // Tarjeta con sombra suave
      clipBehavior: Clip.antiAlias, // Recorta la imagen con las esquinas redondeadas de la tarjeta
      shape: predica.destacada // ¿Es la destacada?
          ? RoundedRectangleBorder(side: const BorderSide(color: doradoCanaan, width: 2), borderRadius: BorderRadius.circular(12)) // Sí: borde dorado
          : null, // No: borde normal
      child: InkWell( // Hace que la tarjeta reaccione al toque (efecto de onda)
        onTap: () => _abrir(context), // Al tocar: abre el video (o la descripción si no tiene video)
        child: Column( // Imagen arriba y textos abajo
          crossAxisAlignment: CrossAxisAlignment.start, // Alineados a la izquierda
          children: [ // Elementos
            if (predica.miniaturaUrl != null) // Si hay miniatura del video...
              AspectRatio( // ...con proporción de video 16:9
                aspectRatio: 16 / 9, // Ancho : alto
                child: Image.network( // Imagen descargada de internet
                  predica.miniaturaUrl!, // Enlace de la miniatura
                  fit: BoxFit.cover, // Llena el espacio recortando lo que sobre
                  errorBuilder: (context, error, pila) => Container(color: Colors.black12), // Si no carga, un recuadro gris
                ), // Fin de la imagen
              ), // Fin de AspectRatio
            Padding( // Margen de los textos
              padding: const EdgeInsets.all(12), // 12 puntos por lado
              child: Column( // Textos uno debajo del otro
                crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
                children: [ // Elementos
                  if (predica.serieNombre != null) // Si es parte de una serie...
                    Padding(padding: const EdgeInsets.only(bottom: 2), child: Text('📚 ${predica.serieNombre}${predica.serieParte != null ? ' · Parte ${predica.serieParte}${predica.serieTotal > 1 ? ' de ${predica.serieTotal}' : ''}' : ''}', style: TextStyle(color: context.cc.azul, fontWeight: FontWeight.w600, fontSize: 13))), // "📚 La familia · Parte 2 de 4"
                  if (predica.destacada) // Si es la destacada...
                    const Text('★ DESTACADA', style: TextStyle(color: Color(0xFFB07A00), fontWeight: FontWeight.bold, fontSize: 12)), // ...etiqueta dorada oscura (legible sobre blanco)
                  Row( // Título y botón compartir
                    crossAxisAlignment: CrossAxisAlignment.start, // Arriba
                    children: [ // Elementos
                      Expanded(child: Text(predica.titulo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.cc.titulo))), // Título en negrita marino (igual que los anuncios de Inicio)
                      IconButton( // Compartir
                        tooltip: 'Compartir prédica', // Texto de ayuda
                        visualDensity: VisualDensity.compact, // Compacto
                        icon: Icon(Icons.share, color: context.cc.azul), // Ícono
                        onPressed: () => Compartir.texto([ // Título, predicador y enlace de YouTube
                          '🎥 ${predica.titulo}', // Título
                          if (_subtitulo().isNotEmpty) _subtitulo(), // Predicador · fecha
                          if (predica.youtubeId != null) 'https://www.youtube.com/watch?v=${predica.youtubeId}', // Enlace del video
                        ].join('\n')), // Fin del texto
                      ), // Fin del botón
                    ], // Fin de los elementos
                  ), // Fin de la fila
                  const SizedBox(height: 2), // Espacio
                  Text(_subtitulo(), style: TextStyle(color: context.cc.suave)), // Predicador · fecha
                  if (predica.reproducciones > 0) // Si alguien la ha visto...
                    Text('${predica.reproducciones} vistas', style: TextStyle(color: context.cc.suave, fontSize: 12)), // ...cuántas veces
                ], // Fin de los elementos
              ), // Fin de la columna
            ), // Fin del margen
          ], // Fin de los elementos
        ), // Fin de la columna
      ), // Fin de InkWell
    ); // Fin de la tarjeta
  } // Fin de build
} // Fin de _TarjetaPredica
