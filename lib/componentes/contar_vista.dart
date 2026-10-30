import 'dart:async'; // unawaited (avisar sin esperar)

import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../servicios/servicios_app.dart'; // API y llave del teléfono

class ContarVista extends StatefulWidget { // Envuelve una pantalla de detalle: al abrirla, avisa al panel UNA vez ("abrí este anuncio / evento")
  const ContarVista({super.key, required this.tipo, required this.id, required this.child}); // Constructor

  final String tipo; // 'anuncios' o 'eventos' (parte de la dirección de la API)
  final int id; // Cuál
  final Widget child; // La pantalla que se muestra

  @override // Reemplaza createState
  State<ContarVista> createState() => _ContarVistaState(); // Crea el estado
} // Fin de ContarVista

class _ContarVistaState extends State<ContarVista> { // Estado: solo para avisar al abrir
  @override // Reemplaza initState
  void initState() { // Al abrir la pantalla (una sola vez)
    super.initState(); // Lo normal
    unawaited(ServiciosApp.conLlave((token) => ServiciosApp.api.registrarVista(token: token, tipo: widget.tipo, id: widget.id)) // Avisa en segundo plano (anónimo: el panel solo suma 1 por teléfono)
        .catchError((_) => false)); // Sin internet o sin llave: no pasa nada (no se le muestra nada a la persona)
  } // Fin de initState

  @override // Reemplaza build
  Widget build(BuildContext context) => widget.child; // Muestra la pantalla tal cual
} // Fin de _ContarVistaState
