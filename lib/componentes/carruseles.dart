import 'dart:async'; // Timer (paso automático de las tarjetas)

import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../modelos/anuncio.dart'; // Molde de un anuncio
import '../modelos/evento.dart'; // Molde de un evento
import '../pantallas/anuncio.dart'; // Detalle del anuncio y lista de anuncios
import '../pantallas/evento.dart'; // Detalle del evento
import '../tema.dart'; // Colores de Canaán
import 'tarjeta_evento.dart'; // moradoEvento

// Carruseles de Inicio: ANUNCIOS y PRÓXIMOS EVENTOS, cada uno en SU fila de tarjetas pequeñas que se deslizan de lado.
// Cada tarjeta: el flyer (o un bloque de color con el título) y UNA línea corta abajo. Al tocarla se abre completa.
// Las tarjetas pasan solas; si la persona toca el carrusel se detiene un rato, y con ⏸ se detiene del todo.

class Carruseles { // Ajustes compartidos de los carruseles
  static Duration? pasoAutomatico = const Duration(seconds: 6); // Cada cuánto pasa a la siguiente tarjeta (null = no pasan solas; las pruebas lo apagan)
  static const Duration pausaAlTocar = Duration(seconds: 15); // Tras tocar o deslizar, cuánto espera para seguir pasando solo
} // Fin de Carruseles

class _Novedad { // Una tarjeta del carrusel (sirve igual para anuncio o evento)
  const _Novedad({required this.titulo, required this.tipo, required this.linea, required this.color, required this.icono, this.imagenUrl, required this.abrir}); // Constructor

  final String titulo; // Título (va dentro del bloque si no hay flyer; con flyer ya está en la imagen)
  final String tipo; // "Anuncio" o "Evento" (para lectores de pantalla)
  final String linea; // Línea corta de abajo: fecha del evento o "Toca para ver más"
  final Color color; // Azul (anuncio) o morado (evento)
  final IconData icono; // Megáfono o celebración
  final String? imagenUrl; // Flyer (null = bloque de color con el título)
  final Widget Function() abrir; // Pantalla que se abre al tocarla
} // Fin de _Novedad

class CarruselAnuncios extends StatelessWidget { // Sección "ANUNCIOS" de Inicio
  const CarruselAnuncios({super.key, required this.anuncios}); // Constructor

  final List<Anuncio> anuncios; // Anuncios vigentes ("Todos")

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return _Carrusel( // Fila deslizable
      titulo: 'ANUNCIOS', // Encabezado
      colorTitulo: context.cc.dorado, // Dorado oscuro
      textoVerTodo: 'Ver todo', // Enlace
      alVerTodo: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PantallaListaAnuncios(anuncios: anuncios))), // Lista con los anuncios completos
      novedades: [ // Una tarjeta por anuncio
        for (final a in anuncios) // Cada anuncio
          _Novedad(titulo: a.titulo, tipo: 'Anuncio', linea: 'Toca para ver más', color: azulCanaan, icono: Icons.campaign_outlined, imagenUrl: a.imagenUrl, abrir: () => PantallaAnuncio(anuncio: a)), // Azul con megáfono (sin fecha: la del envío confundía con la del flyer)
      ], // Fin de las tarjetas
    ); // Fin del carrusel
  } // Fin de build
} // Fin de CarruselAnuncios

class CarruselEventos extends StatelessWidget { // Sección "PRÓXIMOS EVENTOS" de Inicio
  const CarruselEventos({super.key, required this.eventos, this.alVerTodos}); // Constructor

  final List<Evento> eventos; // Próximos eventos
  final VoidCallback? alVerTodos; // Abre la pestaña Eventos (lo da Inicio)

