import 'package:flutter/material.dart'; // Componentes visuales de Flutter (Color, ThemeData…)
import 'package:flutter/services.dart'; // SystemUiOverlayStyle (colores de la barra de arriba del teléfono)

// Barra de arriba del teléfono (hora, batería, señal) con íconos BLANCOS y fondo transparente:
// se usa sobre fondos oscuros (barras de título marino y el degradado de Inicio). Sin esto salían negros y no se leían.
const SystemUiOverlayStyle barraSuperiorClara = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent, // Fondo transparente: se ve el color de la pantalla detrás
  statusBarIconBrightness: Brightness.light, // Android: íconos claros (blancos)
  statusBarBrightness: Brightness.dark, // iPhone: "fondo oscuro" = letras blancas (en iPhone se indica al revés)
); // Fin del estilo

// Colores oficiales de Canaán (los mismos del panel)
const Color azulCanaan = Color(0xFF004B82); // Azul principal
const Color marinoCanaan = Color(0xFF00223E); // Marino (letras del logo)
const Color doradoCanaan = Color(0xFFFFB100); // Dorado (ícono y acentos)
const Color fondoCanaan = Color(0xFFF3F6FA); // Fondo gris azulado muy claro de todas las pantallas (igual que el panel)
const Color bordeCanaan = Color(0xFFE2E8F0); // Borde suave de las tarjetas
const Color doradoOscuro = Color(0xFFB07A00); // Dorado oscuro (se lee bien sobre blanco)

ThemeData temaCanaan() { // Tema (colores y estilos) de toda la app
  final colores = ColorScheme.fromSeed( // Arma una paleta completa a partir de un color
    seedColor: azulCanaan, // Color base: el azul de Canaán
    primary: azulCanaan, // Fuerza el azul oficial como color principal
    secondary: doradoCanaan, // Dorado como color de acento
  ); // Fin de la paleta
  return ThemeData( // Devuelve el tema
    colorScheme: colores, // Usa la paleta de arriba
    useMaterial3: true, // Diseño Material 3 (el más moderno)
    fontFamily: 'Inter', // Fuente Inter en toda la app (la misma del panel; va dentro de la app, ver pubspec.yaml)
    scaffoldBackgroundColor: fondoCanaan, // Fondo claro igual en todas las pantallas
    appBarTheme: const AppBarTheme( // Estilo de las barras de título de cada pantalla
      backgroundColor: marinoCanaan, // Fondo marino
      foregroundColor: Colors.white, // Título e íconos en blanco
      centerTitle: true, // Título centrado
      systemOverlayStyle: barraSuperiorClara, // Hora y batería en blanco sobre el marino
      titleTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), // Título en Inter, negrita
    ), // Fin del estilo de la barra
    cardTheme: CardThemeData( // Estilo de TODAS las tarjetas
      color: Colors.white, // Blancas
      elevation: 0, // Sin sombra fuerte (se usa un borde suave)
      surfaceTintColor: Colors.transparent, // Sin el tinte de color de Material 3
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: bordeCanaan)), // Esquinas redondeadas + borde suave
    ), // Fin de las tarjetas
    navigationBarTheme: NavigationBarThemeData( // Estilo de la barra de abajo (menú): marino con la opción elegida en dorado
      backgroundColor: marinoCanaan, // Fondo marino (igual que las barras de título)
      indicatorColor: doradoCanaan.withValues(alpha: 0.22), // "Pastilla" dorada suave detrás de la opción elegida
      iconTheme: WidgetStateProperty.resolveWith((estado) => IconThemeData( // Íconos según si están elegidos
            color: estado.contains(WidgetState.selected) ? doradoCanaan : Colors.white.withValues(alpha: 0.85), // Elegido: dorado; los demás: blanco claro (se lee mejor)
            size: 26, // Un poco más grandes (adultos mayores)
          )), // Fin de los íconos
      labelTextStyle: WidgetStateProperty.resolveWith((estado) => TextStyle( // Textos según si están elegidos
            color: estado.contains(WidgetState.selected) ? doradoCanaan : Colors.white.withValues(alpha: 0.85), // Elegido: dorado; los demás: blanco claro (se lee mejor)
            fontSize: 14, // Un poco más grande (adultos mayores)
            fontWeight: estado.contains(WidgetState.selected) ? FontWeight.bold : FontWeight.w500, // Elegido en negrita
          )), // Fin de los textos
    ), // Fin del estilo del menú
  ); // Fin del tema
} // Fin de temaCanaan

const List<String> _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic']; // Meses abreviados en español

String fechaCorta(DateTime? fecha) { // Convierte una fecha en texto corto, ej: "5 oct 2026"
  if (fecha == null) return ''; // Sin fecha → texto vacío
  return '${fecha.day} ${_meses[fecha.month - 1]} ${fecha.year}'; // Día, mes abreviado y año (los meses empiezan en 1, la lista en 0)
} // Fin de fechaCorta

const List<String> _dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo']; // Días (Dart: lunes = 1 … domingo = 7)
const List<String> _mesesLargos = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']; // Meses completos

String fechaLarga(DateTime fecha) => '${_dias[fecha.weekday - 1]}, ${fecha.day} de ${_mesesLargos[fecha.month - 1]}'; // Ej: "Jueves, 29 de octubre"

String saludoSegunHora(DateTime ahora) { // Saludo según la hora (igual que el Escritorio del panel)
  if (ahora.hour < 12) return 'Buenos días'; // Antes del mediodía
  if (ahora.hour < 19) return 'Buenas tardes'; // Antes de las 7 pm
  return 'Buenas noches'; // Desde las 7 pm
} // Fin de saludoSegunHora
