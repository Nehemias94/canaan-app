import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../componentes/estados.dart'; // Vistas compartidas: Cargando, ErrorConexion
import '../modelos/iglesia.dart'; // Molde de los datos de la iglesia
import '../servicios/api.dart'; // Llamadas a la API
import '../tema.dart'; // Colores de Canaán

class PantallaInicio extends StatefulWidget { // Pestaña "Inicio"; "Stateful" porque cambia (cargando → datos o error)
  const PantallaInicio({super.key, required this.api}); // Constructor: recibe la API (en pruebas, una falsa)

  final Api api; // De dónde se sacan los datos

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
              child: _DatosIglesia(iglesia: estado.data!), // Los datos ("!" = seguro que no es null)
            ); // Fin de RefreshIndicator
          }, // Fin de builder
        ), // Fin de FutureBuilder
      ), // Fin de SafeArea
    ); // Fin del Container
  } // Fin de build
} // Fin de _PantallaInicioState

class _DatosIglesia extends StatelessWidget { // Contenido de Inicio cuando llegaron los datos
  const _DatosIglesia({required this.iglesia}); // Constructor

  final Iglesia iglesia; // Datos de la iglesia

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return ListView( // Lista desplazable (necesaria para "jalar hacia abajo")
      padding: const EdgeInsets.all(24), // Margen
      children: [ // Elementos
        const SizedBox(height: 40), // Espacio arriba
        if (iglesia.logoUrl != null) // Si la iglesia subió un logo en el panel...
          Image.network(iglesia.logoUrl!, height: 96) // ...lo muestra
        else // Si no...
          const Icon(Icons.church, size: 80, color: doradoCanaan), // ...ícono dorado de iglesia
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
        if (iglesia.radioDisponible) // Si la radio está al aire...
          const _Etiqueta(texto: '🎧 Radio al aire', fondo: doradoCanaan, letras: marinoCanaan), // ...etiqueta dorada
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
