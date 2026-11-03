import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../servicios/conexion.dart'; // sinConexion (true = la app está mostrando lo guardado porque no hay internet)
import '../servicios/wifi_iglesia.dart'; // Wi-Fi para invitados

// Franja "📶 ¿Sin internet? Toca para conectarte al Wi-Fi de la iglesia" (opción B, con un toque).
// Sale solo si: la app no tiene internet, el panel ofrece Wi-Fi para invitados (Android) y el teléfono está en el área
// (si no dio permiso de ubicación, pregunta "¿Estás en la iglesia?"). No pide permisos.
class FranjaWifi extends StatefulWidget { // Franja encima del menú de abajo
  const FranjaWifi({super.key}); // Constructor

  @override // Reemplaza createState
  State<FranjaWifi> createState() => _FranjaWifiState(); // Crea el estado
} // Fin de FranjaWifi

class _FranjaWifiState extends State<FranjaWifi> { // Estado de la franja
  bool? _enArea; // null = no mostrar; true = está en el área; false = no se sabe dónde está
  bool _conectando = false; // true mientras se sugiere la red

  @override // Reemplaza initState
  void initState() { // Al crearse
    super.initState(); // Lo de Flutter por defecto
    sinConexion.addListener(_revisar); // Cada vez que cambia "sin conexión"...
    _revisar(); // ...y ahora mismo
  } // Fin de initState

  @override // Reemplaza dispose
  void dispose() { // Al quitarse
    sinConexion.removeListener(_revisar); // Deja de escuchar
    super.dispose(); // Lo de Flutter por defecto
  } // Fin de dispose

  Future<void> _revisar() async { // ¿Hay que ofrecer el Wi-Fi?
    if (!sinConexion.value) { if (mounted) setState(() => _enArea = null); return; } // Hay internet: nada
    final oferta = await WifiIglesiaServicio.ofrecerFranja(); // ¿Panel con Wi-Fi y está en el área?
    if (mounted && sinConexion.value) setState(() => _enArea = oferta); // Redibuja (si sigue sin internet)
  } // Fin de _revisar

  Future<void> _conectar() async { // Al tocar la franja
    final mensajero = ScaffoldMessenger.of(context); // Para avisar el resultado
    setState(() => _conectando = true); // Muestra la rueda
    final mensaje = await WifiIglesiaServicio.conectarConUnToque(); // Sugiere la red
    if (!mounted) return; // Ya no está en pantalla
    setState(() => _conectando = false); // Quita la rueda
    mensajero.showSnackBar(SnackBar(content: Text(mensaje), duration: const Duration(seconds: 8))); // Explica qué pasa ahora
  } // Fin de _conectar

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    if (_enArea == null) return const SizedBox.shrink(); // No se ofrece
    return Material( // Fondo (para el efecto del toque)
      color: const Color(0xFF0E7490), // Verde azulado (como el acceso rápido "Mapa"; se distingue del gris de "Sin conexión")
      child: InkWell( // Se puede tocar
        onTap: _conectando ? null : _conectar, // Conecta (una vez a la vez)
        child: Padding( // Relleno
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Arriba y abajo
          child: Row( // Ícono y texto
            children: [ // Elementos
              _conectando // ¿Conectando?
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) // Rueda
                  : const Icon(Icons.wifi, color: Colors.white), // Ícono de Wi-Fi
              const SizedBox(width: 12), // Espacio
              Expanded( // El texto ocupa el resto
                child: Text( // Texto
                  _enArea! ? '¿Sin internet? Toca para conectarte al Wi-Fi de la iglesia' : '¿Estás en la iglesia sin internet? Toca para conectarte a su Wi-Fi', // Según si se sabe dónde está
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600), // Blanco
                ), // Fin del texto
              ), // Fin de Expanded
              const Icon(Icons.chevron_right, color: Colors.white), // Flechita
            ], // Fin de los elementos
          ), // Fin de la fila
        ), // Fin del relleno
      ), // Fin de InkWell
    ); // Fin del fondo
  } // Fin de build
} // Fin de _FranjaWifiState
