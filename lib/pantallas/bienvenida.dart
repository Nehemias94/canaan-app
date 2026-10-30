import 'package:flutter/foundation.dart'; // kIsWeb (en el navegador no hay permisos del teléfono)
import 'package:flutter/material.dart'; // Componentes visuales de Flutter
import 'package:permission_handler/permission_handler.dart'; // Permiso de notificaciones

import '../servicios/api.dart'; // Datos de la iglesia (para activar el aviso al llegar)
import '../servicios/geocerca_fondo.dart'; // Aviso al llegar a la iglesia
import '../servicios/preferencias.dart'; // Recordar que ya la vio y el "Ahora no"
import '../tema.dart'; // Colores de Canaán

// Bienvenida: SOLO la primera vez que se abre la app. Explica qué hay y pide los permisos con su explicación delante
// (notificaciones y, si se quiere, ubicación para el aviso al llegar a la iglesia). "Saltar" siempre visible.

class PantallaBienvenida extends StatefulWidget { // Pantalla de 3 pasos que se desliza
  const PantallaBienvenida({super.key, required this.api}); // Constructor

  final Api api; // Para pedir la ubicación de la iglesia (paso 3)

  @override // Reemplaza createState
  State<PantallaBienvenida> createState() => _PantallaBienvenidaState(); // Crea el estado
} // Fin de PantallaBienvenida

class _PantallaBienvenidaState extends State<PantallaBienvenida> { // Estado: en qué paso va
  final _control = PageController(); // Control de los pasos
  int _paso = 0; // Paso actual
  bool _ocupado = false; // Rueda mientras se piden permisos

  bool get _conUbicacion => GeocercaFondo.soportada; // El paso 3 solo en teléfonos (no en el navegador)
  int get _total => _conUbicacion ? 3 : 2; // Cuántos pasos

  @override // Reemplaza dispose
  void dispose() { // Al cerrar
    _control.dispose(); // Libera el control
    super.dispose(); // Lo normal
  } // Fin de dispose

