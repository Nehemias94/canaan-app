import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../componentes/estados.dart'; // Vistas compartidas: Cargando, ErrorConexion
import '../modelos/iglesia.dart'; // Molde de los datos de la iglesia
import '../servicios/api.dart'; // Llamadas a la API
import '../servicios/registro.dart'; // Registro del teléfono (para las señales del en vivo)
import '../tema.dart'; // Colores de Canaán
import 'radio.dart'; // Pantalla de la radio
import 'video.dart'; // Pantalla del video (transmisión en vivo)

class PantallaInicio extends StatefulWidget { // Pestaña "Inicio"; "Stateful" porque cambia (cargando → datos o error)
  const PantallaInicio({super.key, required this.api, required this.registro}); // Constructor: recibe la API (en pruebas, una falsa) y el registro

  final Api api; // De dónde se sacan los datos
  final RegistroDispositivo registro; // Para las señales del en vivo

  @override // Reemplaza createState
  State<PantallaInicio> createState() => _PantallaInicioState(); // Crea el estado de la pantalla
} // Fin de PantallaInicio

class _PantallaInicioState extends State<PantallaInicio> { // Estado de la pestaña Inicio
  late Future<Iglesia> _peticion; // Petición en curso ("late": se le da valor en initState)

  @override // Reemplaza initState
  void initState() { // Se ejecuta una sola vez, al crear la pantalla
    super.initState(); // Lo que hace Flutter por defecto
    _peticion = widget.api.obtenerIglesia(); // Empieza a pedir los datos apenas se abre
  } // Fin de initState

  Future<void> _recargar() async { // Vuelve a pedir los datos (botón Reintentar o jalar hacia abajo)
    setState(() => _peticion = widget.api.obtenerIglesia()); // Nueva petición y redibuja
    try { await _peticion; } catch (_) {} // Espera a que termine (si falla, el FutureBuilder ya muestra el error)
  } // Fin de _recargar

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Container( // Caja que ocupa toda la pestaña
      decoration: const BoxDecoration( // Fondo
        gradient: LinearGradient( // Degradado
          begin: Alignment.topCenter, // De arriba...
          end: Alignment.bottomCenter, // ...hacia abajo
          colors: [marinoCanaan, azulCanaan], // Marino → azul (igual que el login del panel)
        ), // Fin del degradado
      ), // Fin del fondo
      child: SafeArea( // Evita la cámara y la barra del teléfono
        child: FutureBuilder<Iglesia>( // Dibuja según el estado de la petición
          future: _peticion, // La petición que vigila
          builder: (context, estado) { // Se llama cada vez que cambia
            if (estado.connectionState != ConnectionState.done) return const Cargando(claro: true); // Esperando
            if (estado.hasError) return ErrorConexion(alReintentar: _recargar, claro: true); // Falló
            return RefreshIndicator( // Permite "jalar hacia abajo" para actualizar
              onRefresh: _recargar, // Qué hacer al jalar
              child: _DatosIglesia(iglesia: estado.data!, api: widget.api, registro: widget.registro), // Los datos ("!" = seguro que no es null)
            ); // Fin de RefreshIndicator
          }, // Fin de builder
        ), // Fin de FutureBuilder
      ), // Fin de SafeArea
    ); // Fin del Container
  } // Fin de build
} // Fin de _PantallaInicioState

class _DatosIglesia extends StatelessWidget { // Contenido de Inicio cuando llegaron los datos
  const _DatosIglesia({required this.iglesia, required this.api, required this.registro}); // Constructor

