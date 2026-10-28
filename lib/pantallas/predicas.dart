import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../componentes/estados.dart'; // Vistas compartidas: Cargando, ErrorConexion, Vacio
import '../modelos/predica.dart'; // Molde de una prédica
import '../servicios/api.dart'; // Llamadas a la API
import '../tema.dart'; // Colores y fechaCorta()

class PantallaPredicas extends StatefulWidget { // Pestaña "Prédicas"
  const PantallaPredicas({super.key, required this.api}); // Constructor: recibe la API

  final Api api; // De dónde se sacan los datos

  @override // Reemplaza createState
  State<PantallaPredicas> createState() => _PantallaPredicasState(); // Crea el estado
} // Fin de PantallaPredicas

class _PantallaPredicasState extends State<PantallaPredicas> { // Estado de la pestaña Prédicas
  late Future<List<Predica>> _peticion; // Petición en curso
  String _buscar = ''; // Texto escrito en el buscador

  @override // Reemplaza initState
  void initState() { // Al abrir la pestaña por primera vez
    super.initState(); // Lo de Flutter por defecto
    _peticion = widget.api.obtenerPredicas(); // Pide la lista completa
  } // Fin de initState

  Future<void> _recargar() async { // Vuelve a pedir la lista (con el texto buscado)
    setState(() => _peticion = widget.api.obtenerPredicas(buscar: _buscar)); // Nueva petición y redibuja
    try { await _peticion; } catch (_) {} // Espera a que termine (el error lo muestra el FutureBuilder)
  } // Fin de _recargar

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
              onSubmitted: (texto) { // Al pulsar Enter / Buscar...
                _buscar = texto; // ...guarda el texto...
                _recargar(); // ...y vuelve a pedir la lista filtrada
              }, // Fin de onSubmitted
            ), // Fin del buscador
          ), // Fin del margen
          Expanded( // La lista ocupa el resto del alto
            child: FutureBuilder<List<Predica>>( // Dibuja según el estado de la petición
              future: _peticion, // Petición que vigila
              builder: (context, estado) { // Se llama cada vez que cambia
                if (estado.connectionState != ConnectionState.done) return const Cargando(); // Esperando
                if (estado.hasError) return ErrorConexion(alReintentar: _recargar); // Falló
                final predicas = estado.data!; // Lista recibida
                return RefreshIndicator( // "Jalar hacia abajo" para actualizar
                  onRefresh: _recargar, // Qué hacer al jalar
                  child: predicas.isEmpty // ¿Está vacía?
                      ? Vacio( // Sí: mensaje
                          icono: Icons.video_library_outlined, // Ícono de videos
                          mensaje: _buscar.isEmpty ? 'Aún no hay prédicas publicadas.' : 'No encontramos prédicas con “$_buscar”.', // Mensaje según si buscó
                        ) // Fin de Vacio
                      : ListView.builder( // No: lista (builder = solo dibuja las que se ven, más rápido)
                          padding: const EdgeInsets.all(12), // Margen
                          itemCount: predicas.length, // Cuántas hay
                          itemBuilder: (context, i) => _TarjetaPredica(predica: predicas[i]), // Dibuja la tarjeta número i
                        ), // Fin de la lista
                ); // Fin de RefreshIndicator
              }, // Fin de builder
            ), // Fin de FutureBuilder
          ), // Fin de Expanded
        ], // Fin de los elementos
      ), // Fin de la columna
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de _PantallaPredicasState

class _TarjetaPredica extends StatelessWidget { // Tarjeta de una prédica en la lista
  const _TarjetaPredica({required this.predica}); // Constructor

  final Predica predica; // Datos de la prédica

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
            Text(_subtitulo(), style: const TextStyle(color: Colors.black54)), // Predicador · fecha
            const SizedBox(height: 16), // Espacio
            Text(predica.descripcion ?? 'Sin descripción.'), // Descripción
            const SizedBox(height: 16), // Espacio
            const Text( // Aviso temporal
              'El reproductor de video llegará en un próximo paso.', // Se hará con el reproductor de YouTube
              style: TextStyle(color: Colors.black45, fontStyle: FontStyle.italic), // Gris y en cursiva
            ), // Fin del aviso
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
        onTap: () => _verDetalle(context), // Al tocar, muestra el detalle
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
                  if (predica.destacada) // Si es la destacada...
                    const Text('★ DESTACADA', style: TextStyle(color: Color(0xFFB07A00), fontWeight: FontWeight.bold, fontSize: 12)), // ...etiqueta dorada oscura (legible sobre blanco)
                  Text(predica.titulo, style: Theme.of(context).textTheme.titleMedium), // Título
                  const SizedBox(height: 2), // Espacio
                  Text(_subtitulo(), style: const TextStyle(color: Colors.black54)), // Predicador · fecha
                  if (predica.reproducciones > 0) // Si alguien la ha visto...
                    Text('${predica.reproducciones} vistas', style: const TextStyle(color: Colors.black45, fontSize: 12)), // ...cuántas veces
                ], // Fin de los elementos
              ), // Fin de la columna
            ), // Fin del margen
          ], // Fin de los elementos
        ), // Fin de la columna
      ), // Fin de InkWell
    ); // Fin de la tarjeta
  } // Fin de build
} // Fin de _TarjetaPredica