  void _siguiente() { // Pasa al siguiente paso o termina
    if (_paso + 1 >= _total) { // Era el último
      Preferencias.terminarBienvenida(); // No vuelve a salir; la app pasa a la pantalla principal
    } else { // Si no
      _control.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOut); // Siguiente
    } // Fin del if
  } // Fin de _siguiente

  Future<void> _permitirNotificaciones() async { // Paso 2: "Permitir notificaciones"
    setState(() => _ocupado = true); // Rueda
    await Preferencias.posponerNotificaciones(false); // Ya decidió
    if (!kIsWeb) await Permission.notification.request(); // Ventana del teléfono (en el navegador la pide Firebase después)
    if (!mounted) return; // Pantalla cerrada
    setState(() => _ocupado = false); // Quita la rueda
    _siguiente(); // Siguiente paso
  } // Fin de _permitirNotificaciones

  Future<void> _ahoraNoNotificaciones() async { // Paso 2: "Ahora no"
    await Preferencias.posponerNotificaciones(true); // No se pedirá al abrir; se pedirá al encender un aviso en Servicios
    _siguiente(); // Siguiente paso
  } // Fin de _ahoraNoNotificaciones

  Future<void> _activarAvisoAlLlegar() async { // Paso 3: "Sí, activar"
    setState(() => _ocupado = true); // Rueda
    String? error; // Motivo si no se pudo
    try { // Pide la ubicación de la iglesia y activa
      error = await GeocercaFondo.activar(await widget.api.obtenerIglesia()); // Permisos + círculo de la iglesia
    } catch (_) { // Sin internet
      error = 'No pudimos conectar con la iglesia. Puedes activarlo después en Servicios.'; // Mensaje
    } // Fin del try
    if (!mounted) return; // Pantalla cerrada
    setState(() => _ocupado = false); // Quita la rueda
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Listo: te saludaremos cuando llegues a la iglesia.'))); // Resultado
    _siguiente(); // Termina
  } // Fin de _activarAvisoAlLlegar

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    final pasos = <Widget>[ // Los pasos
      _Paso( // 1) Bienvenida
        icono: Image.asset('assets/imagenes/canaan-icono.png', height: 110), // Ícono dorado de Canaán
        titulo: 'Bienvenido a Canaán', // Título
        texto: 'Aquí tienes las prédicas, la Biblia, los eventos, el horario de cultos y la transmisión en vivo de la iglesia, siempre a la mano.', // Explicación
        botones: [FilledButton(onPressed: _siguiente, style: _estiloPrincipal, child: const Text('Comenzar'))], // Botón
      ), // Fin del paso 1
      _Paso( // 2) Notificaciones
        icono: const Icon(Icons.notifications_active, size: 96, color: doradoCanaan), // Campana
        titulo: 'Te avisamos lo importante', // Título
        texto: 'Te enviaremos un aviso cuando estemos en vivo, los anuncios de la iglesia y los avisos urgentes (como un culto cancelado). Puedes elegir cuáles en Servicios.', // Explicación
        botones: [ // Botones
          FilledButton(onPressed: _ocupado ? null : _permitirNotificaciones, style: _estiloPrincipal, child: const Text('Permitir notificaciones')), // Sí
          TextButton(onPressed: _ocupado ? null : _ahoraNoNotificaciones, style: _estiloSecundario, child: const Text('Ahora no')), // No
        ], // Fin de los botones
      ), // Fin del paso 2
      if (_conUbicacion) _Paso( // 3) Aviso al llegar (solo en teléfonos)
        icono: const Icon(Icons.place, size: 96, color: doradoCanaan), // Pin
        titulo: '¿Un saludo al llegar a la iglesia?', // Título
        texto: 'Cuando llegues al templo te mostraremos los avisos del día, aunque la app esté cerrada. Tu ubicación NUNCA sale de tu teléfono. Android te pedirá permitir la ubicación "todo el tiempo".', // Explicación (requisito de Google: decir para qué se usa)
        botones: [ // Botones
          FilledButton(onPressed: _ocupado ? null : _activarAvisoAlLlegar, style: _estiloPrincipal, child: const Text('Sí, activar')), // Sí
          TextButton(onPressed: _ocupado ? null : _siguiente, style: _estiloSecundario, child: const Text('Ahora no')), // No
        ], // Fin de los botones
      ), // Fin del paso 3
    ]; // Fin de los pasos
    return Scaffold( // Estructura
      body: Container( // Fondo
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [marinoCanaan, azulCanaan])), // Degradado de Canaán
        child: SafeArea( // Sin chocar con la hora ni la barra de abajo
          child: Column( // Saltar · pasos · puntitos
            children: [ // Elementos
              Align( // "Saltar" arriba a la derecha
                alignment: Alignment.centerRight, // A la derecha
                child: TextButton(onPressed: _ocupado ? null : Preferencias.terminarBienvenida, style: TextButton.styleFrom(foregroundColor: Colors.white70), child: const Text('Saltar', style: TextStyle(fontSize: 16))), // Termina sin pedir nada
              ), // Fin de "Saltar"
              Expanded( // Los pasos
                child: PageView( // Se desliza
                  controller: _control, // Control
                  onPageChanged: (i) => setState(() => _paso = i), // Recuerda el paso
                  children: pasos, // Pasos
                ), // Fin del PageView
              ), // Fin de los pasos
              if (_ocupado) const Padding(padding: EdgeInsets.only(bottom: 12), child: CircularProgressIndicator(color: doradoCanaan)), // Rueda
              Padding( // Puntitos
                padding: const EdgeInsets.only(bottom: 24), // Separación
                child: Row( // En fila
                  mainAxisAlignment: MainAxisAlignment.center, // Centrados
                  children: [ // Un puntito por paso
                    for (var i = 0; i < _total; i++) // Cada paso
                      AnimatedContainer( // Cambia suave
                        duration: const Duration(milliseconds: 250), // Rapidez
                        margin: const EdgeInsets.symmetric(horizontal: 4), // Espacio
                        width: i == _paso ? 22 : 8, height: 8, // El actual es más largo
                        decoration: BoxDecoration(color: i == _paso ? doradoCanaan : Colors.white38, borderRadius: BorderRadius.circular(4)), // Dorado el actual
                      ), // Fin del puntito
                  ], // Fin de los puntitos
                ), // Fin de la fila
              ), // Fin de los puntitos
            ], // Fin de los elementos
          ), // Fin de la columna
        ), // Fin de SafeArea
      ), // Fin del fondo
    ); // Fin del Scaffold
  } // Fin de build

  static final ButtonStyle _estiloPrincipal = FilledButton.styleFrom( // Botón dorado grande
    backgroundColor: doradoCanaan, foregroundColor: marinoCanaan, // Dorado con letra marino
    minimumSize: const Size.fromHeight(56), // Alto cómodo (adultos mayores)
    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), // Letra grande
  ); // Fin del estilo
  static final ButtonStyle _estiloSecundario = TextButton.styleFrom( // "Ahora no"
    foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52), // Blanco, alto cómodo
    textStyle: const TextStyle(fontSize: 17), // Letra grande
  ); // Fin del estilo
} // Fin de _PantallaBienvenidaState

class _Paso extends StatelessWidget { // Un paso: ícono, título, texto y botones
  const _Paso({required this.icono, required this.titulo, required this.texto, required this.botones}); // Constructor

  final Widget icono; // Ícono grande
  final String titulo; // Título
  final String texto; // Explicación
  final List<Widget> botones; // Botones de abajo

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return SingleChildScrollView( // Desplazable si no cabe (letra grande o pantalla chica)
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 12), // Márgenes
      child: Column( // Uno debajo del otro
        children: [ // Elementos
          const SizedBox(height: 24), // Espacio arriba
          icono, // Ícono
          const SizedBox(height: 28), // Espacio
          Text(titulo, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, height: 1.2)), // Título
          const SizedBox(height: 16), // Espacio
          Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 18, height: 1.45)), // Explicación
          const SizedBox(height: 36), // Espacio
          for (final b in botones) Padding(padding: const EdgeInsets.only(bottom: 10), child: b), // Botones
        ], // Fin de los elementos
      ), // Fin de la columna
    ); // Fin del desplazable
  } // Fin de build
} // Fin de _Paso
