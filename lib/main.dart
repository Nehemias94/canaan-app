import 'package:flutter/material.dart'; // Trae los componentes visuales de Flutter (botones, textos, colores…)

// Colores oficiales de Canaán (los mismos del panel)
const Color azulCanaan = Color(0xFF004B82); // Azul principal
const Color marinoCanaan = Color(0xFF00223E); // Marino (letras del logo)
const Color doradoCanaan = Color(0xFFFFB100); // Dorado (ícono y acentos)

void main() { // Punto de arranque: es lo primero que se ejecuta al abrir la app
  runApp(const CanaanApp()); // Dibuja la app en la pantalla
} // Fin de main

class CanaanApp extends StatelessWidget { // La app completa (no cambia por sí sola, por eso "Stateless")
  const CanaanApp({super.key}); // Constructor (la "key" la usa Flutter internamente)

  @override // Reemplaza el método build de la clase padre
  Widget build(BuildContext context) { // Describe cómo se ve la app
    return MaterialApp( // Contenedor principal con el estilo Material de Google
      title: 'Canaán', // Nombre de la app (se ve en la pestaña del navegador y al cambiar de app)
      debugShowCheckedModeBanner: false, // Quita la cinta roja "DEBUG" de la esquina
      theme: ThemeData( // Tema claro
        colorScheme: ColorScheme.fromSeed( // Arma una paleta completa a partir de un color
          seedColor: azulCanaan, // Color base: el azul de Canaán
          primary: azulCanaan, // Fuerza el azul oficial como color principal
          secondary: doradoCanaan, // Dorado como color de acento
        ), // Fin de la paleta
        useMaterial3: true, // Usa el diseño Material 3 (el más moderno)
      ), // Fin del tema
      home: const PantallaInicio(), // Primera pantalla que se muestra
    ); // Fin de MaterialApp
  } // Fin de build
} // Fin de CanaanApp

class PantallaInicio extends StatelessWidget { // Pantalla de bienvenida (temporal, la iremos llenando)
  const PantallaInicio({super.key}); // Constructor

  @override // Reemplaza el método build
  Widget build(BuildContext context) { // Describe cómo se ve la pantalla
    return Scaffold( // Estructura básica de una pantalla (fondo, barra, cuerpo)
      body: Container( // Caja que ocupa toda la pantalla
        width: double.infinity, // Todo el ancho
        decoration: const BoxDecoration( // Decoración del fondo
          gradient: LinearGradient( // Degradado de color
            begin: Alignment.topCenter, // Empieza arriba
            end: Alignment.bottomCenter, // Termina abajo
            colors: [marinoCanaan, azulCanaan], // De marino a azul (igual que el login del panel)
          ), // Fin del degradado
        ), // Fin de la decoración
        child: const SafeArea( // Evita que el contenido quede debajo de la cámara o la barra del teléfono
          child: Column( // Acomoda los elementos uno debajo del otro
            mainAxisAlignment: MainAxisAlignment.center, // Centrados de arriba a abajo
            children: [ // Elementos de la columna
              Icon(Icons.church, size: 80, color: doradoCanaan), // Ícono temporal de iglesia en dorado (luego irá el logo)
              SizedBox(height: 16), // Espacio de 16 puntos
              Text( // Título
                'Canaán', // Texto
                style: TextStyle( // Estilo del texto
                  color: Colors.white, // Blanco
                  fontSize: 40, // Grande
                  fontWeight: FontWeight.bold, // Negrita
                ), // Fin del estilo
              ), // Fin del título
              SizedBox(height: 8), // Espacio de 8 puntos
              Text( // Subtítulo
                'Ministerio Cristiano Canaán', // Texto
                style: TextStyle(color: Colors.white70, fontSize: 16), // Blanco un poco transparente
              ), // Fin del subtítulo
            ], // Fin de los elementos
          ), // Fin de la columna
        ), // Fin de SafeArea
      ), // Fin del Container
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de PantallaInicio
