import 'package:flutter/material.dart'; // Componentes visuales de Flutter (Color, ThemeData…)

// Colores oficiales de Canaán (los mismos del panel)
const Color azulCanaan = Color(0xFF004B82); // Azul principal
const Color marinoCanaan = Color(0xFF00223E); // Marino (letras del logo)
const Color doradoCanaan = Color(0xFFFFB100); // Dorado (ícono y acentos)

ThemeData temaCanaan() { // Tema (colores y estilos) de toda la app
  final colores = ColorScheme.fromSeed( // Arma una paleta completa a partir de un color
    seedColor: azulCanaan, // Color base: el azul de Canaán
    primary: azulCanaan, // Fuerza el azul oficial como color principal
    secondary: doradoCanaan, // Dorado como color de acento
  ); // Fin de la paleta
  return ThemeData( // Devuelve el tema
    colorScheme: colores, // Usa la paleta de arriba
    useMaterial3: true, // Diseño Material 3 (el más moderno)
    appBarTheme: const AppBarTheme( // Estilo de las barras de título de cada pantalla
      backgroundColor: marinoCanaan, // Fondo marino
      foregroundColor: Colors.white, // Título e íconos en blanco
      centerTitle: true, // Título centrado
    ), // Fin del estilo de la barra
    navigationBarTheme: NavigationBarThemeData( // Estilo de la barra de abajo (menú)
      indicatorColor: doradoCanaan.withValues(alpha: 0.35), // "Pastilla" dorada suave detrás de la opción elegida
    ), // Fin del estilo del menú
  ); // Fin del tema
} // Fin de temaCanaan

const List<String> _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic']; // Meses abreviados en español

String fechaCorta(DateTime? fecha) { // Convierte una fecha en texto corto, ej: "5 oct 2026"
  if (fecha == null) return ''; // Sin fecha → texto vacío
  return '${fecha.day} ${_meses[fecha.month - 1]} ${fecha.year}'; // Día, mes abreviado y año (los meses empiezan en 1, la lista en 0)
} // Fin de fechaCorta