  final Iglesia iglesia; // Datos de la iglesia
  final Api api; // Se pasa a la pantalla del video
  final RegistroDispositivo registro; // Se pasa a la pantalla del video

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return ListView( // Lista desplazable (necesaria para "jalar hacia abajo")
      padding: const EdgeInsets.all(24), // Margen
      children: [ // Elementos
        const SizedBox(height: 40), // Espacio arriba
        if (iglesia.logoUrl != null) // Si la iglesia subió un logo en el panel...
          Image.network(iglesia.logoUrl!, height: 96) // ...lo muestra
        else // Si no...
          Image.asset('assets/imagenes/canaan-icono.png', height: 96), // ...el ícono oficial dorado de Canaán (va dentro de la app)
        const SizedBox(height: 16), // Espacio
        Text( // Nombre de la iglesia (viene del panel)
          iglesia.nombre, // Texto
          textAlign: TextAlign.center, // Centrado
          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold), // Blanco grande en negrita
        ), // Fin del nombre
        const SizedBox(height: 20), // Espacio
        if (iglesia.enVivo.activo) // Si hay transmisión en vivo...
          _Etiqueta( // ...etiqueta roja
            texto: '● EN VIVO${iglesia.enVivo.titulo != null ? ' · ${iglesia.enVivo.titulo}' : ''}', // "● EN VIVO · título"
            fondo: Colors.red, // Rojo
            letras: Colors.white, // Letras blancas
          ), // Fin de la etiqueta
        if (iglesia.enVivo.activo && iglesia.enVivo.youtubeId != null) // Si hay en vivo y tiene video de YouTube...
          Padding( // ...botón grande para verlo
            padding: const EdgeInsets.only(top: 4, bottom: 12), // Separación
            child: Center( // Centrado
              child: FilledButton.icon( // Botón relleno
                style: FilledButton.styleFrom(backgroundColor: doradoCanaan, foregroundColor: marinoCanaan, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)), // Dorado con letras marino, grande
                icon: const Icon(Icons.play_circle_fill), // Ícono de reproducir
                label: const Text('Ver transmisión', style: TextStyle(fontWeight: FontWeight.bold)), // Texto
                onPressed: () => Navigator.push( // Abre el video encima
                  context, // Desde aquí
                  MaterialPageRoute(builder: (context) => PantallaVideo( // Pantalla del video
                    api: api, // API
                    registro: registro, // Registro del teléfono
                    youtubeId: iglesia.enVivo.youtubeId!, // Video de la transmisión
                    titulo: iglesia.enVivo.titulo ?? 'Transmisión en vivo', // Título (o uno genérico)
                    subtitulo: iglesia.nombre, // Nombre de la iglesia
                    enVivo: true, // Es en vivo: manda señales y muestra cuántos ven
                  )), // Fin de la ruta
                ), // Fin de Navigator.push
              ), // Fin del botón
            ), // Fin del centrado
          ), // Fin del margen
        if (iglesia.radioDisponible) // Si la radio está al aire...
          GestureDetector( // ...etiqueta dorada que se puede tocar
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaRadio(api: api))), // Al tocar, abre la radio
            child: const _Etiqueta(texto: '🎧 Radio al aire · Escuchar', fondo: doradoCanaan, letras: marinoCanaan), // Etiqueta dorada
          ), // Fin de GestureDetector
        if (iglesia.avisoUrgente.activo) // Si hay un aviso urgente vigente...
          Card( // ...tarjeta blanca con el aviso
            margin: const EdgeInsets.only(top: 12), // Separación arriba
            child: ListTile( // Fila con ícono, título y texto
              leading: const Icon(Icons.campaign, color: Colors.red), // Megáfono rojo
              title: Text(iglesia.avisoUrgente.titulo ?? 'Aviso'), // Título
              subtitle: Text(iglesia.avisoUrgente.mensaje ?? ''), // Mensaje
            ), // Fin de la fila
          ), // Fin de la tarjeta
        if (!iglesia.enVivo.activo && !iglesia.radioDisponible && !iglesia.avisoUrgente.activo) // Si no hay nada de lo anterior...
          const Text( // ...confirma que la conexión funciona
            '✓ Conectado con el panel', // Texto
            textAlign: TextAlign.center, // Centrado
            style: TextStyle(color: Colors.white70), // Blanco suave
          ), // Fin del texto
      ], // Fin de los elementos
    ); // Fin de la lista
  } // Fin de build
} // Fin de _DatosIglesia

class _Etiqueta extends StatelessWidget { // Etiqueta redondeada de color (EN VIVO, Radio)
  const _Etiqueta({required this.texto, required this.fondo, required this.letras}); // Constructor

  final String texto; // Texto
  final Color fondo; // Color de fondo
  final Color letras; // Color de las letras

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Center( // Centrada (dentro de la lista ocuparía todo el ancho)
      child: Container( // Caja
        margin: const EdgeInsets.only(bottom: 8), // Separación abajo
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), // Relleno interno
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)), // Fondo y bordes redondos
        child: Text(texto, style: TextStyle(color: letras, fontWeight: FontWeight.bold)), // Texto en negrita
      ), // Fin de la caja
    ); // Fin del centrado
  } // Fin de build
} // Fin de _Etiqueta