  static const int maximo = 5; // Eventos que caben en el carrusel (los demás, en la pestaña Eventos)

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return _Carrusel( // Fila deslizable
      titulo: 'PRÓXIMOS EVENTOS', // Encabezado
      colorTitulo: context.cc.morado, // Morado de los eventos
      textoVerTodo: 'Ver todos', // Enlace
      alVerTodo: alVerTodos, // Pestaña Eventos
      novedades: [ // Una tarjeta por evento
        for (final e in eventos.take(maximo)) // Los más cercanos
          _Novedad(titulo: e.titulo, tipo: 'Evento', linea: e.enCurso ? '● AHORA' : e.cuandoTexto(), color: moradoEvento, icono: Icons.celebration_outlined, imagenUrl: e.imagenUrl, abrir: () => PantallaEvento(evento: e)), // Morado con celebración; la línea es la fecha del evento
      ], // Fin de las tarjetas
    ); // Fin del carrusel
  } // Fin de build
} // Fin de CarruselEventos

class _Carrusel extends StatefulWidget { // Encabezado + fila de tarjetas que se deslizan + puntitos y ⏸ (lo comparten anuncios y eventos)
  const _Carrusel({required this.titulo, required this.colorTitulo, required this.novedades, required this.textoVerTodo, this.alVerTodo}); // Constructor

  final String titulo; // "ANUNCIOS" o "PRÓXIMOS EVENTOS"
  final Color colorTitulo; // Color del encabezado y del puntito actual
  final List<_Novedad> novedades; // Tarjetas
  final String textoVerTodo; // "Ver todo" / "Ver todos"
  final VoidCallback? alVerTodo; // Qué hacer al tocar el enlace (null = no se muestra)

  @override // Reemplaza createState
  State<_Carrusel> createState() => _CarruselState(); // Crea el estado
} // Fin de _Carrusel

class _CarruselState extends State<_Carrusel> { // Estado: tarjeta actual, paso automático y pausas
  final _control = PageController(viewportFraction: 0.86); // Cada tarjeta ocupa el 86 %: se asoma la siguiente (así se nota que se desliza)
  int _actual = 0; // Tarjeta que se ve ahora
  Timer? _reloj; // Pasa a la siguiente tarjeta cada cierto tiempo
  bool _detenido = false; // La persona tocó ⏸ (no pasa solo hasta que toque ▶)
  DateTime? _tocadoEn; // Última vez que la persona tocó o deslizó el carrusel (pausa corta)

  @override // Reemplaza initState
  void initState() { // Al crearse
    super.initState(); // Preparación normal
    final paso = Carruseles.pasoAutomatico; // Cada cuánto pasa
    if (paso != null) _reloj = Timer.periodic(paso, (_) => _siguiente()); // Arranca el paso automático
  } // Fin de initState

  @override // Reemplaza dispose
  void dispose() { // Al cerrar la pantalla
    _reloj?.cancel(); // Detiene el reloj
    _control.dispose(); // Libera el control
    super.dispose(); // Limpieza normal
  } // Fin de dispose

  bool get _pasaSolo => // ¿Debe pasar solo? (más de una tarjeta, sin ⏸ y sin "quitar animaciones" en el teléfono)
      widget.novedades.length > 1 && !_detenido && !MediaQuery.of(context).disableAnimations; // Las tres condiciones

