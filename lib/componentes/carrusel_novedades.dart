import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../modelos/anuncio.dart'; // Molde de un anuncio
import '../modelos/evento.dart'; // Molde de un evento
import '../pantallas/anuncio.dart'; // Detalle del anuncio
import '../pantallas/evento.dart'; // Detalle del evento
import '../pantallas/novedades.dart'; // "Ver todo"
import '../tema.dart'; // Colores de Canaán
import 'tarjeta_anuncio.dart'; // fechasDeAnuncio()
import 'tarjeta_evento.dart'; // moradoEvento

// "NOVEDADES" de Inicio: anuncios y eventos juntos en UNA fila de tarjetas pequeñas que se deslizan de lado.
// Cada tarjeta muestra el flyer (o un bloque de color), si es anuncio o evento, la fecha y el título.
// Al tocarla se abre completa. Así Inicio queda corto y ordenado.

class _Novedad { // Una tarjeta del carrusel (sirve igual para anuncio o evento)
  const _Novedad({required this.titulo, required this.etiqueta, required this.fecha, required this.color, required this.icono, this.imagenUrl, required this.abrir}); // Constructor

  final String titulo; // Título
  final String etiqueta; // "ANUNCIO" o "EVENTO"
  final String fecha; // Cuándo
  final Color color; // Azul (anuncio) o morado (evento)
  final IconData icono; // Megáfono o celebración
  final String? imagenUrl; // Flyer (null = bloque de color)
  final Widget Function() abrir; // Pantalla que se abre al tocarla
} // Fin de _Novedad

class CarruselNovedades extends StatefulWidget { // Sección "NOVEDADES" con el carrusel
  const CarruselNovedades({super.key, required this.anuncios, required this.eventos}); // Constructor

  final List<Anuncio> anuncios; // Anuncios vigentes ("Todos")
  final List<Evento> eventos; // Próximos eventos

  static const int maxEventos = 5; // Eventos que caben en el carrusel (los demás, en "Ver todo" o en la pestaña Eventos)

  @override // Reemplaza createState
  State<CarruselNovedades> createState() => _CarruselNovedadesState(); // Crea el estado
} // Fin de CarruselNovedades

class _CarruselNovedadesState extends State<CarruselNovedades> { // Estado: qué tarjeta se está viendo (para los puntitos)
  final _control = PageController(viewportFraction: 0.86); // Cada tarjeta ocupa el 86 %: se asoma la siguiente (así se nota que se desliza)
  int _actual = 0; // Tarjeta que se ve ahora

  @override // Reemplaza dispose
  void dispose() { // Al cerrar la pantalla
    _control.dispose(); // Libera el control
    super.dispose(); // Limpieza normal
  } // Fin de dispose

  List<_Novedad> _novedades() => [ // Arma la lista: primero los anuncios, después los eventos
        for (final a in widget.anuncios) // Cada anuncio
          _Novedad(titulo: a.titulo, etiqueta: 'ANUNCIO', fecha: fechasDeAnuncio(a), color: azulCanaan, icono: Icons.campaign_outlined, imagenUrl: a.imagenUrl, abrir: () => PantallaAnuncio(anuncio: a)), // Azul con megáfono
        for (final e in widget.eventos.take(CarruselNovedades.maxEventos)) // Los eventos más cercanos
          _Novedad(titulo: e.titulo, etiqueta: 'EVENTO', fecha: e.enCurso ? '● AHORA' : e.cuandoTexto(), color: moradoEvento, icono: Icons.celebration_outlined, imagenUrl: e.imagenUrl, abrir: () => PantallaEvento(evento: e)), // Morado con celebración
      ]; // Fin de la lista

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    final novedades = _novedades(); // Tarjetas
    if (novedades.isEmpty) return const SizedBox.shrink(); // Sin anuncios ni eventos: no se muestra nada
    final escala = MediaQuery.textScalerOf(context).scale(1); // Tamaño de letra del teléfono (y "letra grande"): el texto necesita más alto
    return Column( // Encabezado, carrusel y puntitos
      crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
      children: [ // Elementos
        Padding( // Encabezado con "Ver todo"
          padding: const EdgeInsets.only(top: 18, left: 4), // Separación
          child: Row( // Título y enlace
            children: [ // Elementos
              Expanded(child: Text('NOVEDADES', style: TextStyle(color: context.cc.dorado, fontWeight: FontWeight.bold, letterSpacing: 1.5))), // Dorado oscuro
              TextButton( // Abre la lista completa
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PantallaNovedades(anuncios: widget.anuncios, eventos: widget.eventos))), // Con tarjetas completas
                child: const Text('Ver todo'), // Texto
              ), // Fin del botón
            ], // Fin de los elementos
          ), // Fin de la fila
        ), // Fin del encabezado
        LayoutBuilder( // Mide el ancho disponible para calcular el alto de las tarjetas
          builder: (context, medidas) { // Con las medidas
            final ancho = medidas.maxWidth * 0.86; // Ancho de cada tarjeta
            final altoImagen = ancho * 9 / 16; // Flyer en proporción 16:9 (como los que crea el panel)
            final alto = altoImagen + 92 * escala; // Imagen + etiqueta, fecha y título (2 renglones)
            return SizedBox( // Alto fijo del carrusel
              height: alto, // Alto calculado
              child: PageView.builder( // Tarjetas que se deslizan
                  controller: _control, // Control (86 % por tarjeta)
                  padEnds: false, // La primera empieza a la izquierda (no centrada)
                  itemCount: novedades.length, // Cuántas
                  onPageChanged: (i) => setState(() => _actual = i), // Actualiza los puntitos
                  itemBuilder: (context, i) => Padding( // Separación entre tarjetas
                    padding: const EdgeInsets.only(right: 12), // Espacio a la derecha
                    child: _TarjetaNovedad(novedad: novedades[i], altoImagen: altoImagen), // La tarjeta
                  ), // Fin de la separación
                ), // Fin del PageView
            ); // Fin del alto fijo
          }, // Fin del builder
        ), // Fin del LayoutBuilder
        if (novedades.length > 1) // Si hay más de una...
          Padding( // ...puntitos para saber cuántas hay y cuál se ve
            padding: const EdgeInsets.only(top: 10), // Separación
            child: ExcludeSemantics( // Los lectores de pantalla no los leen (no aportan)
              child: Row( // En fila
                mainAxisAlignment: MainAxisAlignment.center, // Centrados
                children: [ // Un puntito por tarjeta
                  for (var i = 0; i < novedades.length; i++) // Cada tarjeta
                    AnimatedContainer( // Cambia de tamaño suavemente
                      duration: const Duration(milliseconds: 250), // Rapidez
                      margin: const EdgeInsets.symmetric(horizontal: 3), // Espacio entre puntitos
                      width: i == _actual ? 18 : 7, // El actual es una rayita más larga
                      height: 7, // Alto
                      decoration: BoxDecoration( // Forma y color
                        color: i == _actual ? context.cc.dorado : context.cc.tenue, // Dorado el actual, gris los demás
                        borderRadius: BorderRadius.circular(4), // Redondeado
                      ), // Fin de la decoración
                    ), // Fin del puntito
                ], // Fin de los puntitos
              ), // Fin de la fila
            ), // Fin de ExcludeSemantics
          ), // Fin de los puntitos
      ], // Fin de los elementos
    ); // Fin de la columna
  } // Fin de build
} // Fin de _CarruselNovedadesState

