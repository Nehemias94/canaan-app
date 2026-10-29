import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../tema.dart'; // Colores de Canaán

// Pantalla de carga animada (mientras la app se conecta con el panel), igual al logo oficial:
// 1) aparece el arca dorada, 2) a su lado se escribe "Canaán" letra por letra, 3) aparecen "MINISTERIO CRISTIANO" y
// "DE LAS ASAMBLEAS DE DIOS", 4) si sigue cargando, abajo sale "Conectando…". La animación corre UNA vez (no se repite).
class CargaAnimada extends StatefulWidget { // Pantalla de carga con el logo animado
  const CargaAnimada({super.key, this.datosListos = false}); // Constructor

  final bool datosListos; // true = el panel ya respondió (la animación sigue en pantalla un momento): no hace falta mostrar "Conectando…"

  @override // Reemplaza createState
  State<CargaAnimada> createState() => _CargaAnimadaState(); // Crea el estado
} // Fin de CargaAnimada

class _CargaAnimadaState extends State<CargaAnimada> with SingleTickerProviderStateMixin { // "SingleTicker…" = permite usar un reloj de animación
  static const _letras = ['C', 'a', 'n', 'a', 'á', 'n']; // Letras de "Canaán", en orden
  static const _duracion = Duration(milliseconds: 4700); // Duración total: el logo se forma en 2.5 s y luego se queda quieto (Inicio lo cambia a los 4.5 s; así la animación cubre esa pausa)

  late final AnimationController _reloj = AnimationController(vsync: this, duration: _duracion); // Reloj de 0 a 1 en 3.6 s

  @override // Reemplaza initState
  void initState() { // Al aparecer
    super.initState(); // Lo de Flutter por defecto
    _reloj.forward(); // Arranca la animación (una sola vez)
  } // Fin de initState

  @override // Reemplaza dispose
  void dispose() { // Al desaparecer (ya cargó)
    _reloj.dispose(); // Libera el reloj
    super.dispose(); // Lo de Flutter por defecto
  } // Fin de dispose

  double _tramo(double desde, double hasta) { // Avance (0 a 1) entre dos momentos, en SEGUNDOS desde que empezó, con frenado suave
    final segundos = _reloj.value * _duracion.inMilliseconds / 1000; // Segundos transcurridos
    return Curves.easeOut.transform(((segundos - desde) / (hasta - desde)).clamp(0.0, 1.0)); // 0 antes de "desde", 1 después de "hasta"
  } // Fin de _tramo

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    if (MediaQuery.of(context).disableAnimations) _reloj.value = 1; // El teléfono pide "reducir animaciones": muestra todo de una vez
    return AnimatedBuilder( // Se redibuja en cada cuadro de la animación
      animation: _reloj, // Escucha el reloj
      builder: (context, _) { // Cómo se ve en este instante
        final arca = _tramo(0.0, 0.6); // Arca: de 0 a 0.6 s
        final textos = _tramo(2.0, 2.5); // "Ministerio…" y "de las Asambleas…": de 2.0 a 2.5 s
        final aviso = _tramo(3.0, 3.6); // "Conectando…": de 3.0 a 3.6 s (solo si sigue cargando)
        return Center( // Todo centrado en la pantalla
          child: Column( // Logo arriba y aviso abajo
            mainAxisSize: MainAxisSize.min, // Solo lo necesario
            children: [ // Elementos
              Semantics( // Para lectores de pantalla: se lee como una sola cosa
                label: 'Ministerio Cristiano Canaán de las Asambleas de Dios. Cargando.', // Texto para lectores de pantalla
                excludeSemantics: true, // No lee cada letra por separado
                child: Row( // Arca a la izquierda y nombre a la derecha
                  mainAxisSize: MainAxisSize.min, // Solo lo necesario
                  children: [ // Elementos
                    Opacity( // El arca se va aclarando...
                      opacity: arca, // ...de 0 a 1
                      child: Transform.scale( // ...y crece un poco
                        scale: 0.7 + 0.3 * arca, // De 70 % a 100 %
                        child: Image.asset('assets/imagenes/canaan-icono.png', height: 76), // Arca dorada oficial
                      ), // Fin del crecimiento
                    ), // Fin del arca
                    const SizedBox(width: 12), // Espacio
                    Column( // Nombre con sus dos textos chicos
                      crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
                      mainAxisSize: MainAxisSize.min, // Solo lo necesario
                      children: [ // Elementos
                        Opacity( // "MINISTERIO CRISTIANO" aparece al final
                          opacity: textos, // De 0 a 1
                          child: const Text('MINISTERIO CRISTIANO', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2)), // Pequeño y separado
                        ), // Fin del texto de arriba
                        Row( // Las letras de "Canaán"
                          mainAxisSize: MainAxisSize.min, // Solo lo necesario
                          children: [ // Una por letra
                            for (var i = 0; i < _letras.length; i++) // Por cada letra...
                              Builder(builder: (context) { // ...calcula su animación
                                final inicio = 0.6 + i * 0.23; // Cada letra empieza 0.23 s después que la anterior (la primera a los 0.6 s)
                                final t = _tramo(inicio, inicio + 0.32); // Avance de esta letra (tarda 0.32 s en aparecer)
                                return Opacity( // Se va aclarando...
                                  opacity: t, // ...de 0 a 1 (invisible pero OCUPA su lugar: el arca no se mueve)
                                  child: Transform.translate( // ...y se desliza desde la izquierda
                                    offset: Offset(-10 * (1 - t), 0), // 10 px → 0
                                    child: Text(_letras[i], style: const TextStyle(color: Colors.white, fontSize: 46, fontWeight: FontWeight.bold, height: 1.05)), // Letra blanca grande
                                  ), // Fin del deslizamiento
                                ); // Fin de la letra
                              }), // Fin del Builder
                          ], // Fin de las letras
                        ), // Fin de "Canaán"
                        Opacity( // "DE LAS ASAMBLEAS DE DIOS" aparece al final
                          opacity: textos, // De 0 a 1
                          child: const Text('DE LAS ASAMBLEAS DE DIOS', style: TextStyle(color: doradoCanaan, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.6)), // Pequeño, dorado
                        ), // Fin del texto de abajo
                      ], // Fin de los elementos
                    ), // Fin del nombre
                  ], // Fin de los elementos
                ), // Fin de la fila
              ), // Fin de Semantics
              const SizedBox(height: 36), // Espacio
              Opacity( // Aviso "Conectando…" (solo si tarda)
                opacity: widget.datosListos ? 0 : aviso, // Aparece desde los 3 s, solo si TODAVÍA está cargando
                child: const Column( // Dos líneas
                  children: [ // Elementos
                    Text('Conectando…', style: TextStyle(color: Colors.white, fontSize: 17)), // Texto principal
                    SizedBox(height: 4), // Espacio
                    Text('La primera vez puede tardar hasta un minuto.', style: TextStyle(color: Colors.white60, fontSize: 14)), // Explicación
                  ], // Fin de los elementos
                ), // Fin de la columna
              ), // Fin del aviso
            ], // Fin de los elementos
          ), // Fin de la columna
        ); // Fin del centrado
      }, // Fin de builder
    ); // Fin de AnimatedBuilder
  } // Fin de build
} // Fin de _CargaAnimadaState