  void _siguiente() { // Lo llama el reloj
    if (!mounted || !_pasaSolo || !_control.hasClients) return; // Nada que hacer
    final tocado = _tocadoEn; // Último toque
    if (tocado != null && DateTime.now().difference(tocado) < Carruseles.pausaAlTocar) return; // La persona lo está viendo: espera
    final destino = (_actual + 1) % widget.novedades.length; // La siguiente (después de la última, vuelve a la primera)
    _control.animateToPage(destino, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut); // Pasa con movimiento suave
  } // Fin de _siguiente

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    final novedades = widget.novedades; // Tarjetas
    if (novedades.isEmpty) return const SizedBox.shrink(); // Sin tarjetas: no se muestra la sección
    if (_actual >= novedades.length) _actual = 0; // Si el panel quitó tarjetas, vuelve a la primera
    final escala = MediaQuery.textScalerOf(context).scale(1); // Tamaño de letra del teléfono (y "letra grande"): la línea de abajo necesita más alto
    final automatico = Carruseles.pasoAutomatico != null && novedades.length > 1 && !MediaQuery.of(context).disableAnimations; // ¿Se muestra el botón ⏸ / ▶?
    return Column( // Encabezado, carrusel y puntitos
      crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
      children: [ // Elementos
        Padding( // Encabezado
          padding: const EdgeInsets.only(top: 18, left: 4), // Separación
          child: Row( // Título y enlace
            children: [ // Elementos
              Expanded(child: Text(widget.titulo, style: TextStyle(color: widget.colorTitulo, fontWeight: FontWeight.bold, letterSpacing: 1.5))), // Título en color
              if (widget.alVerTodo != null) TextButton(onPressed: widget.alVerTodo, child: Text(widget.textoVerTodo)), // "Ver todo"
            ], // Fin de los elementos
          ), // Fin de la fila
        ), // Fin del encabezado
        LayoutBuilder( // Mide el ancho disponible para calcular el alto de las tarjetas
          builder: (context, medidas) { // Con las medidas
            final ancho = medidas.maxWidth * 0.86; // Ancho de cada tarjeta
            final altoImagen = ancho * 9 / 16; // Flyer en proporción 16:9 (como los que crea el panel)
            final alto = altoImagen + 44 * escala; // Imagen + una línea corta
            return SizedBox( // Alto fijo del carrusel
              height: alto, // Alto calculado
              child: Listener( // Se entera cuando la persona toca el carrusel (para detener el paso automático un rato)
                onPointerDown: (_) => _tocadoEn = DateTime.now(), // Al tocar
                onPointerUp: (_) => _tocadoEn = DateTime.now(), // Al soltar (cuenta los 15 s desde ahí)
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
              ), // Fin del Listener
            ); // Fin del alto fijo
          }, // Fin del builder
        ), // Fin del LayoutBuilder
        if (novedades.length > 1) // Si hay más de una...
          Padding( // ...puntitos y botón ⏸ / ▶
            padding: const EdgeInsets.only(top: 4), // Separación
            child: Row( // En fila
              mainAxisAlignment: MainAxisAlignment.center, // Centrados
              children: [ // Elementos
                ExcludeSemantics( // Los lectores de pantalla no leen los puntitos (no aportan)
                  child: Row( // Un puntito por tarjeta
                    children: [ // Puntitos
                      for (var i = 0; i < novedades.length; i++) // Cada tarjeta
                        AnimatedContainer( // Cambia de tamaño suavemente
                          duration: const Duration(milliseconds: 250), // Rapidez
                          margin: const EdgeInsets.symmetric(horizontal: 3), // Espacio entre puntitos
                          width: i == _actual ? 18 : 7, // El actual es una rayita más larga
                          height: 7, // Alto
                          decoration: BoxDecoration( // Forma y color
                            color: i == _actual ? widget.colorTitulo : context.cc.tenue, // El actual del color de la sección, los demás en gris
                            borderRadius: BorderRadius.circular(4), // Redondeado
                          ), // Fin de la decoración
                        ), // Fin del puntito
                    ], // Fin de los puntitos
                  ), // Fin de la fila
                ), // Fin de ExcludeSemantics
                if (automatico) // Si pasan solas...
                  IconButton( // ...botón para detenerlas o reanudarlas
                    tooltip: _detenido ? 'Pasar las tarjetas solas' : 'Detener el paso de las tarjetas', // Texto de ayuda (y para lectores de pantalla)
                    visualDensity: VisualDensity.compact, // Compacto
                    icon: Icon(_detenido ? Icons.play_circle_outline : Icons.pause_circle_outline, color: context.cc.suave, size: 26), // ▶ o ⏸
                    onPressed: () => setState(() { _detenido = !_detenido; _tocadoEn = null; }), // Cambia (al reanudar, sigue en el próximo paso)
                  ), // Fin del botón
              ], // Fin de los elementos
            ), // Fin de la fila
          ), // Fin de los puntitos
      ], // Fin de los elementos
    ); // Fin de la columna
  } // Fin de build
} // Fin de _CarruselState