class _TarjetaNovedad extends StatelessWidget { // Tarjeta pequeña del carrusel
  const _TarjetaNovedad({required this.novedad, required this.altoImagen}); // Constructor

  final _Novedad novedad; // Datos
  final double altoImagen; // Alto del flyer (16:9)

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    final color = context.vivo(novedad.color); // Color más vivo en modo oscuro
    final bloque = Container( // Bloque de color cuando no hay flyer (o si no carga)
      color: novedad.color.withValues(alpha: context.alfaBurbuja), // Fondo suave del color
      alignment: Alignment.center, // Ícono al centro
      child: Icon(novedad.icono, size: 56, color: color), // Megáfono o celebración
    ); // Fin del bloque
    return Semantics( // Para lectores de pantalla: una sola frase
      button: true, // Se puede tocar
      label: '${novedad.etiqueta == 'ANUNCIO' ? 'Anuncio' : 'Evento'}: ${novedad.titulo}. ${novedad.fecha}', // Lo que leen
      excludeSemantics: true, // No lee cada texto por separado
      child: Card( // Tarjeta blanca (o azul noche en oscuro) con borde
        margin: EdgeInsets.zero, // Sin margen (lo pone el carrusel)
        clipBehavior: Clip.antiAlias, // Recorta la imagen con las esquinas redondeadas
        child: InkWell( // Se puede tocar
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => novedad.abrir())), // Abre el detalle
          child: Column( // Imagen arriba, textos abajo
            crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
            children: [ // Elementos
              SizedBox( // Espacio del flyer (16:9)
                height: altoImagen, // Alto
                width: double.infinity, // Todo el ancho
                child: novedad.imagenUrl == null // ¿Tiene flyer?
                    ? bloque // No: bloque de color
                    : Image.network(novedad.imagenUrl!, fit: BoxFit.cover, errorBuilder: (context, error, pila) => bloque), // Sí: el flyer (si no carga, el bloque)
              ), // Fin del flyer
              Padding( // Textos
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0), // Márgenes
                child: Column( // Uno debajo del otro
                  crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
                  children: [ // Elementos
                    Text( // Etiqueta y fecha: "ANUNCIO · 31 oct 2026"
                      novedad.fecha.isEmpty ? novedad.etiqueta : '${novedad.etiqueta} · ${novedad.fecha}', // Texto
                      maxLines: 1, // Un renglón
                      overflow: TextOverflow.ellipsis, // "…" si no cabe
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.6), // Pequeño y en color
                    ), // Fin de la etiqueta
                    const SizedBox(height: 4), // Espacio
                    Text( // Título
                      novedad.titulo, // Texto
                      maxLines: 2, // Máximo 2 renglones
                      overflow: TextOverflow.ellipsis, // "…" si es más largo (completo al abrirla)
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: context.cc.titulo, height: 1.2), // Negrita
                    ), // Fin del título
                  ], // Fin de los elementos
                ), // Fin de la columna
              ), // Fin de los textos
            ], // Fin de los elementos
          ), // Fin de la columna
        ), // Fin de InkWell
      ), // Fin de la tarjeta
    ); // Fin de Semantics
  } // Fin de build
} // Fin de _TarjetaNovedad