class _TarjetaNovedad extends StatelessWidget { // Tarjeta pequeña del carrusel: imagen (o bloque con el título) + una línea corta
  const _TarjetaNovedad({required this.novedad, required this.altoImagen}); // Constructor

  final _Novedad novedad; // Datos
  final double altoImagen; // Alto del flyer (16:9)

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    final color = context.vivo(novedad.color); // Color más vivo en modo oscuro
    final bloque = Container( // Bloque de color con ícono y título (cuando no hay flyer o no carga)
      color: novedad.color.withValues(alpha: context.alfaBurbuja), // Fondo suave del color
      padding: const EdgeInsets.all(16), // Márgenes
      child: Column( // Ícono arriba, título abajo
        mainAxisAlignment: MainAxisAlignment.center, // Centrados en alto
        children: [ // Elementos
          Icon(novedad.icono, size: 40, color: color), // Megáfono o celebración
          const SizedBox(height: 8), // Espacio
          Flexible( // El título usa lo que quede (si es largo, "…")
            child: Text( // Título grande
              novedad.titulo, // Texto
              textAlign: TextAlign.center, // Centrado
              maxLines: 3, // Máximo 3 renglones
              overflow: TextOverflow.ellipsis, // "…" si es más largo (completo al abrirla)
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.cc.titulo, height: 1.2), // Negrita
            ), // Fin del título
          ), // Fin de Flexible
        ], // Fin de los elementos
      ), // Fin de la columna
    ); // Fin del bloque
    return Semantics( // Para lectores de pantalla: una sola frase
      button: true, // Se puede tocar
      label: '${novedad.tipo}: ${novedad.titulo}. ${novedad.linea}', // Lo que leen (el nombre siempre, aunque solo esté en el flyer)
      excludeSemantics: true, // No lee cada texto por separado
      child: Card( // Tarjeta blanca (o azul noche en oscuro) con borde
        margin: EdgeInsets.zero, // Sin margen (lo pone el carrusel)
        clipBehavior: Clip.antiAlias, // Recorta la imagen con las esquinas redondeadas
        child: InkWell( // Se puede tocar
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => novedad.abrir())), // Abre el detalle
          child: Column( // Imagen arriba, línea abajo
            crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
            children: [ // Elementos
              SizedBox( // Espacio del flyer (16:9)
                height: altoImagen, // Alto
                width: double.infinity, // Todo el ancho
                child: novedad.imagenUrl == null // ¿Tiene flyer?
                    ? bloque // No: bloque de color con el título
                    : Image.network(novedad.imagenUrl!, fit: BoxFit.cover, errorBuilder: (context, error, pila) => bloque), // Sí: el flyer (el nombre ya está en la imagen; si no carga, el bloque)
              ), // Fin del flyer
              Expanded( // La línea corta ocupa el resto
                child: Padding( // Márgenes
                  padding: const EdgeInsets.symmetric(horizontal: 12), // A los lados
                  child: Row( // Texto y flechita
                    children: [ // Elementos
                      Expanded( // El texto usa el espacio
                        child: Text( // "20 AL 22 DE NOVIEMBRE" o "TOCA PARA VER MÁS"
                          novedad.linea.toUpperCase(), // Texto
                          maxLines: 1, // Un renglón
                          overflow: TextOverflow.ellipsis, // "…" si no cabe
                          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.6), // Pequeño y en color
                        ), // Fin del texto
                      ), // Fin de Expanded
                      Icon(Icons.chevron_right, color: color), // Flechita: se puede abrir
                    ], // Fin de los elementos
                  ), // Fin de la fila
                ), // Fin de los márgenes
              ), // Fin de Expanded
            ], // Fin de los elementos
          ), // Fin de la columna
        ), // Fin de InkWell
      ), // Fin de la tarjeta
    ); // Fin de Semantics
  } // Fin de build
} // Fin de _TarjetaNovedad
